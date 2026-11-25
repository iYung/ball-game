-- tests/test_op_tiles.lua
-- Unit tests for lua/game/op_tiles.lua: default params, param limits, clicks and drawing.

local OpTiles = require("lua/game/op_tiles")
local Stubs   = require("lua/headless/stubs")

local CS = 60
local LEFT, CENTRE, RIGHT = 5, 30, 55
local LIMITS = { rows = 3, cols = 2, set_row = 4 }

local ALL_OPS = {
    "transpose", "scale_row", "swap_rows", "negate", "scalar_mul", "add_matrix",
    "sub_matrix", "mul_matrix", "set_row", "add_rows", "scale_col", "swap_cols",
    "add_cols", "set_col", "rotate_90", "flip_h", "flip_v", "abs",
}

local function eq(got, want, msg)
    assert(got == want, msg .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function click(tile, dc, dr, rel_x, limits)
    return OpTiles.click(tile, dc, dr, rel_x, CS, limits or LIMITS)
end

-- ── SYMBOLS / default_params ───────────────────────────────────────────────

do
    for _, op in ipairs(ALL_OPS) do
        assert(OpTiles.SYMBOLS[op], "symbol for " .. op)
    end

    local a = OpTiles.default_params("add_rows")
    eq(a.src, 1, "add_rows src"); eq(a.dst, 2, "add_rows dst"); eq(a.scalar, 1, "add_rows scalar")
    a.src = 9
    eq(OpTiles.default_params("add_rows").src, 1, "default_params returns a fresh copy")

    assert(next(OpTiles.default_params("set_col")) == nil, "set_col has no default params")
    assert(next(OpTiles.default_params("transpose")) == nil, "transpose has no default params")
    assert(next(OpTiles.default_params(nil)) == nil, "nil op has no default params")
    print("PASS: op_tiles symbols and default params")
end

-- ── param_defs ─────────────────────────────────────────────────────────────

do
    local limits = { rows = 3, cols = 2, set_row = 4 }
    local expected = {
        scale_row  = { {"row","row",1,3}, {"scalar","x",-9,9} },
        swap_rows  = { {"row_a","r1",1,3}, {"row_b","r2",1,3} },
        scalar_mul = { {"scalar","x",-9,9} },
        set_row    = { {"row","row",1,4} },
        add_rows   = { {"src","sr",1,3}, {"dst","dr",1,3}, {"scalar","x",-9,9} },
        scale_col  = { {"col","col",1,2}, {"scalar","x",-9,9} },
        swap_cols  = { {"col_a","c1",1,2}, {"col_b","c2",1,2} },
        add_cols   = { {"src","sc",1,2}, {"dst","dc",1,2}, {"scalar","x",-9,9} },
        set_col    = { {"col","col",1,2} },
    }
    for _, op in ipairs(ALL_OPS) do
        local defs, want = OpTiles.param_defs(op, limits), expected[op]
        if not want then
            assert(defs == nil, op .. " has no param defs")
        else
            eq(#defs, #want, op .. " def count")
            for i, w in ipairs(want) do
                eq(defs[i].key,   w[1], op .. " key")
                eq(defs[i].label, w[2], op .. " label")
                eq(defs[i].min,   w[3], op .. " min")
                eq(defs[i].max,   w[4], op .. " max")
            end
        end
    end

    local first = OpTiles.param_defs("set_row", limits)
    first[1].max = 99
    eq(OpTiles.param_defs("set_row", limits)[1].max, 4, "param_defs returns a fresh array")
    eq(OpTiles.param_defs("set_row", { rows = 3, cols = 2, set_row = 2 })[1].max, 2,
        "set_row limit comes from limits.set_row")
    print("PASS: op_tiles param_defs")
end

-- ── click: matrix ops ──────────────────────────────────────────────────────

do
    for _, op in ipairs({ "add_matrix", "sub_matrix", "mul_matrix" }) do
        local t = { op = op }
        assert(click(t, 1, 1, CENTRE), "centre is consumed")
        assert(t.values and t.values[2], "missing tables created")
        eq(t.values[2][2], nil, "centre changes nothing")
        click(t, 1, 1, RIGHT); eq(t.values[2][2], 1, "right third increments")
        click(t, 1, 1, LEFT);  click(t, 1, 1, LEFT)
        eq(t.values[2][2], -1, "left third decrements")
        click(t, 0, 0, RIGHT); eq(t.values[1][1], 1, "anchor is a value cell")
    end

    local t = { op = "add_matrix", values = { { 20 } } }
    click(t, 0, 0, CENTRE); eq(t.values[1][1], 20, "centre keeps out-of-range value")
    click(t, 0, 0, LEFT);   eq(t.values[1][1], 9,  "left clamps from above")
    t.values[1][1] = -20
    click(t, 0, 0, RIGHT);  eq(t.values[1][1], -9, "right clamps from below")
    click(t, 0, 0, LEFT);   eq(t.values[1][1], -9, "lower bound")
    t.values[1][1] = 9
    click(t, 0, 0, RIGHT);  eq(t.values[1][1], 9,  "upper bound")

    -- Third boundaries
    t.values[1][1] = 0
    click(t, 0, 0, CS / 3);         eq(t.values[1][1], 0, "one third is the centre")
    click(t, 0, 0, CS * 2 / 3);     eq(t.values[1][1], 1, "two thirds is the right third")
    print("PASS: op_tiles click matrix ops")
end

-- ── click: set_row / set_col ───────────────────────────────────────────────

do
    local t = { op = "set_row" }
    assert(click(t, 0, 0, CENTRE), "set_row param centre consumed")
    assert(t.params, "params created")
    eq(t.params.row, nil, "centre changes nothing")
    click(t, 0, 0, RIGHT); eq(t.params.row, 2, "nil row falls back to 1")
    click(t, 0, 0, LEFT);  click(t, 0, 0, LEFT); eq(t.params.row, 1, "row min")
    t.params.row = 9
    click(t, 0, 0, LEFT);  eq(t.params.row, 4, "row clamps to limits.set_row")
    t.params.row = -3
    click(t, 0, 0, RIGHT); eq(t.params.row, 1, "row clamps from below")

    assert(click(t, 2, 0, CENTRE), "value centre consumed")
    assert(t.values and t.values[1], "values created")
    eq(t.values[1][2], nil, "centre assigns nothing")
    click(t, 2, 0, LEFT); eq(t.values[1][2], -1, "set_row value")

    local c = { op = "set_col" }
    assert(click(c, 0, 0, CENTRE), "set_col param consumed")
    click(c, 0, 0, RIGHT); eq(c.params.col, 2, "nil col falls back to 1")
    click(c, 0, 0, RIGHT); eq(c.params.col, 2, "col max is limits.cols")
    click(c, 0, 0, LEFT);  eq(c.params.col, 1, "col decrement")
    assert(click(c, 0, 3, CENTRE), "value centre consumed")
    assert(c.values[3], "row table created")
    click(c, 0, 3, RIGHT); eq(c.values[3][1], 1, "set_col value")
    print("PASS: op_tiles click set_row / set_col")
end

-- ── click: scale_row / scale_col ───────────────────────────────────────────

do
    for _, case in ipairs({ { op = "scale_row", key = "row", dc = 0, dr = 2 },
                            { op = "scale_col", key = "col", dc = 2, dr = 0 } }) do
        for _, rel in ipairs({ LEFT, CENTRE, RIGHT }) do
            local t = { op = case.op }
            assert(click(t, case.dc, case.dr, rel), "band consumed")
            eq(t.params[case.key], 3, "any third selects an unselected band")
            eq(t.params.scalar, nil, "selecting leaves the scalar")
        end
        local t = { op = case.op, params = { [case.key] = 3 } }
        assert(click(t, case.dc, case.dr, CENTRE), "selected centre consumed")
        eq(t.params.scalar, nil, "centre changes nothing")
        click(t, case.dc, case.dr, RIGHT); eq(t.params.scalar, 3, "nil scalar falls back to 2")
        click(t, case.dc, case.dr, LEFT);  eq(t.params.scalar, 2, "scalar decrement")
        t.params.scalar = 30
        click(t, case.dc, case.dr, LEFT);  eq(t.params.scalar, 9, "scalar clamps from above")
        t.params.scalar = -30
        click(t, case.dc, case.dr, RIGHT); eq(t.params.scalar, -9, "scalar clamps from below")
    end
    print("PASS: op_tiles click scale bands")
end

-- ── click: swaps ───────────────────────────────────────────────────────────

do
    for _, case in ipairs({ { op = "swap_rows", a = "row_a", b = "row_b", dc = 0, dr = 1 },
                            { op = "swap_cols", a = "col_a", b = "col_b", dc = 1, dr = 0 } }) do
        local t = { op = case.op }
        assert(click(t, 0, 0, CENTRE), "centre consumed")
        eq(t.params[case.a], nil, "centre changes nothing")
        t.params = { [case.a] = 1, [case.b] = 2 }
        assert(click(t, 0, 0, RIGHT), "rejected change is consumed")
        eq(t.params[case.a], 1, "cannot equal the other index")
        click(t, case.dc, case.dr, LEFT)
        eq(t.params[case.b], 2, "second strip cannot equal the first")
        local small = { rows = 1, cols = 1, set_row = 1 }
        for _ = 1, 5 do click(t, case.dc, case.dr, RIGHT, small) end
        eq(t.params[case.b], 4, "range is 1..4 whatever the limits")
        click(t, 0, 0, RIGHT); eq(t.params[case.a], 2, "first strip increments")
        click(t, 0, 0, LEFT);  eq(t.params[case.a], 1, "first strip decrements")
        click(t, 0, 0, LEFT);  eq(t.params[case.a], 1, "lower bound")
        t.params[case.b] = 20
        click(t, case.dc, case.dr, LEFT); eq(t.params[case.b], 4, "out of range clamps")
    end
    print("PASS: op_tiles click swaps")
end

-- ── click: other ops ───────────────────────────────────────────────────────

do
    local s = { op = "scalar_mul" }
    eq(click(s, 0, 0, RIGHT), false, "anchor is not a param cell")
    assert(click(s, 1, 0, CENTRE), "param centre consumed")
    eq(s.params.scalar, nil, "centre changes nothing")
    click(s, 1, 0, RIGHT); eq(s.params.scalar, 1, "nil scalar falls back to 0")
    s.params.scalar = 15
    click(s, 1, 0, LEFT);  eq(s.params.scalar, 9, "clamp from above")

    for _, case in ipairs({ { op = "add_rows", max = 3 }, { op = "add_cols", max = 2 } }) do
        local t = { op = case.op, params = { src = 1, dst = 7, scalar = -9 } }
        click(t, 1, 0, LEFT);  eq(t.params.src, 1, "src min")
        click(t, 2, 0, LEFT);  eq(t.params.dst, case.max, "dst clamps to limit")
        click(t, 3, 0, LEFT);  eq(t.params.scalar, -9, "scalar min")
        click(t, 3, 0, RIGHT); eq(t.params.scalar, -8, "scalar increment")
        assert(click(t, 4, 0, RIGHT), "cell past the params is consumed")
        eq(t.params.src, 1, "and changes nothing")
    end

    for _, op in ipairs({ "transpose", "negate", "rotate_90", "flip_h", "flip_v", "abs" }) do
        local t = { op = op }
        eq(click(t, 0, 0, RIGHT), false, op .. " anchor returns false")
        eq(click(t, 0, 1, RIGHT), false, op .. " dc 0 returns false")
        eq(click(t, 1, 0, RIGHT), true, op .. " dc 1 is consumed")
        assert(t.params == nil and t.values == nil, op .. " gains no tables")
    end

    -- locked / fixed are the caller's concern
    local locked = { op = "scalar_mul", locked = true, fixed = true, params = { scalar = 2 } }
    click(locked, 1, 0, RIGHT)
    eq(locked.params.scalar, 3, "click ignores locked and fixed")
    print("PASS: op_tiles click other ops")
end

-- ── draw_cell / draw_overlay ───────────────────────────────────────────────

local FONTS = { cell = {}, ui = {} }

local function drawn(fn)
    Stubs.clear_text()
    fn()
    local out = {}
    for _, s in ipairs(Stubs.drawn_text()) do out[#out + 1] = s end
    return table.concat(out, "|")
end

local function cell_text(tile, dc, dr, editable)
    return drawn(function()
        OpTiles.draw_cell(tile, dc, dr, 10, 20, CS, FONTS, editable)
    end)
end

-- want is the text without marks; editable cells add "-|+" when marks is true.
local function check(tile, dc, dr, want, marks)
    local name = tostring(tile.op) .. " (" .. dc .. "," .. dr .. ")"
    local with = want
    if marks then with = (want == "" and "" or (want .. "|")) .. "-|+" end
    eq(cell_text(tile, dc, dr, true), with, name .. " editable")
    eq(cell_text(tile, dc, dr, false), want, name .. " not editable")
end

do
    for _, op in ipairs({ "add_matrix", "sub_matrix", "mul_matrix" }) do
        local t = { op = op, values = { { -3, 4 }, { 5 } } }
        check(t, 0, 0, OpTiles.SYMBOLS[op] .. "|1,1|-3", true)
        check(t, 1, 0, "2,1|4", true)
        check(t, 1, 1, "2,2|0", true)
        check({ op = op }, 0, 1, "1,2|0", true)
    end

    for _, case in ipairs({ { op = "scale_row", key = "row", p = "R" },
                            { op = "scale_col", key = "col", p = "C" } }) do
        local dc, dr = 0, 1
        if case.op == "scale_col" then dc, dr = 1, 0 end
        local t = { op = case.op, params = { [case.key] = 2, scalar = -3 } }
        check(t, dc, dr, case.p .. "2|×-3", true)
        check(t, 0, 0, case.p .. "1", false)
        check({ op = case.op, params = { [case.key] = 1 } }, 0, 0, case.p .. "1|×2", true)
        check({ op = case.op }, 0, 0, case.p .. "1", false)
    end

    check({ op = "swap_rows", params = { row_a = 3, row_b = 4 } }, 0, 0, "R3", true)
    check({ op = "swap_rows", params = { row_a = 3, row_b = 4 } }, 0, 1, "R4", true)
    check({ op = "swap_rows" }, 0, 0, "R1", true)
    check({ op = "swap_rows" }, 0, 1, "R2", true)
    check({ op = "swap_cols", params = { col_a = 3, col_b = 4 } }, 0, 0, "C3", true)
    check({ op = "swap_cols", params = { col_a = 3, col_b = 4 } }, 1, 0, "C4", true)
    check({ op = "swap_cols" }, 0, 0, "C1", true)
    check({ op = "swap_cols" }, 1, 0, "C2", true)

    local sr = { op = "set_row", params = { row = 3 }, values = { { 7 } } }
    check(sr, 0, 0, "row|3", true)
    check(sr, 1, 0, "c1|7", true)
    check(sr, 2, 0, "c2|0", true)
    local sc = { op = "set_col", params = { col = 2 }, values = { { 8 } } }
    check(sc, 0, 0, "col|2", true)
    check(sc, 0, 1, "r1|8", true)
    check(sc, 0, 2, "r2|0", true)
    check({ op = "set_col" }, 0, 0, "col|0", true)

    local sm = { op = "scalar_mul", params = { scalar = -3 } }
    check(sm, 0, 0, "xk", false)
    check(sm, 1, 0, "x|-3", true)
    check(sm, 2, 0, "", false)

    for _, case in ipairs({ { op = "add_rows", labels = { "sr", "dr", "x" } },
                            { op = "add_cols", labels = { "sc", "dc", "x" } } }) do
        local t = { op = case.op, params = { src = 5, dst = 6, scalar = 7 } }
        check(t, 0, 0, OpTiles.SYMBOLS[case.op], false)
        for i, label in ipairs(case.labels) do
            check(t, i, 0, label .. "|" .. (4 + i), true)
        end
    end

    for _, op in ipairs({ "transpose", "negate", "rotate_90", "flip_h", "flip_v", "abs" }) do
        check({ op = op }, 0, 0, OpTiles.SYMBOLS[op], false)
        check({ op = op }, 1, 0, "", false)
    end
    check({ op = "mystery" }, 0, 0, "?", false)
    print("PASS: op_tiles draw_cell")
end

do
    -- Two arrows (a shaft and a head each), drawn as lines with no text.
    local function overlay(op)
        local lines, real = {}, love.graphics.line
        love.graphics.line = function(...) lines[#lines+1] = table.concat({...}, ",") end
        local text = drawn(function() OpTiles.draw_overlay({ op = op }, 10, 20, CS) end)
        love.graphics.line = real
        eq(text, "", op .. " overlay draws no text")
        return lines
    end
    local mid, edge = 10 + CS / 2, 20 + CS
    local rows = overlay("swap_rows")
    eq(#rows, 4, "swap_rows overlay lines")
    eq(rows[1], table.concat({ mid-4, edge+6, mid-4, edge-6 }, ","), "swap_rows up shaft")
    eq(rows[3], table.concat({ mid+4, edge-6, mid+4, edge+6 }, ","), "swap_rows down shaft")
    local cols = overlay("swap_cols")
    eq(#cols, 4, "swap_cols overlay lines")
    eq(cols[1], table.concat({ 10+CS-6, 25, 10+CS+6, 25 }, ","), "swap_cols right shaft")
    eq(cols[3], table.concat({ 10+CS+6, 33, 10+CS-6, 33 }, ","), "swap_cols left shaft")
    for _, op in ipairs(ALL_OPS) do
        if op ~= "swap_rows" and op ~= "swap_cols" then
            eq(#overlay(op), 0, op .. " has no overlay")
        end
    end
    print("PASS: op_tiles draw_overlay")
end
