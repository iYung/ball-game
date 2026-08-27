-- Shared level geometry helpers: wall-rect generation, mirrored-entry
-- calculation, and spawn transforms. Plain functions, not a class/instance.

local Level = {}

local ROOM_W = 1280
local ROOM_H = 720
local WALL_THICKNESS = 40

-- Reuse the ball's tuning constants without requiring game/player.lua
-- (avoids a hard dependency/ordering problem between parallel modules).
local BALL_RADIUS = 10
local MIN_RADIUS = 50

local OPPOSITE_SIDE = {
    top    = "bottom",
    bottom = "top",
    left   = "right",
    right  = "left",
}

-- inward normal (unit vector pointing from the wall into the room) per side
local INWARD_NORMAL = {
    top    = { x = 0, y = 1 },
    bottom = { x = 0, y = -1 },
    left   = { x = 1, y = 0 },
    right  = { x = -1, y = 0 },
}

-- Build the full-length boundary rect for a given side.
local function boundary_rect(side)
    if side == "top" then
        return { x = 0, y = 0, w = ROOM_W, h = WALL_THICKNESS }
    elseif side == "bottom" then
        return { x = 0, y = ROOM_H - WALL_THICKNESS, w = ROOM_W, h = WALL_THICKNESS }
    elseif side == "left" then
        return { x = 0, y = 0, w = WALL_THICKNESS, h = ROOM_H }
    elseif side == "right" then
        return { x = ROOM_W - WALL_THICKNESS, y = 0, w = WALL_THICKNESS, h = ROOM_H }
    end
end

-- Split a boundary side's rect into two rects flanking the exit gap.
local function split_rect(side, pos, gap)
    local half = gap / 2
    local gap_start = pos - half
    local gap_end = pos + half

    if side == "top" or side == "bottom" then
        local y = (side == "top") and 0 or (ROOM_H - WALL_THICKNESS)
        local rects = {}

        local left_w = math.max(0, gap_start - 0)
        if left_w > 0 then
            table.insert(rects, { x = 0, y = y, w = left_w, h = WALL_THICKNESS })
        end

        local right_x = gap_end
        local right_w = math.max(0, ROOM_W - gap_end)
        if right_w > 0 then
            table.insert(rects, { x = right_x, y = y, w = right_w, h = WALL_THICKNESS })
        end

        return rects
    else -- left or right
        local x = (side == "left") and 0 or (ROOM_W - WALL_THICKNESS)
        local rects = {}

        local top_h = math.max(0, gap_start - 0)
        if top_h > 0 then
            table.insert(rects, { x = x, y = 0, w = WALL_THICKNESS, h = top_h })
        end

        local bottom_y = gap_end
        local bottom_h = math.max(0, ROOM_H - gap_end)
        if bottom_h > 0 then
            table.insert(rects, { x = x, y = bottom_y, w = WALL_THICKNESS, h = bottom_h })
        end

        return rects
    end
end

-- Level.walls(level_def) -> array of {x, y, w, h} rects to collide against.
function Level.walls(level_def)
    local walls = {}
    local exit = level_def.exit

    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        if side == exit.side then
            local rects = split_rect(side, exit.pos, exit.gap)
            for _, r in ipairs(rects) do
                table.insert(walls, r)
            end
        else
            table.insert(walls, boundary_rect(side))
        end
    end

    for _, obstacle in ipairs(level_def.obstacles or {}) do
        table.insert(walls, obstacle)
    end

    return walls
end

-- Level.mirrored_entry(level_def) -> { side, pos } opposite the exit.
function Level.mirrored_entry(level_def)
    local exit = level_def.exit
    return {
        side = OPPOSITE_SIDE[exit.side],
        pos = exit.pos,
    }
end

-- Level.spawn(entry) -> { x, y, center_x, center_y, direction = 1 }
function Level.spawn(entry)
    local normal = INWARD_NORMAL[entry.side]
    local ball_offset = BALL_RADIUS + 4

    local x, y
    if entry.side == "top" or entry.side == "bottom" then
        x = entry.pos
        y = (entry.side == "top") and ball_offset or (ROOM_H - ball_offset)
    else
        y = entry.pos
        x = (entry.side == "left") and ball_offset or (ROOM_W - ball_offset)
    end

    local center_x = x + normal.x * MIN_RADIUS
    local center_y = y + normal.y * MIN_RADIUS

    return {
        x = x,
        y = y,
        center_x = center_x,
        center_y = center_y,
        direction = 1,
    }
end

-- Fixed safe starting spawn used when there is no previous level's exit to
-- mirror from (level 1's boot, and looping back after the last level). Not
-- placed against a wall side via Level.spawn(), since a level's non-exit
-- sides are solid (no gap) and would embed the ball in a wall.
function Level.default_spawn()
    local x = ROOM_W / 2
    local y = ROOM_H - WALL_THICKNESS - 60

    return {
        x = x,
        y = y,
        center_x = x,
        center_y = y - MIN_RADIUS,
        direction = 1,
    }
end

return Level
