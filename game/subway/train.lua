local Train = {}
Train.__index = Train

-- route_id: string identifying the line
-- color: {r, g, b} with values 0-255
-- stop_sequence: array of {station_id=string, arrival_seconds=number}
-- offset_seconds: how far into the schedule this train starts (for distributing trains evenly)
function Train.new(route_id, color, stop_sequence, offset_seconds)
  local self = setmetatable({}, Train)
  self.route_id = route_id
  self.color = {
    (color.r or color[1]) / 255,
    (color.g or color[2]) / 255,
    (color.b or color[3]) / 255,
  }
  self.stop_sequence = stop_sequence
  self.leg = 1
  self.progress = 0.0
  self.x = 0
  self.y = 0
  self.active = true
  self.elapsed = offset_seconds or 0
  return self
end

-- dt_sim: sim-seconds elapsed this frame
-- stations: table keyed by station_id -> {x, y} (screen coords)
-- returns list of station_ids that were JUST ARRIVED AT this update (for boarding logic)
function Train:update(dt_sim, stations)
  local arrived_stations = {}

  if not self.active then
    return arrived_stations
  end

  local prev_elapsed = self.elapsed
  self.elapsed = self.elapsed + dt_sim

  local seq = self.stop_sequence
  local n = #seq

  -- Need at least 2 stops to move
  if n < 2 then
    self.active = false
    return arrived_stations
  end

  -- Advance leg as needed, recording arrivals
  while self.leg < n - 1 do
    local next_arrival = seq[self.leg + 1].arrival_seconds
    if self.elapsed >= next_arrival then
      self.leg = self.leg + 1
      -- Record arrival only if we just crossed this threshold
      if prev_elapsed < next_arrival then
        table.insert(arrived_stations, seq[self.leg].station_id)
      end
    else
      break
    end
  end

  -- Check if we've passed the last stop
  local last_arrival = seq[n].arrival_seconds
  if self.elapsed >= last_arrival then
    -- Record arrival at last stop if we just crossed it
    if prev_elapsed < last_arrival then
      table.insert(arrived_stations, seq[n].station_id)
    end
    self.active = false
    -- Position at last stop
    local last_id = seq[n].station_id
    local last_station = stations[last_id]
    if last_station then
      self.x = last_station.x
      self.y = last_station.y
    end
    return arrived_stations
  end

  -- Interpolate position within current leg
  local from_stop = seq[self.leg]
  local to_stop = seq[self.leg + 1]
  local leg_start = from_stop.arrival_seconds
  local leg_end = to_stop.arrival_seconds
  local leg_duration = leg_end - leg_start

  if leg_duration > 0 then
    self.progress = (self.elapsed - leg_start) / leg_duration
  else
    self.progress = 1.0
  end
  self.progress = math.max(0.0, math.min(1.0, self.progress))

  local from_station = stations[from_stop.station_id]
  local to_station = stations[to_stop.station_id]

  if from_station and to_station then
    self.x = from_station.x + (to_station.x - from_station.x) * self.progress
    self.y = from_station.y + (to_station.y - from_station.y) * self.progress
  elseif from_station then
    self.x = from_station.x
    self.y = from_station.y
  elseif to_station then
    self.x = to_station.x
    self.y = to_station.y
  end

  return arrived_stations
end

function Train:draw()
  -- Filled circle in line color
  love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1)
  love.graphics.circle("fill", self.x, self.y, 5)
  -- Bright white highlight dot to make trains readable on colored lines
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.circle("fill", self.x - 1, self.y - 1, 2)
end

return Train
