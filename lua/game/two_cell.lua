-- When a two-cell op tile fires. Pure: a body is any table { x, y, matrix },
-- tiles is the Grid:two_cell_tiles() list and disarmed is a set keyed by the
-- left-operand cell, "x,y".
local Ops = require("lua/game/ops")

local TwoCell = {}

local function key(entry)
    return entry.x .. "," .. entry.y
end

function TwoCell.covers(body, cx, cy)
    return cx >= body.x and cx < body.x + body.matrix.cols
       and cy >= body.y and cy < body.y + body.matrix.rows
end

-- Whether the body covers either cell of the tile.
local function touches(body, entry)
    return TwoCell.covers(body, entry.x, entry.y)
        or TwoCell.covers(body, entry.rx, entry.ry)
end

local function covers_both(body, entry)
    return TwoCell.covers(body, entry.x, entry.y)
       and TwoCell.covers(body, entry.rx, entry.ry)
end

-- The body among a and b (b may be nil) covering the cell, or nil.
local function body_at(a, b, cx, cy)
    if TwoCell.covers(a, cx, cy) then return a end
    if b and TwoCell.covers(b, cx, cy) then return b end
    return nil
end

-- What the armed tiles do with the bodies a and b: nil (nothing),
-- { status = "both_inputs" }, { status = "bad_shape", message = ... } or
-- { entry, left, right, matrix } for a merge.
function TwoCell.judge(tiles, a, b, disarmed)
    local armed = {}
    for _, entry in ipairs(tiles) do
        if not (disarmed and disarmed[key(entry)]) then armed[#armed + 1] = entry end
    end

    -- "One matrix on both inputs" is checked on every tile before any merge.
    for _, entry in ipairs(armed) do
        if covers_both(a, entry) or (b and covers_both(b, entry)) then
            return { status = "both_inputs" }
        end
    end

    for _, entry in ipairs(armed) do
        local left  = body_at(a, b, entry.x, entry.y)
        local right = body_at(a, b, entry.rx, entry.ry)
        if left and right then
            local op = entry.tile.op
            local message = Ops.merge_error(op, left.matrix, right.matrix)
            if message then return { status = "bad_shape", message = message } end
            return { entry = entry, left = left, right = right,
                     matrix = Ops.combine(op, left.matrix, right.matrix) }
        end
    end
    return nil
end

-- Disarms every tile with either cell under the body.
function TwoCell.disarm(disarmed, tiles, body)
    for _, entry in ipairs(tiles) do
        if touches(body, entry) then disarmed[key(entry)] = true end
    end
end

-- Re-arms every tile with neither cell under the body, and drops keys that no
-- longer name a tile.
function TwoCell.rearm(disarmed, tiles, body)
    local covered = {}
    for _, entry in ipairs(tiles) do
        if touches(body, entry) then covered[key(entry)] = true end
    end
    for k in pairs(disarmed) do
        if not covered[k] then disarmed[k] = nil end
    end
end

return TwoCell
