local Player = require("game/player")

-- Constants documented in game/player.lua (not exported, so hardcoded here).
local BALL_RADIUS   = 10
local MIN_RADIUS    = 50
local MAX_RADIUS    = 300
local RADIUS_RATE   = 140
local ANGULAR_SPEED = 2.4

-- Test 1: re-pivot keeps the ball's motion consistent with orbital arc
-- length at the NEW radius, not a jump equal to the radius growth.
do
    local x, y = 100, 100
    local p = Player.new(x, y, x, y - MIN_RADIUS, 1)
    assert(math.abs(p.radius - MIN_RADIUS) < 0.01, "initial radius should be MIN_RADIUS")

    local dt = 0.01
    local old_x, old_y = p.x, p.y
    p:update(dt, true, nil)

    assert(p.radius > MIN_RADIUS, "radius should have grown, got " .. tostring(p.radius))

    local moved = math.sqrt((p.x - old_x)^2 + (p.y - old_y)^2)
    local expected_arc = p.radius * ANGULAR_SPEED * dt
    local radius_jump = RADIUS_RATE * dt

    assert(math.abs(moved - expected_arc) < expected_arc * 0.2,
        "ball displacement (" .. moved .. ") should match arc length (" .. expected_arc .. ")")
    -- Make sure it's noticeably smaller than a "teleport by the radius
    -- delta" bug would produce (arc length is always < radius growth here
    -- since ANGULAR_SPEED * MIN_RADIUS < RADIUS_RATE).
    assert(moved < radius_jump * 0.95,
        "ball displacement (" .. moved .. ") should be clearly less than the raw radius growth (" .. radius_jump .. ")")

    print("PASS: player: re-pivot keeps ball fixed, motion matches new-radius arc length")
end

-- Test 2: angle progresses clockwise (direction = 1) at ANGULAR_SPEED,
-- and radius stays pinned at MIN_RADIUS when already at the floor.
do
    local p = Player.new(MIN_RADIUS, 0, 0, 0, 1)
    assert(math.abs(p.radius - MIN_RADIUS) < 0.01, "initial radius should be MIN_RADIUS")
    assert(math.abs(p.angle - 0) < 0.01, "initial angle should be 0")

    local dt = 0.01
    p:update(dt, false, nil)

    assert(math.abs(p.radius - MIN_RADIUS) < 0.01,
        "radius should remain pinned at MIN_RADIUS, got " .. tostring(p.radius))

    local expected_angle = ANGULAR_SPEED * dt
    local expected_x = MIN_RADIUS * math.cos(expected_angle)
    local expected_y = MIN_RADIUS * math.sin(expected_angle)

    assert(math.abs(p.x - expected_x) < 0.01, "x should match expected orbital position")
    assert(math.abs(p.y - expected_y) < 0.01, "y should match expected orbital position")

    print("PASS: player: angle progresses clockwise at ANGULAR_SPEED")
end

-- Test 3: radius clamps at MIN_RADIUS and MAX_RADIUS.
do
    local p = Player.new(150, 100, 100, 100, 1)

    for _ = 1, 100 do
        p:update(0.1, true, nil)
    end
    assert(p.radius <= MAX_RADIUS + 0.01,
        "radius should clamp at MAX_RADIUS, got " .. tostring(p.radius))
    assert(p.radius > MAX_RADIUS - 1,
        "radius should have grown to near MAX_RADIUS, got " .. tostring(p.radius))

    for _ = 1, 100 do
        p:update(0.1, false, nil)
    end
    assert(p.radius >= MIN_RADIUS - 0.01,
        "radius should clamp at MIN_RADIUS, got " .. tostring(p.radius))
    assert(p.radius < MIN_RADIUS + 1,
        "radius should have shrunk to near MIN_RADIUS, got " .. tostring(p.radius))

    print("PASS: player: radius clamps at MIN_RADIUS and MAX_RADIUS")
end

-- Test 4: collision with a wall flips direction and pushes the ball out.
do
    local p = Player.new(MIN_RADIUS, 0, 0, 0, 1)
    local walls = { { x = 40, y = 5, w = 20, h = 20 } }

    p:update(0.1, false, walls)

    assert(p.direction == -1, "direction should flip to -1 on collision, got " .. tostring(p.direction))

    local rect = walls[1]
    local inside = p.x > rect.x and p.x < rect.x + rect.w and p.y > rect.y and p.y < rect.y + rect.h
    assert(not inside, "ball should be pushed out of the wall rect, got x=" .. p.x .. " y=" .. p.y)

    print("PASS: player: collision flips direction and pushes ball out of wall")
end

print("ALL TESTS PASSED")
