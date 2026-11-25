-- Unit tests for drag-and-drop in MatrixScene: ops -> grid cells, chips -> slots, slot -> slot / off the bar.

local S = require("tests/support/shipped")
local runner   = require("lua/headless/runner")
local UI       = require("lua/core/ui")
local Timeline = require("lua/game/timeline")

local function new_scene()
    local ctx = runner.setup(function(_, sm)
        return require("lua/game/scenes/matrix_scene").new(S.puzzle("identity"), sm)
    end)
    local scene = ctx.sm.current
    scene:draw()
    return scene
end

local function centre(scene, id)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "element " .. id .. " present")
    return UI.centre(e.rect)
end

local function drag(scene, from, to, btn)
    local fx, fy = centre(scene, from)
    local tx, ty
    if type(to) == "table" then tx, ty = to[1], to[2] else tx, ty = centre(scene, to) end
    scene:mouse_pressed(fx, fy, btn or 1)
    scene:mouse_moved(tx, ty)
    scene:draw()                      -- ghost draws without error
    scene:mouse_released(tx, ty, btn or 1)
end

local function click(scene, id)
    local x, y = centre(scene, id)
    scene:mouse_pressed(x, y, 1); scene:mouse_released(x, y, 1)
end

-- (a) palette -> cell places like click-select + click-cell; release elsewhere cancels.
do
    local scene = new_scene()
    drag(scene, "palette:pusher", "cell:3,3")
    assert(scene:ui_tile(3, 3) and scene:ui_tile(3, 3).kind == "pusher", "pusher placed by drag")
    local before = scene:ui_tile(4, 4)
    drag(scene, "palette:pusher", { 700, 300 })        -- released over the HUD, not a cell
    assert(scene:ui_tile(4, 4) == before, "cancelled drag places nothing")
    -- click-to-select path still works
    click(scene, "palette:pusher")
    assert(UI.find(scene:ui_elements(), "palette:pusher").selected)
    click(scene, "cell:5,5")
    assert(scene:ui_tile(5, 5) and scene:ui_tile(5, 5).kind == "pusher")
    assert(scene._dnd == nil)
end

-- (b) chip -> slot writes for the selected pusher; plain click still arms.
do
    local scene = new_scene()
    drag(scene, "palette:pusher", "cell:3,3")
    drag(scene, "chip:right", "slot:1:4")
    local c = Timeline.get(scene.timeline, 1, 4)
    assert(c and c.pusher == 1 and c.cmd == "right", "chip dropped on slot")
    click(scene, "chip:up")
    assert(scene.armed_chip == "up")
    click(scene, "slot:2:5")
    assert(Timeline.get(scene.timeline, 2, 5).cmd == "up")
    drag(scene, "chip:down", { 700, 300 })             -- not a slot: nothing written
    assert(Timeline.last_tick(scene.timeline) == 5)
end

-- (c) slot -> slot moves; slot -> off the bar removes; click on filled slot keeps click behaviour.
do
    local scene = new_scene()
    drag(scene, "palette:pusher", "cell:3,3")
    drag(scene, "chip:left", "slot:1:2")
    drag(scene, "slot:1:2", "slot:3:7")
    assert(Timeline.get(scene.timeline, 1, 2) == nil)
    assert(Timeline.get(scene.timeline, 3, 7).cmd == "left")
    drag(scene, "slot:3:7", { 700, 300 })
    assert(Timeline.last_tick(scene.timeline) == 0, "dropped outside the bar removes it")
    -- release on a non-slot bar element cancels (keeps the command)
    drag(scene, "chip:left", "slot:1:2")
    drag(scene, "slot:1:2", "chip:up")
    assert(Timeline.get(scene.timeline, 1, 2), "released on a chip: unchanged")
    -- armed chip + plain click on filled slot overwrites it
    click(scene, "chip:stop")
    click(scene, "slot:1:2")
    assert(Timeline.get(scene.timeline, 1, 2).cmd == "stop")
end

-- Disabled while running; right button never starts a drag.
do
    local scene = new_scene()
    drag(scene, "palette:pusher", "cell:3,3")
    drag(scene, "chip:left", "slot:1:2")
    drag(scene, "chip:right", "slot:1:3", 2)
    assert(Timeline.get(scene.timeline, 1, 3) == nil)
    scene:start_run()
    drag(scene, "slot:1:2", { 700, 300 })
    assert(Timeline.get(scene.timeline, 1, 2), "no drag while running")
    drag(scene, "palette:pusher", "cell:6,6")
    assert(scene:ui_tile(6, 6) == nil, "no palette drag while running")
end

-- End to end: pusher on (1,5), one 'right' chip at tick 1; the pusher keeps going to the sink and wins.
do
    local scene = new_scene()
    drag(scene, "palette:pusher", "cell:1,5")
    drag(scene, "chip:right", "slot:1:1")
    click(scene, "cmd:run")
    local n = 0
    while scene.running and n < 3000 do
        scene:update(1)
        n = n + 1
    end
    assert(scene.status == "win", "persistent right wins, got " .. tostring(scene.status))
    assert(scene.sim.tick > Timeline.last_tick(scene.timeline), "ran beyond the last chip")
end

print("test_drag_timeline passed")
