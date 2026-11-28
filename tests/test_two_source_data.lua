-- test_two_source_data.lua
-- Every shipped puzzle with a second source or a two-cell tile is laid out soundly
-- (checked from the defs, since the scene silently overwrites), and the Two Sources
-- world is complete, locked until earlier worlds are solved, and needs its ideas.

local PuzzleLoader = require("lua/game/puzzle_loader")
local Progress     = require("lua/game/progress")
local Matrix       = require("lua/game/matrix_math")
local Ops          = require("lua/game/ops")
local DefParser    = require("lua/game/def_parser")
local S            = require("tests/support/shipped")

local function is_two_cell(t)
    return t.kind == "op" and Ops.is_two_cell(t.op)
end

local function uses_pairs(def)
    if def.source2 or def.input2 then return true end
    for _, t in ipairs(def.locked or {}) do
        if is_two_cell(t) then return true end
    end
    return false
end

local function check_layout(where, def)
    assert((def.source2 == nil) == (def.input2 == nil),
        where .. ": source2 and input2 come together")

    local used = {}   -- "x,y" -> what sits there
    local function take(x, y, what)
        assert(x >= 1 and x <= def.grid_w and y >= 1 and y <= def.grid_h,
            string.format("%s: %s at %d,%d is off the grid", where, what, x, y))
        local key = x .. "," .. y
        assert(not used[key], string.format("%s: %s overlaps %s at %s",
            where, what, tostring(used[key]), key))
        used[key] = what
    end
    local function footprint(at, input, what)
        for r = 0, input.rows - 1 do
            for c = 0, input.cols - 1 do take(at.x + c, at.y + r, what) end
        end
    end

    footprint(def.source, def.input, "source")
    if def.source2 then footprint(def.source2, def.input2, "source2") end
    take(def.sink.x, def.sink.y, "sink")
    for _, g in ipairs(def.gaps or {}) do take(g.x, g.y, "gap") end
    for i, t in ipairs(def.locked or {}) do
        local what = string.format("locked[%d]", i)
        take(t.x, t.y, what)
        if is_two_cell(t) then
            local ok, message = Ops.validate(t.op, t.params)
            assert(ok, string.format("%s: %s: %s", where, what, tostring(message)))
            local rx, ry = Ops.partner(t.x, t.y, Ops.params(t.op, t.params).facing)
            take(rx, ry, what)
        end
    end
end

local checked = 0
for n = 1, PuzzleLoader.count() do
    local def = PuzzleLoader.load(n)
    if uses_pairs(def) then
        check_layout(PuzzleLoader.path(n), def)
        checked = checked + 1
    end
end
assert(checked >= 4, "expected the two-source puzzles to be checked")
print("PASS: two-source layouts are sound")

-- ── The world ────────────────────────────────────────────────────────────────

local IDS = { "first_sum", "take_away", "turned_sum", "operand_order", "two_preps",
    "merge_maze" }
