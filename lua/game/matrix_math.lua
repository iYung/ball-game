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

function Matrix:add_matrix(other)
    local m = self:copy()
    for r = 1, math.min(self.rows, other.rows) do
        for c = 1, math.min(self.cols, other.cols) do
            m.values[r][c] = m.values[r][c] + other.values[r][c]
        end
    end
    return m
end

function Matrix:sub_matrix(other)
    local m = self:copy()
    for r = 1, math.min(self.rows, other.rows) do
        for c = 1, math.min(self.cols, other.cols) do
            m.values[r][c] = m.values[r][c] - other.values[r][c]
        end
    end
    return m
end

function Matrix:mul_matrix(other)
    local m = self:copy()
    for r = 1, math.min(self.rows, other.rows) do
        for c = 1, math.min(self.cols, other.cols) do
            m.values[r][c] = m.values[r][c] * other.values[r][c]
        end
    end
    return m
end

function Matrix:set_row(r, values)
    if r < 1 or r > self.rows then return self:copy() end
    local m = self:copy()
    for c = 1, math.min(self.cols, #values) do
        m.values[r][c] = values[c]
    end
    return m
end

function Matrix:scale_col(c, s)
    c = math.max(1, math.min(self.cols, c))
    local m = self:copy()
    for r = 1, m.rows do
        m.values[r][c] = m.values[r][c] * s
    end
    return m
end

function Matrix:swap_cols(a, b)
    local m = self:copy()
    if a == b then return m end
    for r = 1, m.rows do
        m.values[r][a], m.values[r][b] = m.values[r][b], m.values[r][a]
    end
    return m
end

function Matrix:add_cols(src, dst, s)
    if src == dst then return self end
    local m = self:copy()
    for r = 1, m.rows do
        m.values[r][dst] = m.values[r][dst] + s * m.values[r][src]
    end
    return m
end

function Matrix:set_col(c, values)
    c = math.max(1, math.min(self.cols, c))
    local m = self:copy()
    for r = 1, math.min(self.rows, #values) do
        m.values[r][c] = values[r]
    end
    return m
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

function Matrix:abs()
    local m = self:copy()
    for r = 1, m.rows do
        for c = 1, m.cols do
            m.values[r][c] = math.abs(m.values[r][c])
        end
    end
    return m
end

return Matrix
