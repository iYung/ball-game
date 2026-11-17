local Matrix = {}
Matrix.__index = Matrix

local EPSILON = 1e-9

function Matrix.new(rows, cols, values)
    local self = setmetatable({}, Matrix)
    self.rows = rows
    self.cols = cols
    self.values = {}
    for r = 1, rows do
        self.values[r] = {}
        for c = 1, cols do
            self.values[r][c] = (values and values[r] and values[r][c]) or 0
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

function Matrix:scale_row(r, s)
    local m = self:copy()
    for c = 1, m.cols do
        m.values[r][c] = m.values[r][c] * s
    end
    return m
end

function Matrix:add_rows(src, dst, s)
    local m = self:copy()
    for c = 1, m.cols do
        m.values[dst][c] = m.values[dst][c] + s * m.values[src][c]
    end
    return m
end

function Matrix:swap_rows(a, b)
    local m = self:copy()
    m.values[a], m.values[b] = m.values[b], m.values[a]
    return m
end

function Matrix:negate()
    return self:scalar_mul(-1)
end

function Matrix:scalar_mul(s)
    local m = self:copy()
    for r = 1, m.rows do
        for c = 1, m.cols do
            m.values[r][c] = m.values[r][c] * s
        end
    end
    return m
end

return Matrix
