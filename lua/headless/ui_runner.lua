-- lua/headless/ui_runner.lua
-- Headless UI spec runner. Drives the real game through SceneManager with
-- key presses and clicks at on-screen positions, runs update + draw every
-- frame, checks global layout invariants, and evaluates spec assertions.
-- See docs/design/ui-tests.md and docs/checklists/ui-tests.md (C7-C10).

local SceneManager = require("lua/core/scene_manager")
local UI           = require("lua/core/ui")
local Stubs        = require("lua/headless/stubs")

local UIRunner = {}

local SCREEN_W, SCREEN_H = 1280, 720
local SETTLE_MAX         = 60
local WAIT_UNTIL_DEFAULT = 600

local VALID_KINDS = { button = true, cell = true, slot = true }

local STEP_KEYS = {
    "press", "click", "right_click", "click_button", "right_click_button",
    "click_cell", "right_click_cell", "click_slot", "right_click_slot",
    "move_mouse", "hover_button", "wait", "wait_until", "assert_text",
    "assert_no_text", "assert_button", "assert_matrix", "assert_tile",
}
local STEP_KEY_SET = {}
for _, k in ipairs(STEP_KEYS) do STEP_KEY_SET[k] = true end

-- Serialisation ------------------------------------------------------------

local function serialise(v)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t ~= "table" then
        return tostring(v)
    end
    local parts = {}
    local n = #v
    for i = 1, n do parts[#parts + 1] = serialise(v[i]) end
    local keys = {}
    for k in pairs(v) do
        if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local ks
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            ks = k
        else
            ks = "[" .. serialise(k) .. "]"
        end
        parts[#parts + 1] = ks .. " = " .. serialise(v[k])
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end
UIRunner.serialise = serialise

-- Invariants (C9) ----------------------------------------------------------

function UIRunner.check_invariants(elements)
    elements = elements or {}
    local seen = {}
    for n, e in ipairs(elements) do
        local why
        if type(e) ~= "table" then
            why = "not a table"
        elseif type(e.id) ~= "string" or e.id == "" then
            why = "missing id"
        elseif type(e.label) ~= "string" or e.label == "" then
            why = "missing label"
        elseif not VALID_KINDS[e.kind] then
            why = "bad kind '" .. tostring(e.kind) .. "'"
        elseif type(e.rect) ~= "table" or type(e.rect.x) ~= "number"
            or type(e.rect.y) ~= "number" or type(e.rect.w) ~= "number"
            or type(e.rect.h) ~= "number" then
            why = "bad rect"
        elseif not (e.rect.w > 0 and e.rect.h > 0) then
            why = "non-positive size"
        end
        if why then
            return "invariant: malformed element " .. n .. ": " .. why
        end
        if seen[e.id] then
            return "invariant: duplicate id '" .. e.id .. "'"
        end
        seen[e.id] = true
    end
    for _, e in ipairs(elements) do
        local r = e.rect
        if r.x < 0 or r.x + r.w > SCREEN_W or r.y < 0 or r.y + r.h > SCREEN_H then
            return "invariant: '" .. e.id .. "' off screen"
        end
    end
    for i = 1, #elements do
        for j = i + 1, #elements do
            if UI.overlaps(elements[i].rect, elements[j].rect) then
                return "invariant: '" .. elements[i].id .. "' overlaps '" .. elements[j].id .. "'"
            end
        end
    end
    return nil
end

-- Spec execution -----------------------------------------------------------

local FAIL_TAG = {}

local function fail(reason)
    error({ [FAIL_TAG] = true, reason = reason }, 0)
end

local function elements_of(sm)
    local scene = sm.current
    if scene and scene.ui_elements then
        return scene:ui_elements() or {}
    end
    return {}
end

local function new_ctx(sm)
    return { sm = sm, frame = 0 }
end

local function run_frame(ctx)
    local sm = ctx.sm
    ctx.frame = ctx.frame + 1
    sm:update(1 / 60)
    Stubs.clear_text()
    sm:draw()
    local err = UIRunner.check_invariants(elements_of(sm))
    if err then fail(err .. " at frame " .. ctx.frame) end
end

local function settle(ctx)
    local n = 0
    while not ctx.sm:is_idle() and n < SETTLE_MAX do
        run_frame(ctx)
        n = n + 1
    end
    if not ctx.sm:is_idle() then fail("fade did not finish") end
end

local function do_move(ctx, x, y)
    Stubs.set_mouse(x, y)
    ctx.sm:mouse_moved(x, y)
end

local function do_click(ctx, x, y, b)
    Stubs.set_mouse(x, y)
    ctx.sm:mouse_moved(x, y)
    ctx.sm:mouse_pressed(x, y, b)
    ctx.sm:mouse_released(x, y, b)
end

local function text_contains(s)
    for _, t in ipairs(Stubs.drawn_text()) do
        if t:find(s, 1, true) then return true end
    end
    return false
end

-- Finds the element a selector names. Selector is a label string or a table
-- with `id` (or `label`). Returns element (or nil) and a description used in
-- "missing" messages. Fails on ambiguous labels.
local function resolve(ctx, sel)
    local elements = elements_of(ctx.sm)
    local id, label
    if type(sel) == "string" then
        label = sel
    elseif type(sel) == "table" then
        id, label = sel.id, sel.label
    end
    if id ~= nil then
        return UI.find(elements, id), "id '" .. tostring(id) .. "'"
    end
    if label == nil then fail("selector needs a label or id") end
    local matches = {}
    for _, e in ipairs(elements) do
        if e.label == label then matches[#matches + 1] = e end
    end
    if #matches > 1 then
        fail("ambiguous label '" .. label .. "' (" .. #matches .. " matches)")
    end
    return matches[1], "labelled '" .. label .. "'"
end

local function require_element(ctx, sel, need_enabled)
    local e, desc = resolve(ctx, sel)
    if not e then fail("no visible element " .. desc) end
    if need_enabled and not e.enabled then
        fail("element '" .. e.id .. "' is disabled")
    end
    return e
end

local function click_element(ctx, e, b, px, py)
    local x, y = UI.centre(e.rect)
    do_click(ctx, px or x, py or y, b)
end

local function current_matrix(ctx)
    local scene = ctx.sm.current
    if not (scene and scene.ui_matrix) then fail("scene has no matrix") end
    return scene:ui_matrix()
end

local function matrix_equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do
        local ra, rb = a[i], b[i]
        if type(ra) ~= "table" or type(rb) ~= "table" or #ra ~= #rb then return false end
        for j = 1, #ra do
            if ra[j] ~= rb[j] then return false end
        end
    end
    return true
end

local function pusher_letter(p)
    if type(p) == "number" then return string.char(64 + p) end
    return tostring(p)
end

local handlers = {}

function handlers.press(ctx, key)
    settle(ctx)
    ctx.sm:key_pressed(key)
    run_frame(ctx)
end

local function raw_click(b)
    return function(ctx, arg)
        settle(ctx)
        do_click(ctx, arg[1] or arg.x, arg[2] or arg.y, b)
        run_frame(ctx)
    end
end
handlers.click       = raw_click(1)
handlers.right_click = raw_click(2)

local function button_click(b)
    return function(ctx, sel)
        settle(ctx)
        local e = require_element(ctx, sel, true)
        click_element(ctx, e, b)
        run_frame(ctx)
    end
end
handlers.click_button       = button_click(1)
handlers.right_click_button = button_click(2)

local function cell_click(b)
    return function(ctx, arg)
        settle(ctx)
        local cx, cy = arg[1] or arg.x, arg[2] or arg.y
        local e = require_element(ctx, { id = "cell:" .. tostring(cx) .. "," .. tostring(cy) }, true)
        local r = e.rect
        local part = arg.part or "centre"
        local px, py = UI.centre(r)
        if part == "left" then
            px = math.floor(r.x + r.w / 6 + 0.5)
        elseif part == "right" then
            px = math.floor(r.x + 5 * r.w / 6 + 0.5)
        elseif part ~= "centre" then
            fail("bad cell part '" .. tostring(part) .. "'")
        end
        click_element(ctx, e, b, px, py)
        run_frame(ctx)
    end
end
handlers.click_cell       = cell_click(1)
handlers.right_click_cell = cell_click(2)

local function slot_click(b)
    return function(ctx, arg)
        settle(ctx)
        local letter = pusher_letter(arg.pusher)
        local times  = arg.times or 1
        for _, s in ipairs(arg.slots or {}) do
            for _ = 1, times do
                local e = require_element(ctx, { id = "slot:" .. letter .. ":" .. tostring(s) }, true)
                click_element(ctx, e, b)
            end
        end
        run_frame(ctx)
    end
end
handlers.click_slot       = slot_click(1)
handlers.right_click_slot = slot_click(2)

function handlers.move_mouse(ctx, arg)
    settle(ctx)
    do_move(ctx, arg[1] or arg.x, arg[2] or arg.y)
    run_frame(ctx)
end

function handlers.hover_button(ctx, sel)
    settle(ctx)
    local e = require_element(ctx, sel, false)
    local x, y = UI.centre(e.rect)
    do_move(ctx, x, y)
    run_frame(ctx)
end

function handlers.wait(ctx, n)
    for _ = 1, n do run_frame(ctx) end
end

function handlers.wait_until(ctx, arg)
    local max = arg.max_frames or WAIT_UNTIL_DEFAULT
    local function holds()
        if arg.text ~= nil and not text_contains(arg.text) then return false end
        if arg.matrix ~= nil and not matrix_equal(current_matrix(ctx), arg.matrix) then
            return false
        end
        return true
    end
    local n = 0
    while not holds() do
        if n >= max then fail("wait_until exceeded " .. max .. " frames") end
        run_frame(ctx)
        n = n + 1
    end
end

function handlers.assert_text(ctx, s)
    settle(ctx)
    if not text_contains(s) then fail("text '" .. s .. "' not drawn") end
end

function handlers.assert_no_text(ctx, s)
    settle(ctx)
    if text_contains(s) then fail("text '" .. s .. "' was drawn") end
end

function handlers.assert_button(ctx, arg)
    settle(ctx)
    local e, desc = resolve(ctx, arg)
    if arg.visible == false then
        if e then fail("element " .. desc .. " is visible") end
        return
    end
    if not e then fail("no visible element " .. desc) end
    if arg.enabled ~= nil and (e.enabled == true) ~= arg.enabled then
        fail("element '" .. e.id .. "' enabled is " .. tostring(e.enabled == true))
    end
    if arg.selected ~= nil and (e.selected == true) ~= arg.selected then
        fail("element '" .. e.id .. "' selected is " .. tostring(e.selected == true))
    end
end

function handlers.assert_matrix(ctx, expected)
    settle(ctx)
    local got = current_matrix(ctx)
    if not matrix_equal(got, expected) then
        fail("matrix is " .. serialise(got) .. ", expected " .. serialise(expected))
    end
end

function handlers.assert_tile(ctx, arg)
    settle(ctx)
    local scene = ctx.sm.current
    if not (scene and scene.ui_tile) then fail("scene has no tiles") end
    local x, y = arg.x or arg[1], arg.y or arg[2]
    local tile = scene:ui_tile(x, y)
    local where = "tile at " .. tostring(x) .. "," .. tostring(y)
    if arg.kind == nil then
        if tile ~= nil then fail(where .. " is " .. serialise(tile) .. ", expected empty") end
        return
    end
    if tile == nil then fail(where .. " is empty") end
    for _, f in ipairs({ "kind", "op", "dir" }) do
        if arg[f] ~= nil and tile[f] ~= arg[f] then
            fail(where .. " " .. f .. " is " .. tostring(tile[f]) .. ", expected " .. tostring(arg[f]))
        end
    end
end

local function step_key(step)
    if type(step) ~= "table" then fail("step is not a table") end
    local keys = {}
    for k in pairs(step) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        if not STEP_KEY_SET[k] then fail("unknown step key '" .. tostring(k) .. "'") end
    end
    if #keys ~= 1 then fail("step must have exactly one key (has " .. #keys .. ")") end
    return keys[1]
end

-- Runs one spec. Returns ok, err. err is "step <i> <step> — <reason>" for a
-- step failure, or "setup — <reason>" before the first step.
function UIRunner.run_spec(spec, opts)
    opts = opts or {}
    local step_index = nil

    local ok, err = pcall(function()
        local Progress   = require("lua/game/progress")
        local make_scene = opts.make_scene or function(sm)
            return require("lua/game/scenes/start_scene").new(sm)
        end

        Progress.reset()
        local given = spec.given or {}
        if given.solved == "all" then
            Progress.unlock_all()
        elseif type(given.solved) == "table" then
            for _, i in ipairs(given.solved) do Progress.mark_solved(i) end
        end

        -- Mark all cutscenes as seen by default so navigating between worlds
        -- doesn't unexpectedly trigger cutscenes in unrelated specs.
        -- Specs that intentionally test cutscene triggering must list the
        -- worlds whose cutscene should remain unseen in given.cutscenes_unseen.
        local PuzzleLoader   = require("lua/game/puzzle_loader")
        local unseen_cutscenes = {}
        if type(given.cutscenes_unseen) == "table" then
            for _, w in ipairs(given.cutscenes_unseen) do
                unseen_cutscenes[w] = true
            end
        end
        for w = 1, PuzzleLoader.world_count() do
            if not unseen_cutscenes[w] then
                Progress.mark_cutscene_seen(w)
            end
        end

        local sm = SceneManager.new(SCREEN_W, SCREEN_H)
        sm:switch(make_scene(sm))
        Stubs.set_mouse(0, 0)
        local ctx = new_ctx(sm)
        run_frame(ctx)

        for i, step in ipairs(spec.steps or {}) do
            step_index = i
            local k = step_key(step)
            handlers[k](ctx, step[k])
        end
    end)

    if ok then return true, nil end

    local reason
    if type(err) == "table" and err[FAIL_TAG] then
        reason = err.reason
    else
        reason = tostring(err)
    end
    if step_index then
        return false, "step " .. step_index .. " " .. serialise(spec.steps[step_index]) .. " — " .. reason
    end
    return false, "setup — " .. reason
end

-- Loads a spec file (a single spec or a list of specs) and runs each spec.
-- Returns an array of { name = , ok = , err = }. If the file fails to load,
-- returns a single entry { name = nil, ok = false, err = , load_error = true }.
function UIRunner.run_file(path)
    local ok, loaded = pcall(dofile, path)
    if not ok then
        return { { name = nil, ok = false, err = tostring(loaded), load_error = true } }
    end

    local specs
    if type(loaded) == "table" and type(loaded.steps) == "table" then
        specs = { loaded }
    elseif type(loaded) == "table" and #loaded > 0 then
        specs = loaded
        for i, s in ipairs(specs) do
            if type(s) ~= "table" or type(s.steps) ~= "table" then
                return { { name = nil, ok = false, load_error = true,
                           err = "spec " .. i .. " has no steps" } }
            end
        end
    else
        return { { name = nil, ok = false, load_error = true,
                   err = "file must return a spec or a list of specs" } }
    end

    local results = {}
    for i, spec in ipairs(specs) do
        local sok, serr = UIRunner.run_spec(spec)
        results[#results + 1] = { name = spec.name or ("spec " .. i), ok = sok, err = serr }
    end
    return results
end

-- Prints C10 lines for one spec file's results. Returns passed, total.
function UIRunner.report(path, results)
    local passed, total = 0, 0
    for _, r in ipairs(results) do
        total = total + 1
        if r.load_error then
            print("FAIL  " .. path .. " — " .. tostring(r.err))
        elseif r.ok then
            print("PASS  " .. path .. " :: " .. tostring(r.name))
            passed = passed + 1
        else
            print("FAIL  " .. path .. " :: " .. tostring(r.name) .. " — " .. tostring(r.err))
        end
    end
    return passed, total
end

return UIRunner
