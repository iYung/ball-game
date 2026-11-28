-- Ops column layout (puzzle scene UI overhaul): palette in a 2-wide column on the left
-- (x 0..120, y 0..540) scrolling one row at a time with ^ / v arrows; Run/Reset/Menu/Continue
-- in a 2x2 block in the bottom-right corner of the bottom bar (y >= 540).

local S = require("tests/support/shipped")
local runner       = require("lua/headless/runner")
local UI           = require("lua/core/ui")
local UIRunner     = require("lua/headless/ui_runner")
local PuzzleLoader = require("lua/game/puzzle_loader")

local CMD_X       = 1280 - 10 - (2 * 72 + 6)   -- left edge of the command block
local BAR_Y       = 540
local OPS_W       = 120

local function new_scene(n)
    local ctx = runner.setup(function(_, sm)
        return require("lua/game/scenes/matrix_scene").new(n, sm)
    end)
    local scene = ctx.sm.current
    scene:draw()  -- sets _tl_top so timeline elements exist
    return scene
end

local function click(scene, id)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "element " .. id .. " present")
    local x, y = UI.centre(e.rect)
    scene:mouse_pressed(x, y, 1)
end

local function is_scroll(id) return id == "palette:scroll_up" or id == "palette:scroll_down" end

-- Visible palette item ids (everything but the scroll arrows), left to right.
local function item_ids(scene)
    local out = {}
    for _, e in ipairs(scene:ui_elements()) do
        if e.id:sub(1, 8) == "palette:" and not is_scroll(e.id) then out[#out + 1] = e.id end
    end
    return out
end

local function check_bar(scene, label)
    local els = scene:ui_elements()
    local err = UIRunner.check_invariants(els)
    assert(err == nil, label .. ": " .. tostring(err))
    for _, e in ipairs(els) do
        if e.id:sub(1, 4) == "cmd:" then
            assert(e.rect.y >= BAR_Y and e.rect.x >= CMD_X, label .. ": " .. e.id .. " outside the bar corner")
        end
        if e.id:sub(1, 8) == "palette:" then
            assert(e.rect.x >= 0 and e.rect.x + e.rect.w <= OPS_W and e.rect.y >= 0 and e.rect.y + e.rect.h <= BAR_Y,
                label .. ": " .. e.id .. " leaves the ops column")
        end
    end
    for _, id in ipairs({ "cmd:run", "cmd:reset", "cmd:menu" }) do
        assert(UI.find(els, id), label .. ": " .. id .. " missing")
    end
end

-- Invariants hold for every puzzle at every scroll position.
do
    local scrolled = {}
    for i = 1, PuzzleLoader.count() do
        local scene = new_scene(i)
        check_bar(scene, "puzzle " .. i .. " scroll 0")
        local max = scene._palette_max_scroll or 0
        if UI.find(scene:ui_elements(), "palette:scroll_down") then
            scrolled[#scrolled + 1] = i .. "(" .. max .. ")"
            for s = 1, max do
                click(scene, "palette:scroll_down")
                assert(scene._palette_scroll == s, "puzzle " .. i .. " reached scroll " .. s)
                check_bar(scene, "puzzle " .. i .. " scroll " .. s)
            end
        else
            assert(max == 0, "puzzle " .. i .. ": no arrows means nothing to scroll")
            assert(not UI.find(scene:ui_elements(), "palette:scroll_up"), "no arrows when it fits")
        end
    end
    print("PASS: bar invariants on all puzzles and scroll positions; scrolled: " .. table.concat(scrolled, ", "))
end

-- Small palette: two-wide column from x=8, command buttons right-aligned.
do
    local scene = new_scene(S.puzzle("flip"))
    local els = scene:ui_elements()
    local function rx(id) return UI.find(els, id).rect end
    assert(rx("palette:pusher").x == 8 and rx("palette:pusher").w == 48, "P at the column's left edge")
    assert(rx("palette:transpose").x == 8, "first op starts a new row after the separator")
    assert(rx("palette:transpose").y == rx("palette:pusher").y + 56 + 14, "separator gap after P")
    for _, id in ipairs({ "palette:pusher", "palette:drag", "palette:erase" }) do
        assert(UI.find(els, id), id .. " present")
    end
    for i, id in ipairs({ "cmd:run", "cmd:reset", "cmd:menu" }) do
        local r = rx(id)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        assert(r.x == CMD_X + col * 78 and r.w == 72 and r.h == 40 and r.y == 720 - 10 - 86 + row * 46,
            id .. " position")
    end
    assert(rx("cmd:menu").x + rx("cmd:menu").w <= 1280 - 10, "command buttons keep a right margin")
    print("PASS: small palette and command zone")
end

-- Puzzle 1 (all ten ops) fits: no arrows, last button ends at y=454.
do
    local scene = new_scene(S.puzzle("identity"))
    local els = scene:ui_elements()
    assert(not UI.find(els, "palette:scroll_up") and not UI.find(els, "palette:scroll_down"), "no scroll arrows")
    assert(#item_ids(scene) == 10 + 3, "all 10 ops plus P, Mv, [X] shown, got " .. #item_ids(scene))
    local last = UI.find(els, "palette:erase").rect
    assert(last.y + last.h == 454, "last button ends at y=454, got " .. (last.y + last.h))
    print("PASS: full palette fits")
end

-- A definition with every op plus several fixed ops overflows: arrows scroll one slot,
-- every item reachable once. (No shipped puzzle overflows.)
do
    local def = {
        name = "overflow", grid_w = 10, grid_h = 10,
        source = { x=2, y=5 }, sink = { x=10, y=5 }, gaps = {},
        input  = { rows=2, cols=2, values={ {1,0}, {0,1} } },
        target = { rows=2, cols=2, values={ {1,0}, {0,1} } },
        fixed_ops = { "transpose", "rotate_90", "flip_h", "flip_v",
                      { op = "scalar_mul", params = { scalar = -1 } } },
    }
    local ctx = runner.setup(function(_, sm)
        return require("lua/game/scenes/matrix_scene").new_from_def(def, sm)
    end)
    local scene = ctx.sm.current
    scene:draw()
    local left  = UI.find(scene:ui_elements(), "palette:scroll_up")
    local right = UI.find(scene:ui_elements(), "palette:scroll_down")
    assert(left and right, "scroll arrows present")
    assert(left.label == "^" and right.label == "v", "arrow labels")
    assert(left.enabled == false and right.enabled == true, "arrow states at scroll 0")
    check_bar(scene, "overflow scroll 0")

    -- Select the first op; selection must survive scrolling.
    local first_op
    for _, id in ipairs(item_ids(scene)) do
        if id ~= "palette:pusher" then first_op = id; break end
    end
    click(scene, first_op)
    local sel = scene.palette:selected()
    assert(sel and sel.kind == "op" and "palette:" .. sel.op == first_op, "op selected")

    click(scene, "palette:scroll_up")
    assert(scene._palette_scroll == 0, "disabled left arrow is a no-op")

    local seen = {}
    for _, id in ipairs(item_ids(scene)) do seen[id] = true end
    local before = item_ids(scene)
    click(scene, "palette:scroll_down")
    local after = item_ids(scene)
    assert(after[1] == before[2], "scrolling down shifts by exactly one row (P sits alone in row 0)")
    check_bar(scene, "overflow scroll 1")
    for s = 2, scene._palette_max_scroll do
        click(scene, "palette:scroll_down")
        check_bar(scene, "overflow scroll " .. s)
    end
    for _, id in ipairs(item_ids(scene)) do seen[id] = true end

    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    assert(n == 10 + 5 + 3, "all 10 ops, 5 fixed ops plus P, Mv, [X] reachable, got " .. n)
    local last = scene:ui_elements()
    assert(UI.find(last, "palette:scroll_down").enabled == false, "right disabled at the end")
    assert(UI.find(last, "palette:scroll_up").enabled == true, "left enabled at the end")
    click(scene, "palette:scroll_down")
    assert(scene._palette_scroll == scene._palette_max_scroll, "disabled right arrow is a no-op")
    sel = scene.palette:selected()
    assert(sel and "palette:" .. sel.op == first_op, "selection kept after scrolling")

    scene:load_puzzle(S.puzzle("identity"))
    assert(scene._palette_scroll == 0, "load_puzzle resets the scroll")
    print("PASS: overflow scrolling")
end

-- Add Only: only fixed ops plus tools.
do
    local scene = new_scene(S.puzzle("add_only"))
    local seen = {}
    for _, id in ipairs(item_ids(scene)) do
        seen[id] = true
        if id ~= "palette:pusher" and id ~= "palette:drag" and id ~= "palette:erase" then
            assert(id:sub(1, 14) == "palette:fixed:", "Add Only offers no editable op, got " .. id)
        end
    end
    assert(seen["palette:fixed:rotate_90"] and seen["palette:fixed:edge_add"] and seen["palette:fixed:scalar_mul"],
        "Add Only fixed ops")
    print("PASS: Add Only fixed-only palette")
end

-- The puzzle hint is drawn in the HUD, without "[Esc] Menu".
do
    local Stubs = require("lua/headless/stubs")
    local scene = new_scene(S.puzzle("scale_shift"))
    Stubs.clear_text()
    scene:draw()
    local found = false
    for _, t in ipairs(Stubs.drawn_text()) do
        if t == string.format("Puzzle %d/%d", S.puzzle("scale_shift"), PuzzleLoader.count()) then found = true end
        assert(not t:find("%[Esc%] Menu"), "old hint text still drawn")
    end
    assert(found, "Puzzle N/M hint drawn")
    print("PASS: hint in HUD")
end
