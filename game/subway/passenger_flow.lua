local PassengerFlow = {}
PassengerFlow.__index = PassengerFlow

-- ridership_data: the decoded ridership.json table (passed in, not loaded here)
function PassengerFlow.new(ridership_data)
  local self = setmetatable({}, PassengerFlow)
  self.ridership_data = ridership_data or {}
  return self
end

-- dt_minutes: sim-minutes elapsed this frame (may be fractional, e.g. 0.016 at 60fps with 1x speed)
-- sim_hour: integer 0-23
-- sim_dow: integer 1-7 (1=Monday)
-- stations: table keyed by station_id -> station object (has :add_crowd(n) method)
function PassengerFlow:update(dt_minutes, sim_hour, sim_dow, stations)
  local dow_key = tostring(sim_dow)
  local hour_key = tostring(sim_hour)

  for station_id, station in pairs(stations) do
    local station_data = self.ridership_data[station.id]
    if station_data then
      local dow_data = station_data[dow_key]
      if dow_data then
        local hourly_avg = dow_data[hour_key]
        if hourly_avg then
          station:add_crowd(hourly_avg / 60 * dt_minutes)
        end
      end
    end
  end
end

return PassengerFlow
