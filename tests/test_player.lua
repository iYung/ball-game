local Player = require("game/player")

-- These mirror the constants in game/player.lua (not exported, so hardcoded
-- here per the values documented there).
local MAX_SPEED  = 260
local FLIP_BOOST = 70
local FLIP_TURN  = 0.35
local DRAG       = 90
local BALL_RADIUS = 10

-- Test 1: alternating flips build speed and turn the heading
do
    local p = Player.new(100, 100, 0) -- facing along +x
    local dt = 0.01
    p:update(dt, true, false, nil)    -- flip left
    -- drag is applied the same frame, right after the flip's boost
    local expected_speed = FLIP_BOOST - DRAG * dt
    assert(math.abs(p.speed - expected_speed) < 0.01,
        "speed after one valid flip should be ~" .. expected_speed .. ", got " .. p.speed)
    assert(math.abs(p.heading - (-FLIP_TURN)) < 0.01,
        "heading after a left flip should turn by -FLIP_TURN, got " .. p.heading)
    print("PASS: player: a flip boosts speed and turns the heading")
end

-- Test 2: repeating the same side without alternating does nothing
do
    local p = Player.new(100, 100, 0)
    p:update(0.01, true, false, nil)         -- valid left flip
    local speed_after_first = p.speed
    local heading_after_first = p.heading
    p:update(0.01, true, false, nil)         -- left again, not alternating: ignored
    assert(math.abs(p.speed - (speed_after_first - DRAG * 0.01)) < 0.5,
        "repeating the same flip side should not add another boost")
    assert(math.abs(p.heading - heading_after_first) < 0.01,
        "repeating the same flip side should not turn the heading again")
    print("PASS: player: repeating the same flip side is a no-op")
end

-- Test 3: alternating left/right keeps boosting speed up to MAX_SPEED
do
    local p = Player.new(100, 100, 0)
    for i = 1, 20 do
        if i % 2 == 1 then
            p:update(0.01, true, false, nil)
        else
            p:update(0.01, false, true, nil)
        end
    end
    assert(p.speed <= MAX_SPEED + 0.01, "speed should clamp at MAX_SPEED, got " .. p.speed)
    assert(p.speed > 0, "speed should be well above zero after repeated alternating flips")
    print("PASS: player: alternating flips clamp speed at MAX_SPEED")
end

-- Test 4: with no flips, drag brings speed to a stop and position doesn't drift after that
do
    local p = Player.new(100, 100, 0)
    p:update(0.01, true, false, nil) -- get some speed going
    for _ = 1, 200 do
        p:update(0.1, false, false, nil) -- long enough for drag to zero it out
    end
    assert(p.speed == 0, "speed should decay to exactly 0 under drag, got " .. p.speed)
    local x_before, y_before = p.x, p.y
    p:update(0.1, false, false, nil)
    assert(math.abs(p.x - x_before) < 0.001 and math.abs(p.y - y_before) < 0.001,
        "position should not move once speed has decayed to 0")
    print("PASS: player: drag decays speed to 0 and motion stops")
end

-- Test 5: collision reflects heading off the wall normal and pushes the ball out
do
    local p = Player.new(50, 50, 0) -- facing directly along +x (toward the wall)
    p.speed = 200
    -- Positioned so the ball approaches the wall's left face from outside
    -- (not already embedded in it), giving an unambiguous horizontal normal.
    local walls = { { x = 75, y = 0, w = 50, h = 100 } }
    p:update(0.1, false, false, walls)

    -- heading should have flipped roughly 180 degrees (reflecting off a
    -- vertical-ish wall face hit head-on along +x)
    local hx, hy = math.cos(p.heading), math.sin(p.heading)
    assert(hx < 0, "heading x-component should reverse after a head-on bounce, got " .. hx)

    local rect = walls[1]
    local inside = p.x >= rect.x and p.x <= rect.x + rect.w and p.y >= rect.y and p.y <= rect.y + rect.h
    assert(not inside, "player should be pushed out of the wall rect after collision")
    print("PASS: player: collision reflects heading and pushes the ball out of the wall")
end

print("ALL TESTS PASSED")
