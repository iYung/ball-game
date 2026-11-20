-- Unit tests for the headless UI spec runner (lua/headless/ui_runner.lua),
-- the shared UI helpers (lua/core/ui.lua) and the headless stubs API.
-- Uses fake scenes injected through opts.make_scene.

local UI       = require("lua/core/ui")
local UIRunner = require("lua/headless/ui_runner")
local Stubs    = require("lua/headless/stubs")
local Progress = require("lua/game/progress")

-- Builds a fake scene. `elements` is the list ui_elements() returns.
local function fake_scene(elements)
    local s = { presses = {}, keys = {}, moves = {}, elements = elements or {} }
    function s:on_enter() end
    function s:on_exit() end
    function s:update(_dt) end
    function s:draw() love.graphics.print("HELLO") end
    function s:mouse_pressed(x, y, b) self.presses[#self.presses + 1] = { x, y, b } end
    function s:mouse_moved(x, y) self.moves[#self.moves + 1] = { x, y } end
    function s:key_pressed(k) self.keys[#self.keys + 1] = k end
    function s:ui_elements()
        local out = {}
        for i, e in ipairs(self.elements) do out[i] = e end
        return out
    end
    return s
end

local function btn(id, label, x, y, w, h, enabled)
    return { id = id, label = label, kind = "button",
             rect = { x = x, y = y, w = w, h = h }, enabled = enabled ~= false }
end

local function run(scene, steps)
    return UIRunner.run_spec({ name = "t", steps = steps },
                             { make_scene = function(_) return scene end })
end

local function expect_fail(ok, err, needle)
    assert(not ok, "expected failure containing '" .. needle .. "'")
    assert(err:find(needle, 1, true), "expected '" .. needle .. "' in: " .. tostring(err))
end

-- UI helpers ---------------------------------------------------------------
do
    local r = { x = 10, y = 20, w = 30, h = 40 }
    assert(UI.hit(r, 10, 20), "top-left corner is inside")
    assert(UI.hit(r, 39, 59), "last pixel is inside")
    assert(not UI.hit(r, 40, 30), "right edge is outside (half-open)")
    assert(not UI.hit(r, 20, 60), "bottom edge is outside (half-open)")
    assert(not UI.hit(r, 9, 30), "left of rect is outside")

    local x, y = UI.centre({ x = 0, y = 0, w = 5, h = 3 })
    assert(x == 3 and y == 2, "centre rounds half up, got " .. x .. "," .. y)
    x, y = UI.centre({ x = 622, y = 666, w = 42, h = 48 })
    assert(x == 643 and y == 690, "centre of Run rect")

    local a = { x = 0, y = 0, w = 10, h = 10 }
    assert(UI.overlaps(a, { x = 5, y = 5, w = 10, h = 10 }), "overlapping rects")
    assert(not UI.overlaps(a, { x = 10, y = 0, w = 10, h = 10 }), "shared vertical edge")
    assert(not UI.overlaps(a, { x = 0, y = 10, w = 10, h = 10 }), "shared horizontal edge")
    assert(not UI.overlaps(a, { x = 10, y = 10, w = 5, h = 5 }), "shared corner")

    local els = { btn("a", "A", 0, 0, 10, 10), btn("b", "B", 5, 5, 10, 10) }
    assert(UI.element_at(els, 6, 6).id == "a", "element_at returns first in list order")
    assert(UI.element_at(els, 12, 12).id == "b", "element_at finds second")
    assert(UI.element_at(els, 100, 100) == nil, "element_at miss")
    assert(UI.find(els, "b") == els[2], "find by id")
    assert(UI.find(els, "zz") == nil, "find miss")
    print("PASS: ui_runner: UI helpers")
end

-- Stubs API ----------------------------------------------------------------
do
    assert(love.graphics.getWidth() == 1280 and love.graphics.getHeight() == 720, "screen size")
    Stubs.set_mouse(12, 34)
    assert(love.mouse.getX() == 12 and love.mouse.getY() == 34, "virtual cursor")
    local mx, my = love.mouse.getPosition()
    assert(mx == 12 and my == 34, "getPosition")
    assert(love.mouse.isDown(1) == false, "isDown is false")
    Stubs.set_mouse(0, 0)

    Stubs.clear_text()
    love.graphics.print("abc", 0, 0)
    love.graphics.printf(42, 0, 0, 100, "left")
    love.graphics.print({ { 1, 1, 1 }, "red", { 0, 0, 0 }, "blue" }, 0, 0)
    local t = Stubs.drawn_text()
    assert(#t == 3 and t[1] == "abc" and t[2] == "42" and t[3] == "redblue",
           "text recording: " .. table.concat(t, "|"))
    Stubs.clear_text()
    assert(#Stubs.drawn_text() == 0, "clear_text")
    print("PASS: ui_runner: stubs API")
end

-- click_button reaches the scene through sm at the rounded centre ----------
do
    local s = fake_scene({ btn("b:go", "Go", 100, 100, 41, 21) })
    local ok, err = run(s, { { click_button = "Go" }, { right_click_button = { id = "b:go" } } })
    assert(ok, tostring(err))
    assert(#s.presses == 2, "two presses recorded, got " .. #s.presses)
    assert(s.presses[1][1] == 121 and s.presses[1][2] == 111 and s.presses[1][3] == 1,
           "left click at rounded centre")
    assert(s.presses[2][3] == 2, "right click uses button 2")
    assert(s.moves[1][1] == 121 and s.moves[1][2] == 111, "mouse_moved fired before press")
    assert(love.mouse.getX() == 121, "virtual cursor follows the click")
    print("PASS: ui_runner: click_button hits the rounded centre via SceneManager")
end

-- press and raw click ------------------------------------------------------
do
    local s = fake_scene({})
    local ok, err = run(s, { { press = "return" }, { click = { 5, 6 } } })
    assert(ok, tostring(err))
    assert(s.keys[1] == "return", "key forwarded")
    assert(s.presses[1][1] == 5 and s.presses[1][2] == 6, "raw click forwarded")
    print("PASS: ui_runner: press and raw click")
end

-- disabled target fails ----------------------------------------------------
do
    local s = fake_scene({ btn("b:off", "Off", 0, 0, 10, 10, false) })
    local ok, err = run(s, { { click_button = "Off" } })
    expect_fail(ok, err, "element 'b:off' is disabled")
    assert(err:find("step 1 ", 1, true), "failure names the step: " .. err)
    assert(#s.presses == 0, "disabled element was not clicked")
    print("PASS: ui_runner: disabled target fails")
end

-- missing target fails -----------------------------------------------------
do
    local s = fake_scene({})
    local ok, err = run(s, { { click_button = "Nope" } })
    expect_fail(ok, err, "no visible element labelled 'Nope'")
    ok, err = run(s, { { click_button = { id = "x:y" } } })
    expect_fail(ok, err, "no visible element id 'x:y'")
    print("PASS: ui_runner: missing target fails")
end

-- ambiguous label fails ----------------------------------------------------
do
    local s = fake_scene({ btn("a", "Row Swap", 0, 0, 10, 10), btn("b", "Row Swap", 20, 0, 10, 10) })
    local ok, err = run(s, { { click_button = "Row Swap" } })
    expect_fail(ok, err, "ambiguous label 'Row Swap' (2 matches)")
    ok, err = run(s, { { click_button = { id = "b" } } })
    assert(ok, tostring(err))
    print("PASS: ui_runner: ambiguous label fails, id works")
end

-- unknown step key fails ---------------------------------------------------
do
    local ok, err = run(fake_scene({}), { { press = "a" }, { frobnicate = 1 } })
    expect_fail(ok, err, "unknown step key 'frobnicate'")
    assert(err:find("step 2 ", 1, true), "failure names step 2: " .. err)
    print("PASS: ui_runner: unknown step key fails")
end

-- assert_text / assert_no_text ---------------------------------------------
do
    local ok, err = run(fake_scene({}), { { assert_text = "HELL" }, { assert_no_text = "BYE" } })
    assert(ok, tostring(err))
    ok, err = run(fake_scene({}), { { assert_text = "BYE" } })
    expect_fail(ok, err, "text 'BYE' not drawn")
    ok, err = run(fake_scene({}), { { assert_no_text = "HELLO" } })
    expect_fail(ok, err, "text 'HELLO' was drawn")
    print("PASS: ui_runner: assert_text / assert_no_text")
end

-- assert_button ------------------------------------------------------------
do
    local e = btn("b:sel", "Sel", 0, 0, 10, 10)
    e.selected = true
    local s = fake_scene({ e, btn("b:off", "Off", 20, 0, 10, 10, false) })
    local ok, err = run(s, {
        { assert_button = { id = "b:sel", visible = true, enabled = true, selected = true } },
        { assert_button = { label = "Off", enabled = false, selected = false } },
        { assert_button = { id = "b:gone", visible = false } },
    })
    assert(ok, tostring(err))
    ok, err = run(s, { { assert_button = { label = "Off", enabled = true } } })
    expect_fail(ok, err, "enabled is false")
    print("PASS: ui_runner: assert_button")
end

-- wait_until timeout message, and success --------------------------------
do
    local ok, err = run(fake_scene({}), { { wait_until = { text = "NEVER", max_frames = 7 } } })
    expect_fail(ok, err, "wait_until exceeded 7 frames")

    local s = fake_scene({})
    local frames = 0
    function s:update() frames = frames + 1 end
    function s:draw() if frames >= 5 then love.graphics.print("READY") end end
    ok, err = run(s, { { wait_until = { text = "READY", max_frames = 20 } } })
    assert(ok, tostring(err))
    print("PASS: ui_runner: wait_until")
end

-- matrix / tile steps fail on a scene without them ------------------------
do
    local ok, err = run(fake_scene({}), { { assert_matrix = { { 1 } } } })
    expect_fail(ok, err, "scene has no matrix")
    ok, err = run(fake_scene({}), { { assert_tile = { x = 1, y = 1 } } })
    expect_fail(ok, err, "scene has no tiles")

    local s = fake_scene({})
    function s:ui_matrix() return { { 1, 2 }, { 3, 4 } } end
    function s:ui_tile(x, y) if x == 1 and y == 1 then return { kind = "pusher" } end end
    ok, err = run(s, {
        { assert_matrix = { { 1, 2 }, { 3, 4 } } },
        { assert_tile = { x = 1, y = 1, kind = "pusher" } },
        { assert_tile = { x = 2, y = 2 } },
    })
    assert(ok, tostring(err))
    ok, err = run(s, { { assert_matrix = { { 1, 2 }, { 3, 5 } } } })
    expect_fail(ok, err, "matrix is")
    print("PASS: ui_runner: assert_matrix / assert_tile")
end

-- invariant failure inside a spec reports the frame ------------------------
do
    local ok, err = run(fake_scene({ btn("a", "A", 0, 0, 10, 10), btn("b", "B", 5, 5, 10, 10) }), {})
    expect_fail(ok, err, "invariant: 'a' overlaps 'b' at frame 1")
    print("PASS: ui_runner: invariant failure in spec includes frame")
end

-- check_invariants ---------------------------------------------------------
do
    local ci = UIRunner.check_invariants
    assert(ci({}) == nil, "empty list is fine")
    assert(ci({ btn("a", "A", 0, 0, 10, 10), btn("b", "B", 10, 0, 10, 10),
                btn("c", "C", 0, 10, 10, 10) }) == nil, "edge-sharing rects are accepted")
    assert(ci({ btn("a", "A", 1270, 710, 10, 10) }) == nil, "flush with the screen edge is fine")

    assert(ci({ btn("a", "A", 0, 0, 10, 10), btn("b", "B", 9, 9, 10, 10) })
           == "invariant: 'a' overlaps 'b'", "overlap detected")
    local dis = btn("b", "B", 9, 9, 10, 10, false)
    assert(ci({ btn("a", "A", 0, 0, 10, 10), dis }) == "invariant: 'a' overlaps 'b'",
           "overlap with a disabled element detected")
    assert(ci({ btn("a", "A", 1275, 0, 10, 10) }) == "invariant: 'a' off screen", "off right")
    assert(ci({ btn("a", "A", -1, 0, 10, 10) }) == "invariant: 'a' off screen", "off left")
    assert(ci({ btn("a", "A", 0, 715, 10, 10) }) == "invariant: 'a' off screen", "off bottom")
    assert(ci({ btn("a", "A", 0, 0, 10, 10), btn("a", "A2", 20, 0, 10, 10) })
           == "invariant: duplicate id 'a'", "duplicate id")

    local function malformed(e, n)
        local r = ci({ btn("ok", "OK", 100, 100, 10, 10), e })
        assert(r and r:find("invariant: malformed element 2:", 1, true),
               "malformed (" .. n .. "): " .. tostring(r))
    end
    malformed(btn("", "X", 0, 0, 10, 10), "empty id")
    malformed(btn("x", "", 0, 0, 10, 10), "empty label")
    malformed({ id = "x", label = "X", kind = "widget", rect = { x = 0, y = 0, w = 1, h = 1 }, enabled = true }, "bad kind")
    malformed(btn("x", "X", 0, 0, 0, 10), "zero width")
    malformed(btn("x", "X", 0, 0, 10, -1), "negative height")
    malformed({ id = "x", label = "X", kind = "cell", enabled = true }, "no rect")

    -- Check order: malformed before off-screen before overlap.
    assert(ci({ btn("a", "A", -5, 0, 10, 10), btn("b", "B", 0, 0, 10, 10) })
           == "invariant: 'a' off screen", "off screen reported before overlap")
    print("PASS: ui_runner: check_invariants")
end

-- serialise ----------------------------------------------------------------
do
    local s = UIRunner.serialise({ click_slot = { pusher = 1, slots = { 1, 2 }, times = 2 } })
    assert(s == "{click_slot = {pusher = 1, slots = {1, 2}, times = 2}}", "serialise: " .. s)
    assert(UIRunner.serialise({ press = "return" }) == '{press = "return"}', "serialise string")
    print("PASS: ui_runner: serialise")
end

-- given.solved applies to Progress, and every spec resets it --------------
do
    local seen
    local function probe()
        local s = fake_scene({})
        seen = { Progress.is_solved(2), Progress.is_solved(3) }
        return s
    end
    local ok, err = UIRunner.run_spec({ given = { solved = { 2 } }, steps = {} },
                                      { make_scene = probe })
    assert(ok, tostring(err))
    assert(seen[1] == true and seen[2] == false, "given.solved marks listed puzzles")
    ok, err = UIRunner.run_spec({ steps = {} }, { make_scene = probe })
    assert(ok, tostring(err))
    assert(seen[1] == false, "next spec starts with progress reset")
    Progress.reset()
    print("PASS: ui_runner: given.solved and progress reset")
end

-- run_file on a list-of-specs fixture --------------------------------------
do
    local dir = "tests/ui_fixtures"
    os.execute("mkdir -p " .. dir)
    local path = dir .. "/tmp_list_spec.lua"
    local f = assert(io.open(path, "w"))
    f:write([[
return {
  { name = "good", steps = { { wait = 1 } } },
  { name = "bad",  steps = { { nonsense = true } } },
}
]])
    f:close()
    local results = UIRunner.run_file(path)
    os.remove(path)
    os.remove(dir) -- removes the directory only if it is empty
    assert(#results == 2, "two results")
    assert(results[1].name == "good" and results[1].ok, "first spec passes")
    assert(results[2].name == "bad" and not results[2].ok, "second spec fails")
    assert(results[2].err:find("unknown step key 'nonsense'", 1, true), results[2].err)

    local missing = UIRunner.run_file(dir .. "/does_not_exist.lua")
    assert(#missing == 1 and missing[1].load_error and not missing[1].ok, "load error entry")
    Progress.reset()
    print("PASS: ui_runner: run_file")
end

print("ALL TESTS PASSED")
