local Matrix = {}
Matrix.__index = Matrix

local EPSILON = 1e-9

-- -0 compares equal to 0 but prints as "-0"; store it as plain 0.
local function unsigned_zero(v)
    if v == 0 then return 0 end
    return v
end

function Matrix.new(rows, cols, values)
    local self = setmetatable({}, Matrix)
    self.rows = rows
    self.cols = cols
    self.values = {}
    for r = 1, rows do
        self.values[r] = {}
        for c = 1, cols do
            self.values[r][c] = unsigned_zero((values and values[r] and values[r][c]) or 0)
        end
    end
    return self
end

function Matrix:copy()
    local v = {}
    for r = 1, self.rows do
        v[r] = {}
        for c = 1, self.cols do
            v[r][c] = self.values[r][c]
        end
    end
    return Matrix.new(self.rows, self.cols, v)
end

function Matrix:equals(other)
    if self.rows ~= other.rows or self.cols ~= other.cols then return false end
    for r = 1, self.rows do
        for c = 1, self.cols do
            if math.abs(self.values[r][c] - other.values[r][c]) > EPSILON then
                return false
            end
        end
    end
    return true
end

function Matrix:transpose()
    local v = {}
    for c = 1, self.cols do
        v[c] = {}
        for r = 1, self.rows do
            v[c][r] = self.values[r][c]
        end
    end
    return Matrix.new(self.cols, self.rows, v)
end

-- Copy of m with fn applied once to each element in the given row and column range.
local function map_range(m, r1, r2, c1, c2, fn)
    local out = m:copy()
    for r = r1, r2 do
        for c = c1, c2 do
            out.values[r][c] = unsigned_zero(fn(out.values[r][c]))
        end
    end
    return out
end

local function map_all(m, fn)
    return map_range(m, 1, m.rows, 1, m.cols, fn)
end

-- Each edge as r1, r2, c1, c2: first row, last column, last row, first column.
local EDGE_RANGES = {
    top    = function(_, cols)    return 1, 1, 1, cols end,
    right  = function(rows, cols) return 1, rows, cols, cols end,
    bottom = function(rows, cols) return rows, rows, 1, cols end,
    left   = function(rows)       return 1, rows, 1, 1 end,
}

local function map_edge(m, edge, fn)
    local r1, r2, c1, c2 = EDGE_RANGES[edge](m.rows, m.cols)
    return map_range(m, r1, r2, c1, c2, fn)
end

local function times(k) return function(v) return v * k end end
local function plus(k)  return function(v) return v + k end end
local function minus(k) return function(v) return v - k end end

function Matrix:scalar_mul(k)
    return map_all(self, times(k))
end

function Matrix:scalar_add(k)
    return map_all(self, plus(k))
end

function Matrix:scalar_sub(k)
    return map_all(self, minus(k))
end

function Matrix:edge_scale(edge, k)
    return map_edge(self, edge, times(k))
end

function Matrix:edge_add(edge, k)
    return map_edge(self, edge, plus(k))
end

function Matrix:edge_sub(edge, k)
    return map_edge(self, edge, minus(k))
end

-- Element-wise sum; both matrices must have the same shape.
function Matrix:add(other)
    assert(self.rows == other.rows and self.cols == other.cols, "Matrix.add: shapes differ")
    local out = self:copy()
    for r = 1, self.rows do
        for c = 1, self.cols do
            out.values[r][c] = unsigned_zero(self.values[r][c] + other.values[r][c])
        end
    end
    return out
end

-- Matrix product self x other; self.cols must equal other.rows.
function Matrix:mul(other)
    assert(self.cols == other.rows, "Matrix.mul: inner sizes differ")
    local v = {}
    for r = 1, self.rows do
        v[r] = {}
        for c = 1, other.cols do
            local sum = 0
            for i = 1, self.cols do
                sum = sum + self.values[r][i] * other.values[i][c]
            end
            v[r][c] = sum
        end
    end
    return Matrix.new(self.rows, other.cols, v)
end

function Matrix:rotate_90()
    -- 90° clockwise: new[c][rows-r+1] = old[r][c], result is cols×rows
    local v = {}
    for nc = 1, self.cols do
        v[nc] = {}
        for nr = 1, self.rows do
            v[nc][nr] = 0
        end
    end
    for r = 1, self.rows do
        for c = 1, self.cols do
            v[c][self.rows - r + 1] = self.values[r][c]
        end
    end
    return Matrix.new(self.cols, self.rows, v)
end

function Matrix:flip_h()
    local m = self:copy()
    for r = 1, m.rows do
        for c = 1, math.floor(m.cols / 2) do
            local mirror = m.cols - c + 1
            m.values[r][c], m.values[r][mirror] = m.values[r][mirror], m.values[r][c]
        end
    end
    return m
end

function Matrix:flip_v()
    local m = self:copy()
    for r = 1, math.floor(m.rows / 2) do
        local mirror = m.rows - r + 1
        m.values[r], m.values[mirror] = m.values[mirror], m.values[r]
    end
    return m
end

return Matrix
