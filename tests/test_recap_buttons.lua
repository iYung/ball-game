-- test_recap_buttons.lua
-- Solution recap scene: Next puzzle / Replay / Menu are registry elements,
-- clicks dispatch through them, and clicks elsewhere do nothing.

local runner             = require("lua/headless/runner")
local UI                 = require("lua/core/ui")
local UIRunner           = require("lua/headless/ui_runner")
local Progress           = require("lua/game/progress")
local PuzzleLoader       = require("lua/game/puzzle_loader")
local Matrix             = require("lua/game/matrix_math")
local SolutionRecapScene = require("lua/game/scenes/solution_recap_scene")
local MatrixScene        = require("lua/game/scenes/matrix_scene")
local LevelSelectScene   = require("lua/game/scenes/level_select_scene")

local PUZZLE_INDEX = 1

local function new_recap()
    local mat = Matrix.new(1, 1, {{1}})
    local frames = {}
    for i = 1, 4 do
        frames[i] = { from_x = 0, from_y = 0, to_x = 10 * i, to_y = 0, matrix = mat }
    end
    local stats = { ticks = 10, pieces = 2, puzzle_name = "Test", puzzle_index = PUZZLE_INDEX }
    local ctx = runner.setup(function(_, sm)
        return SolutionRecapScene.new(stats, {}, frames, 0.1, sm)
    end)
    return ctx, ctx.sm.current
end

local function click_id(scene, sm, id)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "element " .. id .. " present")
    local x, y = UI.centre(e.rect)
    sm:mouse_pressed(x, y, 1)
end

-- Elements are well-formed, on screen, non-overlapping, all enabled.
do
    local _, scene = new_recap()
    local els = scene:ui_elements()
    assert(#els == 3, "three recap buttons, got " .. #els)
    local err = UIRunner.check_invariants(els)
    assert(err == nil, "invariants: " .. tostring(err))
    local expected = {
        { "recap:next", "Next puzzle" }, { "recap:replay", "Replay" }, { "recap:menu", "Menu" },
    }
    for i, pair in ipairs(expected) do
        assert(els[i].id == pair[1], "element " .. i .. " id " .. pair[1])
        assert(els[i].label == pair[2], "element " .. i .. " label " .. pair[2])
        assert(els[i].enabled == true, pair[1] .. " enabled")
    end
    print("PASS: recap elements pass invariants")
end

-- Click on Next puzzle switches to the next puzzle's MatrixScene.
do
    local ctx, scene = new_recap()
    click_id(scene, ctx.sm, "recap:next")
    local cur = ctx.sm.current
    assert(cur ~= scene, "scene switched")
    assert(getmetatable(cur) == MatrixScene, "switched to MatrixScene")
    local expected = PUZZLE_INDEX % PuzzleLoader.count() + 1
    assert(cur.puzzle_index == expected,
        "next puzzle index " .. expected .. ", got " .. tostring(cur.puzzle_index))
    print("PASS: recap Next puzzle click")
end

-- Click on Menu switches to LevelSelectScene.
do
    local ctx, scene = new_recap()
    click_id(scene, ctx.sm, "recap:menu")
    assert(getmetatable(ctx.sm.current) == LevelSelectScene, "switched to LevelSelectScene")
    print("PASS: recap Menu click")
end

-- Click on Replay resets the animation to frame 1 and stays on the recap.
do
    local ctx, scene = new_recap()
    scene:update(0.15)
    scene:update(0.15)
    assert(scene._frame_idx > 1, "precondition: animation advanced")
    click_id(scene, ctx.sm, "recap:replay")
    assert(ctx.sm.current == scene, "replay stays on recap")
    assert(scene._frame_idx == 1, "replay resets _frame_idx to 1, got " .. tostring(scene._frame_idx))
    print("PASS: recap Replay click")
end

-- A click outside the buttons does nothing.
do
    local ctx, scene = new_recap()
    ctx.sm:mouse_pressed(400, 300, 1)
    assert(ctx.sm.current == scene, "click at (400,300) does not switch scenes")
    assert(ctx.sm:is_idle(), "no fade started")
    print("PASS: recap click outside buttons does nothing")
end

Progress.reset()
print("ALL TESTS PASSED")
