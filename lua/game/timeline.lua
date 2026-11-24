-- Pure timeline model: Timeline.LANES command lanes x Timeline.MAX_TICKS ticks.
-- tl[lane][tick] = { pusher = <id>, cmd = <command> }
local Timeline = {}

Timeline.LANES     = 4
Timeline.MAX_TICKS = 60

function Timeline.new()
    local tl = {}
    for lane = 1, Timeline.LANES do tl[lane] = {} end
    return tl
end

local function in_range(lane, tick)
    return type(lane) == "number" and type(tick) == "number"
        and lane >= 1 and lane <= Timeline.LANES
        and tick >= 1 and tick <= Timeline.MAX_TICKS
end

-- Writes a command. Any other command by the same pusher in this tick is removed.
-- Returns false for out-of-range lane/tick.
function Timeline.set(tl, lane, tick, pusher, cmd)
    if not in_range(lane, tick) then return false end
    for l = 1, Timeline.LANES do
        local c = tl[l][tick]
        if c and c.pusher == pusher then tl[l][tick] = nil end
    end
    tl[lane][tick] = { pusher = pusher, cmd = cmd }
    return true
end

function Timeline.clear(tl, lane, tick)
    if not in_range(lane, tick) then return false end
    tl[lane][tick] = nil
    return true
end

function Timeline.get(tl, lane, tick)
    if not in_range(lane, tick) then return nil end
    return tl[lane][tick]
end

-- Ordered (lane order) list of { pusher, cmd } for a tick.
function Timeline.column(tl, tick)
    local out = {}
    for lane = 1, Timeline.LANES do
        local c = tl[lane][tick]
        if c then out[#out + 1] = { pusher = c.pusher, cmd = c.cmd } end
    end
    return out
end

-- Highest tick holding any command, 0 if empty.
function Timeline.last_tick(tl)
    local last = 0
    for lane = 1, Timeline.LANES do
        for tick in pairs(tl[lane]) do
            if tick > last then last = tick end
        end
    end
    return last
end

-- Lowest empty lane in a tick, or nil when the tick is full.
function Timeline.first_free_lane(tl, tick)
    for lane = 1, Timeline.LANES do
        if not tl[lane][tick] then return lane end
    end
    return nil
end

-- Drops every command of a deleted pusher.
function Timeline.remove_pusher(tl, id)
    for lane = 1, Timeline.LANES do
        for tick, c in pairs(tl[lane]) do
            if c.pusher == id then tl[lane][tick] = nil end
        end
    end
end

return Timeline
