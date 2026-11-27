-- The solution recap of a two-source run: both matrices slide in their own border
-- colours, a merge tick ends on the result alone, and two-cell tiles and numbered
-- sources are drawn.

local runner             = require("lua/headless/runner")
local Stubs              = require("lua/headless/stubs")
local Grid               = require("lua/game/grid")
local Matrix             = require("lua/game/matrix_math")
local Ops                = require("lua/game/ops")
local SolutionRecapScene = require("lua/game/scenes/solution_recap_scene")
local GEOM               = require("lua/game/scenes/matrix_scene").GEOM

local CS = GEOM.CELL_SIZE
local cell = SolutionRecapScene.cell_top_left

-- Texts (with position) and line rectangles (with colour) of one draw.
local function capture(recap)
    local g = love.graphics
    local set, rect, printf = g.setColor, g.rectangle, g.printf
    local color, texts, lines = nil, {}, {}
    g.setColor  = function(r, gr, b) color = { r, gr, b } end
    g.rectangle = function(mode, x, y, w, h)
        if mode == "line" then lines[#lines + 1] = { x = x, y = y, w = w, h = h, color = color } end
    end
    g.printf    = function(s, x, y, w) texts[#texts + 1] = { s = s, x = x, y = y, w = w } end
    local ok, err = pcall(recap.draw, recap)
    g.setColor, g.rectangle, g.printf = set, rect, printf
    assert(ok, tostring(err))
    return texts, lines
end

local function texts_of(texts, s)
    local out = {}
    for _, t in ipairs(texts) do
        if t.s == s then out[#out + 1] = t end
    end
    return out
end

-- Asserts that value s is drawn once, in a matrix cell with top-left (px, py)
-- bordered in the colour of tag.
local function expect_body(texts, lines, s, px, py, tag)
    local found = texts_of(texts, s)
    assert(#found == 1, "value " .. s .. " drawn once, got " .. #found)
    assert(math.abs(found[1].x - px) < 1e-6 and math.abs(found[1].y - (py + CS / 2 - 9)) < 1e-6,
        string.format("value %s at %s,%s, expected cell %s,%s", s, found[1].x, found[1].y, px, py))
    local want = GEOM.MATRIX_BORDER[tag]
    for _, l in ipairs(lines) do
        if l.w == CS - 2 and math.abs(l.x - (px + 1)) < 1e-6 and math.abs(l.y - (py + 1)) < 1e-6
            and l.color[1] == want[1] and l.color[2] == want[2] and l.color[3] == want[3] then
            return
        end
    end
    error("value " .. s .. " has no border of tag " .. tag)
end

local function absent(texts, s)
    assert(#texts_of(texts, s) == 0, "value " .. s .. " should not be drawn")
end

local function one(v) return Matrix.new(1, 1, { { v } }) end

local function new_recap(frames, grid, run_speed)
    local stats = { ticks = #frames, pieces = 2, puzzle_name = "Pair", puzzle_index = 1 }
    local ctx = runner.setup(function(_, sm)
        return SolutionRecapScene.new(stats, { grid = grid or Grid.new(10, 10) }, frames,
                                      run_speed or 1, sm)
    end)
    return ctx.sm.current
end

local ax, ay = cell(2, 3)
local bx, by = cell(6, 3)
local cx, cy = cell(3, 3)
local dx, dy = cell(5, 3)
local ex, ey = cell(8, 3)

-- Tick 1 moves both, tick 2 merges them (source 2's matrix is the left operand),
-- tick 3 carries the result away.
local function three_frames()
    return {
        { from_x = ax, from_y = ay, to_x = cx, to_y = cy, matrix = one(11), tag = 1,
          second = { from_x = bx, from_y = by, to_x = dx, to_y = dy, matrix = one(22), tag = 2 } },
        { from_x = cx, from_y = cy, to_x = cx, to_y = cy, matrix = one(11), tag = 1,
          second = { from_x = dx, from_y = dy, to_x = bx, to_y = by, matrix = one(22), tag = 2 },
          merged = { x = bx, y = by, matrix = one(33), tag = 2 } },
        { from_x = bx, from_y = by, to_x = ex, to_y = ey, matrix = one(33), tag = 2 },
    }
end

-- Mid-slide: both matrices, each part way along its own path.
do
    local recap = new_recap(three_frames())
    recap:update(0.5)  -- smooth-step of 0.5 is 0.5
    local texts, lines = capture(recap)
    expect_body(texts, lines, "11", (ax + cx) / 2, ay, 1)
    expect_body(texts, lines, "22", (bx + dx) / 2, by, 2)
    absent(texts, "33")

    -- The merge tick slides both pre-op matrices in.
    recap:update(0.5)
    recap:update(0.5)
    assert(recap._frame_idx == 2, "on the merge tick")
    texts, lines = capture(recap)
    expect_body(texts, lines, "11", cx, cy, 1)
    expect_body(texts, lines, "22", (dx + bx) / 2, by, 2)
    absent(texts, "33")
    print("PASS: recap draws both matrices mid-slide")
end

-- Merge arrival: only the result, where the merge put it, in the left operand's colour.
do
    local recap = new_recap(three_frames())
    recap._frame_idx, recap._anim_t = 2, 1
    local texts, lines = capture(recap)
    expect_body(texts, lines, "33", bx, by, 2)
    absent(texts, "11")
    absent(texts, "22")

    -- The tick after the merge has the result alone and keeps that colour.
    recap._frame_idx, recap._anim_t = 3, 0.5
    texts, lines = capture(recap)
    expect_body(texts, lines, "33", (bx + ex) / 2, by, 2)
    absent(texts, "11")
    absent(texts, "22")
    print("PASS: recap shows only the result after a merge")
end

-- Merge on the final tick: the end hold shows the result; the loop and Replay
-- bring both inputs back.
do
    local frames = three_frames()
    frames[3] = nil
    local recap = new_recap(frames, nil, 0.1)
    recap:update(0.15)
    recap:update(0.15)
    assert(recap._holding and recap._frame_idx == 2, "holding on the merge tick")
    for _ = 1, 3 do
        local texts, lines = capture(recap)
        expect_body(texts, lines, "33", bx, by, 2)
        absent(texts, "11")
        absent(texts, "22")
        recap:update(0.15)
    end
    assert(recap._holding, "still holding")

    recap:update(1.0)
    assert(not recap._holding and recap._frame_idx == 1, "looped")
    local texts, lines = capture(recap)
    expect_body(texts, lines, "11", ax, ay, 1)
    expect_body(texts, lines, "22", bx, by, 2)
    absent(texts, "33")

    recap:update(0.15)
    recap:update(0.15)
    recap:key_pressed("r")
    texts, lines = capture(recap)
    expect_body(texts, lines, "11", ax, ay, 1)
    expect_body(texts, lines, "22", bx, by, 2)
    absent(texts, "33")
    print("PASS: recap holds the final merge, loops and replays")
end

-- A frame without tag, second or merged (single source) draws one matrix in colour 1.
do
    local recap = new_recap({ { from_x = ax, from_y = ay, to_x = ax, to_y = ay, matrix = one(7) } })
    recap._anim_t = 1
    local texts, lines = capture(recap)
    expect_body(texts, lines, "7", ax, ay, 1)
    print("PASS: recap single-matrix frame")
end

-- Sources are numbered only when they carry an index.
do
    local grid = Grid.new(4, 4)
    grid:set_multi_2d(1, 1, { kind = "source", width = 2, height = 1, index = 1 }, 2, 1)
    grid:set(1, 2, { kind = "source", width = 1, height = 1, index = 2 })
    local texts = capture(new_recap({}, grid))
    assert(#texts_of(texts, "SRC 1") == 1 and #texts_of(texts, "SRC 2") == 1, "numbered sources")
    absent(texts, "SRC")

    grid = Grid.new(4, 4)
    grid:set(1, 1, { kind = "source", width = 1, height = 1 })
    texts = capture(new_recap({}, grid))
    assert(#texts_of(texts, "SRC") == 1, "single source stays SRC")
    print("PASS: recap source labels")
end

-- Two-cell tiles in all four facings: both operand cells are drawn once, in place,
-- and nothing else is drawn on the partner cell.
for _, facing in ipairs(Ops.FACINGS) do
    for _, op in ipairs(Ops.MATRIX_ORDER) do
        local grid = Grid.new(5, 5)
        grid:put(3, 3, { kind = "op", op = op, params = { facing = facing }, locked = true })
        local texts = capture(new_recap({}, grid))
        local px, py = Ops.partner(3, 3, facing)
        for role, at in pairs({ L = { 3, 3 }, R = { px, py } }) do
            local found = texts_of(texts, role)
            local sx, sy = cell(at[1], at[2])
            assert(#found == 1 and found[1].x == sx and found[1].y == sy + 6,
                op .. " " .. facing .. ": " .. role .. " drawn once in its cell")
            local in_cell = 0
            for _, t in ipairs(texts) do
                if t.x == sx and t.y >= sy and t.y < sy + CS then in_cell = in_cell + 1 end
            end
            assert(in_cell == 2, op .. " " .. facing .. ": only role and label in the "
                .. role .. " cell, got " .. in_cell)
        end
        assert(#texts_of(texts, Ops.label(op)) == 2, op .. " label in both cells")
    end
end
print("PASS: recap draws two-cell tiles in every facing")

Stubs.clear_text()
print("ALL TESTS PASSED")
