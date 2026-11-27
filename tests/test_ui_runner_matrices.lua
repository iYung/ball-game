-- Unit tests for the UI runner steps used by two-matrix puzzles:
-- assert_matrices, wait_until.matrices, assert_tile facing / index, and
-- mouse_down / mouse_up. Uses fake scenes injected through opts.make_scene.

local UIRunner = require("lua/headless/ui_runner")
local Progress = require("lua/game/progress")

local function fake_scene(elements)
    local s = { elements = elements or {}, log = {} }
    function s:on_enter() end
    function s:on_exit() end
    function s:update(_dt) self.log[#self.log + 1] = { "update" } end
    function s:draw() end
    function s:mouse_pressed(x, y, b) self.log[#self.log + 1] = { "press", x, y, b } end
    function s:mouse_moved(x, y) self.log[#self.log + 1] = { "move", x, y } end
    function s:mouse_released(x, y, b) self.log[#self.log + 1] = { "release", x, y, b } end
    function s:key_pressed(k) self.log[#self.log + 1] = { "key", k } end
    function s:ui_elements()
        local out = {}
        for i, e in ipairs(self.elements) do out[i] = e end
        return out
    end
    return s
end

local function btn(id, x, y, enabled)
    return { id = id, label = id, kind = "button",
             rect = { x = x, y = y, w = 20, h = 20 }, enabled = enabled ~= false }
end

local function run(scene, steps)
    return UIRunner.run_spec({ name = "t", steps = steps },
                             { make_scene = function(_) return scene end })
end

local function expect_fail(ok, err, needle)
    assert(not ok, "expected failure containing '" .. needle .. "'")
    assert(err:find(needle, 1, true), "expected '" .. needle .. "' in: " .. tostring(err))
end

-- assert_matrices ------------------------------------------------------------
do
    local s = fake_scene()
    function s:ui_matrices()
        return {
            { x = 1, y = 2, values = { { 1, 2 } } },
            { x = 4, y = 5, values = { { 3 }, { 4 } } },
        }
    end
    local a = { x = 1, y = 2, values = { { 1, 2 } } }
    local b = { x = 4, y = 5, values = { { 3 }, { 4 } } }

    local ok, err = run(s, {
        { assert_matrices = { a, b } },
        { assert_matrices = { { values = a.values }, { values = b.values } } },
        { assert_matrices = { { x = 1, values = a.values }, { y = 5, values = b.values } } },
    })
    assert(ok, tostring(err))

    local bad = {
        { "too few",     { a } },
        { "too many",    { a, b, b } },
        { "wrong order", { b, a } },
        { "wrong value", { a, { values = { { 3 }, { 9 } } } } },
        { "wrong shape", { a, { values = { { 3, 4 } } } } },
        { "wrong x",     { { x = 2, values = a.values }, b } },
        { "wrong y",     { a, { y = 6, values = b.values } } },
        { "no values",   { { x = 1, y = 2 }, b } },
    }
    for _, case in ipairs(bad) do
        ok, err = run(s, { { assert_matrices = case[2] } })
        expect_fail(ok, err, "matrices are ")
        assert(err:find(", expected {", 1, true), case[1] .. ": " .. err)
    end

    ok, err = run(s, { { assert_matrices = { a } } })
    expect_fail(ok, err, "matrices are " .. UIRunner.serialise(s:ui_matrices())
                         .. ", expected " .. UIRunner.serialise({ a }))

    function s:ui_matrices() return {} end
    ok, err = run(s, { { assert_matrices = {} } })
    assert(ok, tostring(err))
    print("PASS: ui_runner: assert_matrices")
end

-- scene without ui_matrices ---------------------------------------------------
do
    local ok, err = run(fake_scene(), { { assert_matrices = { { values = { { 1 } } } } } })
    expect_fail(ok, err, "scene has no matrices")
    ok, err = run(fake_scene(), { { wait_until = { matrices = {}, max_frames = 3 } } })
    expect_fail(ok, err, "scene has no matrices")
    print("PASS: ui_runner: scene has no matrices")
end

-- wait_until.matrices ----------------------------------------------------------
do
    local s = fake_scene()
    local frames = 0
    function s:update() frames = frames + 1 end
    function s:ui_matrices()
        if frames < 5 then
            return { { x = 1, y = 1, values = { { 1 } } }, { x = 3, y = 1, values = { { 2 } } } }
        end
        return { { x = 3, y = 1, values = { { 3 } } } }
    end
    function s:draw() if frames >= 8 then love.graphics.print("DONE") end end

    local merged = { { x = 3, y = 1, values = { { 3 } } } }
    local ok, err = run(s, { { wait_until = { matrices = merged, max_frames = 20 } } })
    assert(ok, tostring(err))
    assert(frames == 5, "stops as soon as the matrices match, ran " .. frames)

    frames = 0
    ok, err = run(s, { { wait_until = { matrices = merged, text = "DONE", max_frames = 20 } } })
    assert(ok, tostring(err))
    assert(frames == 8, "all conditions must hold, ran " .. frames)

    frames = 0
    ok, err = run(s, { { wait_until = { matrices = { { values = { { 9 } } } }, max_frames = 7 } } })
    expect_fail(ok, err, "wait_until exceeded 7 frames")
    print("PASS: ui_runner: wait_until matrices")
end

-- assert_tile facing / index ---------------------------------------------------
do
    local s = fake_scene()
    local tiles = {
        { kind = "op", op = "matrix_add", facing = "bottom" },
        { kind = "source", index = 2 },
    }
    function s:ui_tile(x, _y) return tiles[x] end
    local ok, err = run(s, {
        { assert_tile = { x = 1, y = 1, kind = "op", op = "matrix_add", facing = "bottom" } },
        { assert_tile = { x = 2, y = 1, kind = "source", index = 2 } },
        { assert_tile = { x = 1, y = 1, kind = "op" } },
        { assert_tile = { x = 2, y = 1, kind = "source" } },
    })
    assert(ok, tostring(err))
    ok, err = run(s, { { assert_tile = { x = 1, y = 1, kind = "op", facing = "left" } } })
    expect_fail(ok, err, "tile at 1,1 facing is bottom, expected left")
    ok, err = run(s, { { assert_tile = { x = 2, y = 1, kind = "source", index = 1 } } })
    expect_fail(ok, err, "tile at 2,1 index is 2, expected 1")
    ok, err = run(s, { { assert_tile = { x = 1, y = 1, kind = "op", index = 1 } } })
    expect_fail(ok, err, "tile at 1,1 index is nil, expected 1")
    print("PASS: ui_runner: assert_tile facing / index")
end

-- mouse_down / mouse_up --------------------------------------------------------
do
    local s = fake_scene({ btn("from", 10, 10), btn("to", 100, 200), btn("off", 300, 300, false) })
    local ok, err = run(s, {
        { mouse_down = "from" },
        { press = "t" },
        { right_click = { 500, 500 } },
        { mouse_up = { id = "to" } },
    })
    assert(ok, tostring(err))
    local got = {}
    for _, e in ipairs(s.log) do got[#got + 1] = table.concat(e, " ") end
    local want = table.concat({
        "update",                                                       -- first frame
        "move 20 20", "press 20 20 1", "update",                        -- mouse_down
        "key t", "update",
        "move 500 500", "press 500 500 2", "release 500 500 2", "update",
        "move 110 210", "release 110 210 1", "update",                  -- mouse_up
    }, "; ")
    assert(table.concat(got, "; ") == want, table.concat(got, "; "))
    assert(love.mouse.getX() == 110 and love.mouse.getY() == 210, "virtual cursor follows")

    for _, key in ipairs({ "mouse_down", "mouse_up" }) do
        ok, err = run(s, { { [key] = "nope" } })
        expect_fail(ok, err, "no visible element labelled 'nope'")
        ok, err = run(s, { { [key] = "off" } })
        expect_fail(ok, err, "element 'off' is disabled")
    end
    print("PASS: ui_runner: mouse_down / mouse_up")
end

-- mouse_down settles a running fade first --------------------------------------
do
    local s = fake_scene({ btn("a", 0, 0) })
    local idle_after, frames = 4, 0
    local ok, err = UIRunner.run_spec({ name = "t", steps = { { mouse_down = "a" } } }, {
        make_scene = function(sm)
            function sm:is_idle() return frames >= idle_after end
            function s:update() frames = frames + 1 end
            function s:mouse_pressed() assert(frames == idle_after, "pressed at frame " .. frames) end
            return s
        end,
    })
    assert(ok, tostring(err))
    assert(frames == idle_after + 1, "one frame after the press, ran " .. frames)
    print("PASS: ui_runner: mouse_down settles")
end

Progress.reset()
print("ALL TESTS PASSED")
