-- The one definition of the op tiles: ids, labels, default params, k ranges and
-- the click-in-thirds editing rules. No LOVE calls.
local Ops = {}

-- Palette and allowlist order; separator after the 6th.
Ops.ORDER  = { "scalar_mul", "edge_scale", "scalar_add", "edge_add", "scalar_sub", "edge_sub",
               "transpose", "rotate_90", "flip_h", "flip_v" }
Ops.EDGES  = { "top", "right", "bottom", "left" }  -- clockwise
Ops.ARROWS = { top="^", right=">", bottom="v", left="<" }

local SCALE = { default = 2, min = -9, max = 9 }
local SHIFT = { default = 1, min = 0,  max = 9 }

local DEFS = {
    scalar_mul = { label = "xk",  prefix = "x", k = SCALE },
    edge_scale = { label = "xk^", prefix = "x", k = SCALE, edge = true },
    scalar_add = { label = "+k",  prefix = "+", k = SHIFT },
    edge_add   = { label = "+k^", prefix = "+", k = SHIFT, edge = true },
    scalar_sub = { label = "-k",  prefix = "-", k = SHIFT },
    edge_sub   = { label = "-k^", prefix = "-", k = SHIFT, edge = true },
    transpose  = { label = "T"   },
    rotate_90  = { label = "R90" },
    flip_h     = { label = "FLh" },
    flip_v     = { label = "FLv" },
}

local function edge_index(edge)
    for i, e in ipairs(Ops.EDGES) do
        if e == edge then return i end
    end
    return nil
end

function Ops.is_op(op)
    return DEFS[op] ~= nil
end

function Ops.label(op)
    return DEFS[op] and DEFS[op].label or "?"
end

function Ops.has_scalar(op)
    return DEFS[op] ~= nil and DEFS[op].k ~= nil
end

function Ops.has_edge(op)
    return DEFS[op] ~= nil and DEFS[op].edge == true
end

-- min, max of the scalar; nil for ops without one.
function Ops.range(op)
    if not Ops.has_scalar(op) then return nil end
    local k = DEFS[op].k
    return k.min, k.max
end

-- Fresh params table: defaults overlaid with the supported keys of overrides.
function Ops.params(op, overrides)
    local params = {}
    if Ops.has_scalar(op) then params.scalar = DEFS[op].k.default end
    if Ops.has_edge(op) then params.edge = "top" end
    for key in pairs(params) do
        if overrides and overrides[key] ~= nil then params[key] = overrides[key] end
    end
    return params
end

-- true, or false plus a message. Missing params and keys take defaults.
function Ops.validate(op, params)
    if not Ops.is_op(op) then
        return false, "Unsupported op: " .. tostring(op)
    end
    if params == nil then return true end
    if type(params) ~= "table" then
        return false, "Invalid params for " .. op
    end
    if Ops.has_edge(op) and params.edge ~= nil and not edge_index(params.edge) then
        return false, "Invalid edge: " .. tostring(params.edge)
    end
    local k = params.scalar
    if Ops.has_scalar(op) and k ~= nil then
        local min, max = Ops.range(op)
        if type(k) ~= "number" or k ~= math.floor(k) or k < min or k > max then
            return false, "Invalid scalar for " .. op .. ": " .. tostring(k)
        end
    end
    return true
end

-- Which horizontal third of a cell rel_x falls in.
function Ops.part(rel_x, cell_size)
    if rel_x < cell_size / 3 then return "left" end
    if rel_x >= cell_size * 2 / 3 then return "right" end
    return "centre"
end

-- Edit a placed tile's params in place. Left/right change k (clamped); centre
-- turns an edge op clockwise.
function Ops.click(op, params, part)
    if part == "centre" then
        if Ops.has_edge(op) then
            local i = edge_index(params.edge or "top") or 1
            params.edge = Ops.EDGES[i % #Ops.EDGES + 1]
        end
    elseif Ops.has_scalar(op) then
        local min, max = Ops.range(op)
        local delta = part == "left" and -1 or 1
        local k = params.scalar or DEFS[op].k.default
        params.scalar = math.max(min, math.min(max, k + delta))
    end
end

-- The text in the middle of a tile. "-0" is intentional: it names scalar_sub 0.
function Ops.tile_text(op, params)
    if not Ops.has_scalar(op) then return Ops.label(op) end
    return DEFS[op].prefix .. tostring(Ops.params(op, params).scalar)
end

-- Palette label of a fixed (preset, uneditable) op button.
function Ops.fixed_label(op, params)
    local full = Ops.params(op, params)
    local arrow = Ops.has_edge(op) and Ops.ARROWS[full.edge] or ""
    return Ops.tile_text(op, full) .. arrow .. "!"
end

return Ops
