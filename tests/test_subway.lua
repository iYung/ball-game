-- test_subway.lua — unit tests for station, train, passenger_flow logic
-- Does NOT call any :draw() methods (love.mouse is not stubbed).

local Station      = require("game/subway/station")
local Train        = require("game/subway/train")
local PassengerFlow = require("game/subway/passenger_flow")

-- ── Station ──────────────────────────────────────────────────────────────────

local s = Station.new({id="s1", name="Test St", lat=40.75, lon=-73.98})

-- add_crowd increments
s:add_crowd(100)
assert(s.crowd == 100, "add_crowd: expected 100, got " .. s.crowd)

-- board_train removes 70% of capacity
s:board_train(100)
-- 100 - 70 = 30
assert(math.abs(s.crowd - 30) < 0.001,
    "board_train: expected 30, got " .. s.crowd)

-- crowd never goes below 0
s:board_train(10000)
assert(s.crowd == 0, "board_train floor: expected 0, got " .. s.crowd)

-- get_color: green at crowd=0
local r0, g0, b0 = s:get_color()
assert(math.abs(r0 - 0.2) < 0.001, "green r at 0")
assert(math.abs(g0 - 0.8) < 0.001, "green g at 0")
assert(math.abs(b0 - 0.3) < 0.001, "green b at 0")

-- get_color: red at crowd>=2000 (r should dominate over g)
s:add_crowd(2000)
local r2, g2, b2 = s:get_color()
assert(r2 > g2, "red dominates at crowd=2000: r=" .. r2 .. " g=" .. g2)
assert(r2 > 0.8, "r is high at crowd=2000: got " .. r2)

-- ── Train ─────────────────────────────────────────────────────────────────────

local stops = {
    {station_id = "A", arrival_seconds = 0},
    {station_id = "B", arrival_seconds = 60},
}
local mock_stations = {
    A = {x = 0,   y = 0},
    B = {x = 100, y = 0},
}

-- Mid-journey: after 30 sim-seconds, progress ~0.5, still active
local train = Train.new("R1", {255, 100, 50}, stops, 0)
train:update(30, mock_stations)
assert(train.active == true,
    "train active mid-journey: got " .. tostring(train.active))
assert(math.abs(train.progress - 0.5) < 0.01,
    "train progress ~0.5: got " .. train.progress)
assert(math.abs(train.x - 50) < 0.01,
    "train x interpolated to 50: got " .. train.x)

-- End of journey: after 60 sim-seconds total, train deactivates
local train2 = Train.new("R1", {255, 100, 50}, stops, 0)
train2:update(60, mock_stations)
assert(train2.active == false,
    "train inactive at end: got " .. tostring(train2.active))

-- ── PassengerFlow ─────────────────────────────────────────────────────────────

-- ridership: station "s1", Monday (1), hour 8 → 600 avg entries/hour
local ridership = { s1 = { ["1"] = { ["8"] = 600 } } }
local flow = PassengerFlow.new(ridership)

local mock_station = {
    id    = "s1",
    crowd = 0,
    add_crowd = function(self, n) self.crowd = self.crowd + n end,
}
local mock_stations2 = { s1 = mock_station }

-- update(60 minutes, hour=8, dow=1) → should add 600/60*60 = 600 passengers
flow:update(60, 8, 1, mock_stations2)
assert(math.abs(mock_station.crowd - 600) < 0.01,
    "passenger flow 60min: expected 600, got " .. mock_station.crowd)

-- Station with no ridership data should be silently skipped
local unknown = {
    id    = "unknown",
    crowd = 0,
    add_crowd = function(self, n) self.crowd = self.crowd + n end,
}
mock_stations2.unknown = unknown
flow:update(1, 8, 1, mock_stations2)
assert(unknown.crowd == 0, "unknown station stays at 0")

print("ALL TESTS PASSED")
