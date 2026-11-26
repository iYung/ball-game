local HUD = {}
HUD.__index = HUD

function HUD.new(x, y, w, h)
    local self = setmetatable({}, HUD)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.font_num   = love.graphics.newFont(14)
    self.font_label = love.graphics.newFont(16)
    self.font_title = love.graphics.newFont(13)
    return self
end

local function fmt_num(v)
    if v == math.floor(v) then
        return tostring(math.floor(v))
    end
    return string.format("%.2f", v)
end

local function cell_size(mat)
    local n = math.max(mat.rows, mat.cols)
    return math.min(120, math.floor(180 / n))
end

local function grid_height(mat)
    return mat and cell_size(mat) * mat.rows or 0
end

function HUD:draw_matrix(mat, cx, top_y, font_num)
    if not mat then return end
    local cs = cell_size(mat)
    local grid_w = mat.cols * cs
    local grid_h = mat.rows * cs
    local ox = cx - grid_w / 2
    local oy = top_y

    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local px = ox + (c - 1) * cs
            local py = oy + (r - 1) * cs
            love.graphics.setColor(0.1, 0.1, 0.16, 1)
            love.graphics.rectangle("fill", px, py, cs, cs)
            love.graphics.setColor(0.3, 0.3, 0.45, 1)
            love.graphics.rectangle("line", px, py, cs, cs)
            love.graphics.setFont(font_num)
            love.graphics.setColor(0.9, 0.9, 0.95, 1)
            local text = fmt_num(mat.values[r][c])
            love.graphics.printf(text, px, py + cs / 2 - 9, cs, "center")
        end
    end

    return grid_h
end

-- Returns the y just below the divider, where the scene draws the timeline panel.
-- With input2_mat, the two inputs sit side by side above the target.
function HUD:draw(input_mat, target_mat, puzzle_name, input2_mat)
    local x, y, w, h = self.x, self.y, self.w, self.h

    -- Background
    love.graphics.setColor(0.07, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", x, y, w, h)

    local cx = x + w / 2
    local cursor_y = y + 10

    -- Puzzle name
    love.graphics.setFont(self.font_title)
    love.graphics.setColor(0.85, 0.85, 0.95, 1)
    love.graphics.printf(puzzle_name or "", x, cursor_y, w, "center")
    cursor_y = cursor_y + 20

    -- INPUT
    love.graphics.setFont(self.font_label)
    love.graphics.setColor(0.6, 0.75, 1.0, 1)
    if input2_mat then
        local half = math.floor(w / 2)
        local half_cx = x + math.floor(half / 2)
        love.graphics.printf("INPUT 1", x, cursor_y, half, "center")
        love.graphics.printf("INPUT 2", x + half, cursor_y, half, "center")
        cursor_y = cursor_y + 22

        self:draw_matrix(input_mat, half_cx, cursor_y, self.font_num)
        self:draw_matrix(input2_mat, half_cx + half, cursor_y, self.font_num)
        cursor_y = cursor_y + math.max(grid_height(input_mat), grid_height(input2_mat)) + 14
    else
        love.graphics.printf("INPUT", x, cursor_y, w, "center")
        cursor_y = cursor_y + 22

        if input_mat then
            self:draw_matrix(input_mat, cx, cursor_y, self.font_num)
            cursor_y = cursor_y + grid_height(input_mat) + 14
        end
    end

    -- Arrow separator
    love.graphics.setFont(self.font_label)
    love.graphics.setColor(0.5, 0.5, 0.6, 1)
    love.graphics.printf("↓", x, cursor_y, w, "center")
    cursor_y = cursor_y + 24

    -- TARGET
    love.graphics.setFont(self.font_label)
    love.graphics.setColor(0.6, 0.75, 1.0, 1)
    love.graphics.printf("TARGET", x, cursor_y, w, "center")
    cursor_y = cursor_y + 22

    if target_mat then
        self:draw_matrix(target_mat, cx, cursor_y, self.font_num)
        cursor_y = cursor_y + grid_height(target_mat) + 20
    end

    -- Divider
    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    love.graphics.rectangle("fill", x + 20, cursor_y, w - 40, 1)
    cursor_y = cursor_y + 10

    love.graphics.setColor(1, 1, 1, 1)
    return cursor_y
end

return HUD
