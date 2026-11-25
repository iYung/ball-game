-- test_level_select.lua
-- Level select registry, hover-on-move-only fix, and registry hit-testing.

local S = require("tests/support/shipped")
local UI               = require("lua/core/ui")
local UIRunner         = require("lua/headless/ui_runner")
local Stubs            = require("lua/headless/stubs")
local Progress         = require("lua/game/progress")
local LevelSelectScene = require("lua/game/scenes/level_select_scene")
local MatrixScene      = require("lua/game/scenes/matrix_scene")

local function setup()
    Progress.reset()
    Stubs.set_mouse(0, 0)
    local ctx = runner.setup(function(_, sm) return LevelSelectScene.new(sm) end)
    return ctx.sm, ctx.sm.current
end

-- Level select showing the Basics world, which has the rows hovered below.
local function setup_basics()
    local sm, scene = setup()
    for _, n in ipairs(S.before("basics")) do Progress.mark_solved(n) end
    for w = 1, S.world("basics") do Progress.mark_cutscene_seen(w) end
    for _ = 2, S.world("basics") do sm:key_pressed("right") end
    assert(scene._world == S.world("basics"), "on the Basics world, got " .. scene._world)
    return sm, scene
end

local function row_centre(scene, i)
    local p = scene._world_puzzles[i]
    return UI.centre(UI.find(scene:ui_elements(), "puzzle:" .. p.index).rect)
end

-- Registry shape and order --------------------------------------------------
do
    local _, scene = setup()
    local els = scene:ui_elements()
    local PuzzleLoader = require("lua/game/puzzle_loader")
    local n_worlds = PuzzleLoader.world_count()
    assert(UIRunner.check_invariants(els) == nil, tostring(UIRunner.check_invariants(els)))
    assert(els[1].id == "world:1", "tab 1 comes first")
    assert(els[n_worlds].id == "world:" .. n_worlds, "last world tab is world:" .. n_worlds)
    assert(els[n_worlds + 1].id == "puzzle:1" and els[n_worlds + 1].selected == true, "row 1 selected by default")
    assert(#els == n_worlds + #scene._world_puzzles, "one tab per world plus one element per row")
    print("PASS: level_select: registry")
end

-- A resting cursor never overrides keyboard navigation -----------------------
do
    local sm, scene = setup_basics()
    local x, y = row_centre(scene, 3)
    Stubs.set_mouse(x, y)
    sm:mouse_moved(x, y)
    assert(scene.selected == 3, "hover selects row 3")
    sm:key_pressed("down")
    for _ = 1, 30 do scene:update(1 / 60) end
    assert(scene.selected == 4, "selection stays 4 with cursor resting on row 3, got " .. scene.selected)
    print("PASS: level_select: resting cursor does not override Down")
end

-- mouse_moved onto row 2 selects 2 ------------------------------------------
do
    local sm, scene = setup_basics()
    local x, y = row_centre(scene, 2)
    sm:mouse_moved(x, y)
    assert(scene.selected == 2, "mouse_moved selects row 2")
    print("PASS: level_select: mouse_moved selects row")
end

-- Click on row 1 opens the puzzle -------------------------------------------
do
    local sm, scene = setup()
    local x, y = row_centre(scene, 1)
    sm:mouse_pressed(x, y, 1)
    assert(getmetatable(sm.current) == MatrixScene, "click on row 1 switches to MatrixScene")
    print("PASS: level_select: click row opens puzzle")
end

-- Click on world:2 tab with nothing solved stays on world 1 (locked) ----------
do
    local sm, scene = setup()
    local x, y = UI.centre(UI.find(scene:ui_elements(), "world:2").rect)
    sm:mouse_pressed(x, y, 1)
    assert(sm.current == scene, "still on level select")
    assert(scene._world == 1, "locked tab click is no-op, got world " .. scene._world)
    print("PASS: level_select: locked world:2 tab click stays on world 1")
end

-- Right-click on a world tab does not switch scene --------------------------
do
    local sm, scene = setup()
    local x, y = UI.centre(UI.find(scene:ui_elements(), "world:1").rect)
    sm:mouse_pressed(x, y, 2)
    assert(sm.current == scene, "right-click on world tab should not switch scene")
    print("PASS: level_select: right-click on world tab does nothing")
end

Progress.reset()
Stubs.set_mouse(0, 0)
