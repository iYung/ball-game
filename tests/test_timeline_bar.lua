-- Unit tests for the bottom bar of MatrixScene: pusher selector, instruction chips, timeline slots.

local S = require("tests/support/shipped")
local runner   = require("lua/headless/runner")
local UI       = require("lua/core/ui")
local UIRunner = require("lua/headless/ui_runner")
local Timeline = require("lua/game/timeline")

local function new_scene()
    local ctx = runner.setup(function(_, sm)
        return require("lua/game/scenes/matrix_scene").new(S.puzzle("identity"), sm)
    end)
    local scene = ctx.sm.current
    scene:draw()
    return scene
end

local function find(scene, id)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "element " .. id .. " present")
    return e
end

local function click(scene, id, btn)
    local x, y = UI.centre(find(scene, id).rect)
    scene:mouse_pressed(x, y, btn or 1)
    scene:mouse_released(x, y, btn or 1)
end

local function place_pusher(scene, cx, cy)
    scene:_place_tile_at(cx, cy, { kind = "pusher" })
end

-- Layout: invariants hold, bar elements sit inside the bar and clear of the run buttons.
do
    local scene = new_scene()
    place_pusher(scene, 3, 3)
    local els = scene:ui_elements()
    assert(UIRunner.check_invariants(els) == nil, tostring(UIRunner.check_invariants(els)))
    local run = UI.find(els, "cmd:run").rect
    for _, e in ipairs(els) do
        if e.id:match("^slot:") or e.id:match("^chip:") or e.id:match("^psel:") or e.id:match("^tl:") then
            assert(e.rect.y >= 540 and e.rect.y + e.rect.h <= 720, e.id .. " inside bar")
            assert(e.rect.x + e.rect.w <= run.x, e.id .. " left of run buttons")
        end
    end
    for _, id in ipairs({ "chip:up", "chip:down", "chip:left", "chip:right", "chip:stop",
                          "psel:A", "tl:scroll_left", "tl:scroll_right", "slot:1:1", "slot:4:1" }) do
        find(scene, id)
    end
end

-- Selector auto-selects the first pusher; chip arms; click writes a slot; right-click clears.
do
    local scene = new_scene()
    place_pusher(scene, 3, 3)
    scene:ui_elements()
    assert(scene.sel_pusher == 1, "first pusher auto-selected")
    assert(find(scene, "psel:A").selected)
    click(scene, "slot:1:2")
    assert(Timeline.get(scene.timeline, 1, 2) == nil, "no write without an armed chip")
    click(scene, "chip:right")
    assert(find(scene, "chip:right").selected and scene.armed_chip == "right")
    click(scene, "slot:2:3")
    local c = Timeline.get(scene.timeline, 2, 3)
    assert(c and c.pusher == 1 and c.cmd == "right", "slot written")
    click(scene, "chip:stop")
    click(scene, "slot:3:3")   -- same pusher, same tick: replaces the lane-2 command
    assert(Timeline.get(scene.timeline, 2, 3) == nil)
    assert(Timeline.get(scene.timeline, 3, 3).cmd == "stop")
    click(scene, "slot:3:3", 2)
    assert(Timeline.get(scene.timeline, 3, 3) == nil, "right-click clears")
end

-- Selector clamps when its pusher is erased; the erased pusher's commands go away.
do
    local scene = new_scene()
    place_pusher(scene, 3, 3)
    place_pusher(scene, 4, 4)
    click(scene, "psel:B")
    assert(scene.sel_pusher == 2)
    click(scene, "chip:up")
    click(scene, "slot:1:1")
    assert(Timeline.get(scene.timeline, 1, 1).pusher == 2)
    scene.grid:clear(4, 4)
    scene:ui_elements()
    assert(scene.sel_pusher == 1, "selector clamped to remaining pusher")
    assert(Timeline.get(scene.timeline, 1, 1) == nil, "erased pusher's commands removed")
    assert(UI.find(scene:ui_elements(), "psel:B") == nil)
    scene.grid:clear(3, 3)
    scene:ui_elements()
    assert(scene.sel_pusher == nil, "no pushers, no selection")
end

-- Scrolling reveals later ticks; bar is disabled while running.
do
    local scene = new_scene()
    place_pusher(scene, 3, 3)
    assert(find(scene, "tl:scroll_left").enabled == false)
    for _ = 1, 20 do
        if find(scene, "tl:scroll_right").enabled then click(scene, "tl:scroll_right") end
    end
    assert(UI.find(scene:ui_elements(), "slot:1:60"), "tick 60 reachable")
    assert(UI.find(scene:ui_elements(), "slot:1:1") == nil)
    click(scene, "tl:scroll_left")
    assert(find(scene, "tl:scroll_right").enabled)
    scene:start_run()
    assert(find(scene, "slot:1:" .. (scene.timeline_scroll + 1)).enabled == false)
    assert(find(scene, "chip:up").enabled == false)
    assert(find(scene, "psel:A").enabled == false)
end

-- CLR chip: arming it and clicking a slot clears the slot; clicking empty is a no-op.
do
    local scene = new_scene()
    place_pusher(scene, 3, 3)
    scene:ui_elements()
    click(scene, "chip:right")
    click(scene, "slot:1:5")
    assert(Timeline.get(scene.timeline, 1, 5), "slot written before clear test")

    click(scene, "chip:clear")
    assert(find(scene, "chip:clear").selected and scene.armed_chip == "clear")
    click(scene, "slot:1:5")
    assert(Timeline.get(scene.timeline, 1, 5) == nil, "CLR chip clears filled slot")

    -- Clicking an empty slot with CLR armed is a no-op (no error).
    click(scene, "slot:1:5")
    assert(Timeline.get(scene.timeline, 1, 5) == nil, "CLR on empty slot is a no-op")
end

print("test_timeline_bar passed")