local world = S.world("two_sources")
local indices = PuzzleLoader.world_indices(world)
assert(PuzzleLoader.world(world).name == "Two Sources", "tab name")
assert(#indices >= #IDS, "Two Sources opens with these puzzles")
assert(PuzzleLoader.cutscene_path(world) == nil, "no cutscene")

local defs = {}
for i, id in ipairs(IDS) do
    local n = indices[i]
    assert(PuzzleLoader.id(n) == id, "puzzle " .. i .. " is " .. id)
    local def = PuzzleLoader.load(n)
    defs[id] = def
    assert(type(def.ops) == "table", id .. " lists its ops")
    assert(def.source2 and def.input2, id .. " has two sources")
    local file = assert(io.open(PuzzleLoader.path(n), "r"))
    local text = file:read("*a")
    file:close()
    assert(text:match("^%-%-") and text:find("Reference solution", 1, true),
        id .. " documents its reference solution")
    local parsed, err = DefParser.parse(text)
    assert(parsed, id .. " parses as pasted text: " .. tostring(err))
    assert(parsed.name == def.name, id .. " parses to the same puzzle")
end
print("PASS: the Two Sources world opens with its puzzles in order")

Progress.reset()
local before = S.before(world)
assert(not Progress.is_world_unlocked(world), "locked on a fresh save")
for i = 1, #before - 1 do Progress.mark_solved(before[i]) end
assert(not Progress.is_world_unlocked(world), "locked with one earlier puzzle unsolved")
Progress.mark_solved(before[#before])
assert(Progress.is_world_unlocked(world), "open once all earlier puzzles are solved")
Progress.reset()
print("PASS: the world unlocks after all earlier worlds")

-- ── Each puzzle needs its idea ───────────────────────────────────────────────

local function matrix(m) return Matrix.new(m.rows, m.cols, m.values) end

local function parts(id)
    local def = defs[id]
    return matrix(def.input), matrix(def.input2), matrix(def.target)
end

-- Whether L op R is a valid merge that equals the target.
local function hits(op, L, R, target)
    return Ops.merge_error(op, L, R) == nil and Ops.combine(op, L, R):equals(target)
end

local function offers(id, list)
    local ops = defs[id].ops
    assert(#ops == #list, id .. " offers only its ops")
    for i, op in ipairs(list) do assert(ops[i] == op, id .. " offers " .. op) end
end

do
    local a, b, target = parts("first_sum")
    offers("first_sum", {})
    assert(hits("matrix_add", a, b, target), "first_sum target is the sum")
    local t = defs.first_sum.locked[1]
    assert(t.op == "matrix_add", "first_sum locks M+ on the board")
end

do
    local def = defs.turned_sum
    local a, b, target = parts("turned_sum")
    offers("turned_sum", { "matrix_add" })
    assert(hits("matrix_add", a, b, target), "turned_sum target is the sum")

    -- No two non-overlapping matrix positions put different matrices on two
    -- horizontally adjacent cells, so an M+ lying flat can never fire.
    local gap = {}
    for _, g in ipairs(def.gaps) do gap[g.x .. "," .. g.y] = true end
    local spots = {}
    for y = 1, def.grid_h - 1 do
        for x = 1, def.grid_w - 1 do
            if not (gap[x .. "," .. y] or gap[(x + 1) .. "," .. y]
                    or gap[x .. "," .. (y + 1)] or gap[(x + 1) .. "," .. (y + 1)]) then
                spots[#spots + 1] = { x = x, y = y }
            end
        end
    end
    local upright = false
    for _, p in ipairs(spots) do
        for _, q in ipairs(spots) do
            local dx, dy = q.x - p.x, q.y - p.y
            if math.abs(dx) >= 2 or math.abs(dy) >= 2 then
                local shared_row = math.abs(dy) <= 1
                assert(not (shared_row and math.abs(dx) >= 2),
                    string.format("turned_sum: matrices fit side by side at %d,%d and %d,%d",
                        p.x, p.y, q.x, q.y))
                if math.abs(dx) <= 1 then upright = true end
            end
        end
    end
    assert(upright, "turned_sum: matrices can stand one above the other")
end

do
    local a, b, target = parts("operand_order")
    offers("operand_order", { "matrix_mul" })
    assert(a.rows ~= a.cols and b.rows ~= b.cols, "operand_order inputs are not square")
    assert(hits("matrix_mul", b, a, target), "target is INPUT 2 x INPUT 1")
    assert(Ops.merge_error("matrix_mul", a, b) == nil, "the swapped order is a valid product")
    assert(not hits("matrix_mul", a, b, target), "the swapped order misses the target")
end

do
    local a, b, target = parts("merge_maze")
    offers("merge_maze", { "transpose", "matrix_mul" })
    assert(Ops.merge_error("matrix_mul", a, b), "the raw inputs cannot be multiplied")
    assert(Ops.merge_error("matrix_mul", b, a), "in either order")
    assert(hits("matrix_mul", a, b:transpose(), target), "target is INPUT 1 x T(INPUT 2)")
    assert(not hits("matrix_mul", b, a:transpose(), target), "the swapped order misses")
    assert(not hits("matrix_mul", a:transpose(), b, target), "transposing INPUT 1 misses")
    assert(#defs.merge_maze.gaps > 0, "merge_maze has gaps")

    -- The status banner hides row 10: the sink and the winning matrix stay above it.
    local def = defs.merge_maze
    assert(def.sink.y <= 9, "merge_maze: the sink is above the banner")
    local walled = {}
    for _, g in ipairs(def.gaps) do
        if g.y == 10 then walled[g.x] = true end
    end
    for x = 1, 10 do assert(walled[x], "merge_maze: row 10 is closed at " .. x) end
end
print("PASS: each puzzle needs its idea")

print("ALL TWO SOURCE DATA TESTS PASSED")
