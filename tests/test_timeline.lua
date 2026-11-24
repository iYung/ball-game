local Timeline = require("lua/game/timeline")

-- constants and new()
do
    assert(Timeline.LANES == 4 and Timeline.MAX_TICKS == 60, "constants")
    local tl = Timeline.new()
    assert(#tl == 4, "four lanes")
    assert(Timeline.last_tick(tl) == 0, "empty last_tick is 0")
    assert(#Timeline.column(tl, 1) == 0, "empty column")
    print("PASS: new")
end

-- set / get / clear
do
    local tl = Timeline.new()
    assert(Timeline.set(tl, 2, 5, 1, "up") == true, "set ok")
    local c = Timeline.get(tl, 2, 5)
    assert(c.pusher == 1 and c.cmd == "up", "get returns command")
    assert(Timeline.get(tl, 1, 5) == nil, "other lane empty")
    Timeline.clear(tl, 2, 5)
    assert(Timeline.get(tl, 2, 5) == nil, "cleared")
    print("PASS: set/get/clear")
end

-- replace on same lane/tick, and same pusher in another lane
do
    local tl = Timeline.new()
    Timeline.set(tl, 1, 3, 1, "up")
    Timeline.set(tl, 1, 3, 2, "down")
    assert(Timeline.get(tl, 1, 3).pusher == 2, "occupied cell replaced")
    Timeline.set(tl, 1, 4, 1, "left")
    Timeline.set(tl, 3, 4, 1, "right")
    assert(Timeline.get(tl, 1, 4) == nil, "same pusher in other lane removed")
    assert(Timeline.get(tl, 3, 4).cmd == "right", "new command kept")
    Timeline.set(tl, 3, 4, 1, "stop")
    assert(#Timeline.column(tl, 4) == 1 and Timeline.get(tl, 3, 4).cmd == "stop", "re-set same cell")
    -- different pushers coexist; different ticks unaffected
    Timeline.set(tl, 1, 5, 1, "up")
    Timeline.set(tl, 2, 5, 2, "up")
    Timeline.set(tl, 1, 6, 1, "up")
    assert(#Timeline.column(tl, 5) == 2 and Timeline.get(tl, 1, 6) ~= nil, "no cross-talk")
    print("PASS: replace")
end

-- bounds
do
    local tl = Timeline.new()
    assert(Timeline.set(tl, 0, 1, 1, "up") == false, "lane 0")
    assert(Timeline.set(tl, 5, 1, 1, "up") == false, "lane 5")
    assert(Timeline.set(tl, 1, 0, 1, "up") == false, "tick 0")
    assert(Timeline.set(tl, 1, 61, 1, "up") == false, "tick 61")
    assert(Timeline.set(tl, 1, 60, 1, "up") == true, "tick 60 ok")
    assert(Timeline.set(tl, 4, 1, 1, "up") == true, "lane 4 ok")
    assert(Timeline.get(tl, 9, 9) == nil, "get out of range")
    assert(Timeline.clear(tl, 9, 9) == false, "clear out of range")
    assert(Timeline.clear(tl, 1, 60) == true, "clear in range")
    print("PASS: bounds")
end

-- column order, last_tick, first_free_lane
do
    local tl = Timeline.new()
    Timeline.set(tl, 3, 2, 1, "up")
    Timeline.set(tl, 1, 2, 2, "down")
    local col = Timeline.column(tl, 2)
    assert(#col == 2 and col[1].pusher == 2 and col[1].cmd == "down" and col[2].pusher == 1, "lane order")
    assert(Timeline.last_tick(tl) == 2, "last_tick")
    Timeline.set(tl, 2, 9, 1, "stop")
    assert(Timeline.last_tick(tl) == 9, "last_tick later")
    assert(Timeline.first_free_lane(tl, 2) == 2, "first free lane skips used")
    assert(Timeline.first_free_lane(tl, 7) == 1, "empty tick -> lane 1")
    for p = 1, 4 do Timeline.set(tl, p, 8, p, "up") end
    assert(Timeline.first_free_lane(tl, 8) == nil, "full tick -> nil")
    print("PASS: column/last_tick/first_free_lane")
end

-- remove_pusher
do
    local tl = Timeline.new()
    Timeline.set(tl, 1, 1, 1, "up")
    Timeline.set(tl, 2, 3, 1, "down")
    Timeline.set(tl, 1, 2, 2, "left")
    Timeline.remove_pusher(tl, 1)
    assert(#Timeline.column(tl, 1) == 0 and #Timeline.column(tl, 3) == 0, "pusher 1 gone")
    assert(Timeline.get(tl, 1, 2).pusher == 2, "pusher 2 kept")
    assert(Timeline.last_tick(tl) == 2, "last_tick after removal")
    print("PASS: remove_pusher")
end
