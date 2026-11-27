-- HUD side panel with one input and with two inputs.
local HUD    = require("lua/game/hud")
local Matrix = require("lua/game/matrix_math")

-- The in-game panel: right of the grid, above the bottom bar.
local PX, PY, PW, PH = 670, 0, 610, 540

local function filled(rows, cols, first)
    local v = {}
    for r = 1, rows do
        v[r] = {}
        for c = 1, cols do v[r][c] = first + (r - 1) * cols + c - 1 end
    end
    return Matrix.new(rows, cols, v)
end

-- Runs hud:draw while recording texts and matrix cell rectangles.
local function record(...)
    local hud = HUD.new(PX, PY, PW, PH)
    local texts, cells = {}, {}
    local orig_printf, orig_rect = love.graphics.printf, love.graphics.rectangle
    love.graphics.printf = function(t, x, y, w)
        texts[#texts + 1] = { text = t, x = x, y = y, w = w }
    end
    love.graphics.rectangle = function(mode, x, y, w, h)
        if mode == "line" then cells[#cells + 1] = { x = x, y = y, w = w, h = h } end
    end
    local ok, ret = pcall(hud.draw, hud, ...)
    love.graphics.printf, love.graphics.rectangle = orig_printf, orig_rect
    assert(ok, tostring(ret))
    return { y = ret, texts = texts, cells = cells }
end

local function find(out, text)
    for _, t in ipairs(out.texts) do
        if t.text == text then return t end
    end
end

local function bounds(cells, from, to)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for i = from, to do
        local c = cells[i]
        x1, y1 = math.min(x1, c.x), math.min(y1, c.y)
        x2, y2 = math.max(x2, c.x + c.w), math.max(y2, c.y + c.h)
    end
    return x1, y1, x2, y2
end

-- Single input: same layout as before.
do
    local out = record(filled(2, 2, 1), filled(1, 1, 9), "One")
    local label = find(out, "INPUT")
    assert(label and label.x == PX and label.y == 30 and label.w == PW, "INPUT label")
    assert(not find(out, "INPUT 1") and not find(out, "INPUT 2"), "no numbered labels")
    local x1, y1, x2, y2 = bounds(out.cells, 1, 4)
    assert(x1 == 885 and y1 == 52 and x2 == 1065 and y2 == 232, "input grid centred in panel")
    assert(find(out, "↓").y == 246, "arrow below input")
    assert(find(out, "TARGET").y == 270, "TARGET below arrow")
    assert(out.y == 292 + 120 + 20 + 10, "returned y")
    print("PASS: HUD single input unchanged")
end

-- Missing matrices are skipped.
do
    local out = record(nil, nil, nil)
    assert(#out.cells == 0, "nothing drawn")
    assert(find(out, "TARGET").y == 76 and out.y == 108, "compact layout")
    print("PASS: HUD without matrices")
end

-- Two inputs: side by side, each centred in its half of the panel.
do
    local out = record(filled(4, 4, 1), filled(4, 4, 40), "Two", filled(4, 4, 20))
    local l1, l2 = find(out, "INPUT 1"), find(out, "INPUT 2")
    assert(l1 and l2 and not find(out, "INPUT"), "numbered labels only")
    assert(l1.y == l2.y and l1.x == PX and l1.w == PW / 2, "left label")
    assert(l2.x == PX + PW / 2 and l2.w == PW / 2, "right label")

    assert(#out.cells == 48, "three 4x4 matrices")
    local ax1, ay1, ax2, ay2 = bounds(out.cells, 1, 16)
    local bx1, by1, bx2, by2 = bounds(out.cells, 17, 32)
    assert(ax1 >= PX and ax2 <= PX + PW / 2, "input 1 inside left half")
    assert(bx1 >= PX + PW / 2 and bx2 <= PX + PW, "input 2 inside right half")
    assert(ay1 == by1 and ay2 == by2, "inputs aligned")
    assert(math.abs((ax1 - PX) - (PX + PW / 2 - ax2)) <= 1, "input 1 centred")
    assert(math.abs((bx1 - PX - PW / 2) - (PX + PW - bx2)) <= 1, "input 2 centred")

    local tx1, ty1, tx2, ty2 = bounds(out.cells, 33, 48)
    assert(tx1 + tx2 == 2 * PX + PW, "target centred in panel")
    assert(find(out, "↓").y >= ay2, "arrow below inputs")
    assert(ty1 > find(out, "TARGET").y, "target below its label")
    assert(ty2 < out.y and out.y < 540, "4x4 pair ends above the bottom bar")

    -- Values come from the right matrices, in draw order.
    assert(find(out, "1").x < PX + PW / 2, "input 1 values on the left")
    assert(find(out, "35").x >= PX + PW / 2, "input 2 values on the right")
    print("PASS: HUD two 4x4 inputs fit side by side")
end

-- The arrow follows the taller input, whichever side it is on.
do
    local short, tall = filled(1, 4, 1), filled(4, 1, 10)
    local target = filled(2, 2, 30)
    local a = record(short, target, "A", tall)
    local b = record(tall, target, "B", short)
    assert(find(a, "↓").y == 52 + 180 + 14, "taller on the right")
    assert(find(b, "↓").y == 52 + 180 + 14, "taller on the left")
    assert(a.y == b.y, "same total height")
    print("PASS: HUD arrow below the taller input")
end
