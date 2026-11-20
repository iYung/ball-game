local StartScene = require("lua/game/scenes/start_scene")
local Progress   = require("lua/game/progress")
local UI         = require("lua/core/ui")
local UIRunner   = require("lua/headless/ui_runner")

local function fresh()
    return runner.setup(function(_, sm) return StartScene.new(sm) end)
end

Progress.reset()

-- Registry is well-formed and ordered
do
    local ctx = fresh()
    local els = ctx.sm.current:ui_elements()
    assert(#els == 2, "start scene has 2 elements, got " .. #els)
    assert(els[1].id == "start:play" and els[1].label == "Play", "first element is start:play")
    assert(els[2].id == "start:unlock_all" and els[2].label == "Unlock All", "second element is start:unlock_all")
    local err = UIRunner.check_invariants(els)
    assert(err == nil, "invariants hold: " .. tostring(err))
    local r = els[1].rect
    assert(r.x == 520 and r.y == 572 and r.w == 240 and r.h == 32, "play rect matches contract")
    r = els[2].rect
    assert(r.x == 560 and r.y == 625 and r.w == 160 and r.h == 22, "unlock rect matches contract")
    print("PASS: start scene registry well-formed")
end

-- Click at Unlock All's centre unlocks everything and advances
do
    local ctx = fresh()
    local scene = ctx.sm.current
    assert(not Progress.is_world_unlocked(2), "world 2 locked before unlock")
    local e = UI.find(scene:ui_elements(), "start:unlock_all")
    local x, y = UI.centre(e.rect)
    ctx.sm:mouse_pressed(x, y, 1)
    assert(Progress.is_world_unlocked(2), "world 2 unlocked after clicking Unlock All")
    assert(ctx.sm.current ~= scene, "clicking Unlock All advances")
    Progress.reset()
    print("PASS: click Unlock All unlocks and advances")
end

-- Click anywhere else advances without unlocking
do
    local ctx = fresh()
    local scene = ctx.sm.current
    ctx.sm:mouse_pressed(5, 5, 1)
    local LevelSelectScene = require("lua/game/scenes/level_select_scene")
    assert(getmetatable(ctx.sm.current) == LevelSelectScene, "click at (5,5) switches to level select")
    assert(ctx.sm.current ~= scene, "click at (5,5) advances")
    assert(not Progress.is_world_unlocked(2), "click at (5,5) does not unlock")
    print("PASS: click elsewhere advances")
end

Progress.reset()
