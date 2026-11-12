local Train = require("game/subway/train")

local Scheduler = {}
Scheduler.__index = Scheduler

-- network: the Network object (network.lines, network.trips, network.stations)
function Scheduler.new(network)
  local self = setmetatable({}, Scheduler)
  self.network = network
  self.sim_time = 0        -- sim-seconds since midnight (0 = 00:00:00)
  self.sim_speed = 300     -- sim-seconds per real-second; 300x = 1 real sec = 5 sim min
  self.active_trains = {}  -- list of Train objects currently running
  self._spawned_trips = {} -- set of trip_ids already spawned this day; reset at midnight
  self._custom_state = {}  -- per custom line_id: {forward_count, reverse_count}
  self._sim_day = 1        -- 1 = Monday, advances each 86400 sim-seconds
  return self
end

-- Build a stop sequence for a custom line from an ordered list of station_ids.
-- Each stop is 60 sim-seconds apart starting from arrival_seconds = 0.
local function make_custom_stop_sequence(station_ids)
  local seq = {}
  for i, station_id in ipairs(station_ids) do
    seq[i] = { station_id = station_id, arrival_seconds = (i - 1) * 60 }
  end
  return seq
end

-- dt: real-seconds elapsed this frame
-- stations: table keyed by station_id, each entry has x, y, board_train method
function Scheduler:update(dt, stations)
  -- 1. Advance sim_time
  local prev_time = self.sim_time
  self.sim_time = self.sim_time + dt * self.sim_speed
  local did_rollover = false
  if self.sim_time >= 86400 then
    self.sim_time = self.sim_time - 86400
    self._spawned_trips = {}  -- reset trip registry at midnight
    self._sim_day = (self._sim_day % 7) + 1  -- advance day of week (1-7)
    did_rollover = true
  end

  -- 2. Spawn MTA (non-custom) trains
  --    For each active, non-deleted, non-custom line, check if any trip's first stop
  --    arrival_seconds just passed this tick, and spawn a Train if so.
  for line_id, line in pairs(self.network.lines) do
    if line.active and not line.deleted and not line.is_custom then
      local trips = self.network.trips and self.network.trips[line_id]
      if trips then
        for _, trip in ipairs(trips) do
          if not self._spawned_trips[trip.trip_id] then
            local first_stop = trip.stops and trip.stops[1]
            if first_stop then
              local arrival = first_stop.arrival_seconds
              local should_spawn = false
              local offset = 0

              if did_rollover then
                -- The clock wrapped: check arrivals in [prev_time, 86400) from the old day
                -- and arrivals in [0, sim_time) from the new day.
                if arrival >= prev_time then
                  -- Arrived before midnight rollover
                  should_spawn = true
                  offset = (86400 - arrival) + self.sim_time
                elseif arrival < self.sim_time then
                  -- Arrived after midnight in the new day
                  should_spawn = true
                  offset = self.sim_time - arrival
                end
              else
                if arrival >= prev_time and arrival < self.sim_time then
                  should_spawn = true
                  offset = self.sim_time - arrival
                end
              end

              if should_spawn then
                local train = Train.new(line_id, line.color, trip.stops, offset)
                table.insert(self.active_trains, train)
                self._spawned_trips[trip.trip_id] = true
              end
            end
          end
        end
      end
    end
  end

  -- 3. Spawn custom line trains (simpler approach)
  --    Count active trains per custom line. If below num_trains, spawn more,
  --    alternating forward/reverse until balanced.
  for line_id, line in pairs(self.network.lines) do
    if line.active and not line.deleted and line.is_custom then
      local stops = line.stops
      if stops and #stops >= 2 then
        local num_trains = line.num_trains or 4

        -- Count currently active trains for this line by direction
        local active_forward = 0
        local active_reverse = 0
        for _, train in ipairs(self.active_trains) do
          if train.route_id == line_id then
            if train._direction == "forward" then
              active_forward = active_forward + 1
            else
              active_reverse = active_reverse + 1
            end
          end
        end

        -- Target split: round up for forward when odd
        local forward_target = math.ceil(num_trains / 2)
        local reverse_target = math.floor(num_trains / 2)

        -- Spawn forward trains as needed
        while active_forward < forward_target do
          local seq = make_custom_stop_sequence(stops)
          local train = Train.new(line_id, line.color, seq, 0)
          train._direction = "forward"
          table.insert(self.active_trains, train)
          active_forward = active_forward + 1
        end

        -- Spawn reverse trains as needed (stops in reverse order)
        while active_reverse < reverse_target do
          local reversed = {}
          for i = #stops, 1, -1 do
            table.insert(reversed, stops[i])
          end
          local seq = make_custom_stop_sequence(reversed)
          local train = Train.new(line_id, line.color, seq, 0)
          train._direction = "reverse"
          table.insert(self.active_trains, train)
          active_reverse = active_reverse + 1
        end
      end
    end
  end

  -- 4. Update all active trains; remove finished ones; handle boarding
  for i = #self.active_trains, 1, -1 do
    local train = self.active_trains[i]
    local arrived = train:update(dt * self.sim_speed, stations)
    for _, station_id in ipairs(arrived) do
      local s = stations[station_id]
      if s then s:board_train(8000) end
    end
    if not train.active then
      table.remove(self.active_trains, i)
    end
  end
end

-- Set sim speed, clamped to [1, 600] sim-seconds per real-second.
function Scheduler:set_speed(s)
  self.sim_speed = math.max(1, math.min(600, s))
end

-- Returns the current simulated time as {day_of_week=1-7, hour=0-23, minute=0-59}.
-- day_of_week is 1=Monday, 7=Sunday.
function Scheduler:get_sim_time()
  local total_seconds = math.floor(self.sim_time)
  local hour = math.floor(total_seconds / 3600) % 24
  local minute = math.floor((total_seconds % 3600) / 60)
  return {
    day_of_week = self._sim_day,
    hour = hour,
    minute = minute,
  }
end

-- Update num_trains for a custom line and trim or allow growth as needed.
function Scheduler:set_custom_train_count(line_id, n)
  local line = self.network.lines[line_id]
  if not line then return end

  local new_count = math.max(1, math.min(20, n))
  local old_count = line.num_trains or 4
  line.num_trains = new_count

  -- If reducing, mark excess trains inactive (most recently added = highest indices)
  if new_count < old_count then
    local line_trains = {}
    for _, train in ipairs(self.active_trains) do
      if train.route_id == line_id then
        table.insert(line_trains, train)
      end
    end

    local excess = #line_trains - new_count
    if excess > 0 then
      for i = #line_trains, #line_trains - excess + 1, -1 do
        line_trains[i].active = false
      end
    end
  end
  -- If increasing, next update tick will detect the shortfall and spawn more.
end

-- Remove all active trains belonging to line_id (called when a line is deleted).
function Scheduler:remove_line_trains(line_id)
  for i = #self.active_trains, 1, -1 do
    if self.active_trains[i].route_id == line_id then
      table.remove(self.active_trains, i)
    end
  end
  self._custom_state[line_id] = nil
end

return Scheduler
