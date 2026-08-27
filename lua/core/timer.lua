local Timer = {}
Timer.__index = Timer

function Timer.new(interval)
    return setmetatable({ interval = interval, _t = 0 }, Timer)
end

function Timer:update(dt)
    self._t = self._t + dt
    if self._t >= self.interval then
        self._t = self._t - self.interval
        return true
    end
    return false
end

function Timer:reset(interval)
    self._t = 0
    if interval then self.interval = interval end
end

return Timer
