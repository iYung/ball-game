-- tests/test_op_tiles_model.lua
-- Unit tests for the editor's tile model in lua/game/op_tiles.lua: footprint, new tiles,
-- import from a puzzle def, and resize.

local OpTiles = require("lua/game/op_tiles")
local Sim     = require("lua/game/pusher_sim")
local Matrix  = require("lua/game/matrix_math")

local ALL_OPS = {
    "transpose", "scale_row", "swap_rows", "negate", "scalar_mul", "add_matrix",
    "sub_matrix", "mul_matrix", "set_row", "add_rows", "scale_col", "swap_cols",
    "add_cols", "set_col", "rotate_90", "flip_h", "flip_v", "abs",
}
local MATRIX_OPS = { "add_matrix", "sub_matrix", "mul_matrix" }

local function eq(got, want, msg)
    assert(got == want, msg .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function same(got, want, msg)
    if type(want) ~= "table" then return eq(got, want, msg) end
    assert(type(got) == "table", msg .. ": expected a table, got " .. tostring(got))
    for k, v in pairs(want) do same(got[k], v, msg .. "." .. tostring(k)) end
    for k in pairs(got) do
        assert(want[k] ~= nil, msg .. ": unexpected key " .. tostring(k))
    end
end

local function actions(tile)
    return table.concat(OpTiles.resize_actions(tile), " ")
end

local function size(tile, w, h, msg)
    eq(tile.width, w, msg .. " width")
    eq(tile.height, h, msg .. " height")
end

-- ── footprint ──────────────────────────────────────────────────────────────

do
    -- op, tile_rows, tile_cols, w, h
    local cases = {
        { "scalar_mul", nil, nil, 2, 1 },
        { "scale_row",  nil, nil, 1, 4 }, { "scale_row", 2, nil, 1, 2 },
        { "scale_col",  nil, nil, 4, 1 }, { "scale_col", nil, 3, 3, 1 },
        { "swap_rows",  nil, nil, 1, 2 },
        { "swap_cols",  nil, nil, 2, 1 },
        { "add_rows",   nil, nil, 4, 1 },
        { "add_cols",   nil, nil, 4, 1 },
        { "set_row",    nil, nil, 2, 1 }, { "set_row", nil, 3, 4, 1 },
        { "set_col",    nil, nil, 1, 2 }, { "set_col", 3, nil, 1, 4 },
        { "add_matrix", nil, nil, 1, 1 }, { "add_matrix", 2, 3, 3, 2 },
        { "sub_matrix", nil, nil, 1, 1 }, { "sub_matrix", 4, 1, 1, 4 },
        { "mul_matrix", nil, nil, 1, 1 }, { "mul_matrix", 1, 4, 4, 1 },
        { "transpose",  nil, nil, 1, 1 }, { "negate",  nil, nil, 1, 1 },
        { "rotate_90",  nil, nil, 1, 1 }, { "flip_h",  nil, nil, 1, 1 },
        { "flip_v",     nil, nil, 1, 1 }, { "abs",     3,   3,   1, 1 },
    }
    for _, c in ipairs(cases) do
        local w, h = OpTiles.footprint(c[1], c[2], c[3])
        local label = c[1] .. " " .. tostring(c[2]) .. "x" .. tostring(c[3])
        eq(w, c[4], label .. " w"); eq(h, c[5], label .. " h")
    end
    print("PASS: op_tiles footprint")
end

-- ── new_tile ───────────────────────────────────────────────────────────────

do
    local function tile(op, extra)
        local t = { kind="op", op=op, locked=true, params={}, width=1, height=1 }
        for k, v in pairs(extra or {}) do t[k] = v end
        return t
    end
    local expected = {
        transpose  = tile("transpose"),
        negate     = tile("negate"),
        rotate_90  = tile("rotate_90"),
        flip_h     = tile("flip_h"),
        flip_v     = tile("flip_v"),
        abs        = tile("abs"),
        scalar_mul = tile("scalar_mul", { params={scalar=2}, width=2 }),
        scale_row  = tile("scale_row",  { params={row=1, scalar=2}, tile_rows=4, height=4 }),
        scale_col  = tile("scale_col",  { params={col=1, scalar=2}, tile_cols=4, width=4 }),
        swap_rows  = tile("swap_rows",  { params={row_a=1, row_b=2}, height=2 }),
        swap_cols  = tile("swap_cols",  { params={col_a=1, col_b=2}, width=2 }),
        add_rows   = tile("add_rows",   { params={src=1, dst=2, scalar=1}, width=4 }),
        add_cols   = tile("add_cols",   { params={src=1, dst=2, scalar=1}, width=4 }),
        set_row    = tile("set_row",    { params={row=1}, tile_cols=1, values={{0}}, width=2 }),
        set_col    = tile("set_col",    { params={col=1}, tile_rows=3,
                                          values={{0},{0},{0}}, height=4 }),
        add_matrix = tile("add_matrix", { tile_rows=1, tile_cols=1, values={{0}} }),
        sub_matrix = tile("sub_matrix", { tile_rows=1, tile_cols=1, values={{0}} }),
        mul_matrix = tile("mul_matrix", { tile_rows=1, tile_cols=1, values={{1}} }),
    }
    for _, op in ipairs(ALL_OPS) do
        same(OpTiles.new_tile(op, 3), expected[op], "new " .. op)
    end

    local a = OpTiles.new_tile("add_matrix", 2)
    a.values[1][1] = 7
    eq(OpTiles.new_tile("add_matrix", 2).values[1][1], 0, "new_tile values are fresh")
    local s = OpTiles.new_tile("scalar_mul", 2)
    s.params.scalar = 7
    eq(OpTiles.new_tile("scalar_mul", 2).params.scalar, 2, "new_tile params are fresh")
    print("PASS: op_tiles new_tile")
end

-- ── new tiles run in the sim ───────────────────────────────────────────────

do
    local function input() return Matrix.new(2, 2, {{3,4},{5,6}}) end
    for _, op in ipairs(ALL_OPS) do
        local out = Sim.apply_op(OpTiles.new_tile(op, 2), input())
        assert(out and out.rows and out.cols, "apply_op accepts new " .. op)
    end
    local out = Sim.apply_op(OpTiles.new_tile("mul_matrix", 2), input())
    eq(out.values[1][1], 3, "new mul_matrix leaves (1,1) unchanged")
    print("PASS: op_tiles new tiles are accepted by the sim")
end

-- ── tile_from_def ──────────────────────────────────────────────────────────

do
    local function from(op, extra)
        local entry = { kind="op", op=op, x=3, y=4 }
        for k, v in pairs(extra or {}) do entry[k] = v end
        return OpTiles.tile_from_def(entry)
    end

    -- Bare entries get runtime fills, not new-tile defaults.
    local params = {
        scale_row  = { row=1, scalar=1 },
        scale_col  = { col=1, scalar=1 },
        swap_rows  = { row_a=1, row_b=2 },
        swap_cols  = { col_a=1, col_b=2 },
        scalar_mul = { scalar=1 },
        set_row    = { row=1 },
        set_col    = { col=1 },
        add_rows   = { src=1, dst=2, scalar=1 },
        add_cols   = { src=1, dst=2, scalar=1 },
    }
    for _, op in ipairs(ALL_OPS) do
        local t = from(op)
        eq(t.kind, "op", op .. " kind"); eq(t.op, op, op .. " op")
        eq(t.locked, true, op .. " locked")
        eq(t.x, nil, op .. " drops x"); eq(t.y, nil, op .. " drops y")
        same(t.params, params[op] or {}, op .. " params")
        local w, h = OpTiles.footprint(op, t.tile_rows, t.tile_cols)
        size(t, w, h, op)
    end
    for _, op in ipairs(MATRIX_OPS) do
        local t = from(op)
        eq(t.tile_rows, 1, op .. " rows"); eq(t.tile_cols, 1, op .. " cols")
        same(t.values, {{0}}, op .. " values are 0")
    end
    eq(from("scale_row").tile_rows, 4, "scale_row rows")
    eq(from("scale_col").tile_cols, 4, "scale_col cols")
    eq(from("set_row").tile_cols, 1, "set_row cols")
    same(from("set_row").values, {{0}}, "set_row values")
    eq(from("set_col").tile_rows, 1, "set_col rows")
    same(from("set_col").values, {{0}}, "set_col values")
    eq(from("transpose").values, nil, "no values on transpose")
    eq(from("transpose").tile_rows, nil, "no rows on transpose")

    -- Given sizes are preserved on any op; partial values are completed with 0.
    local t = from("transpose", { tile_rows=2, tile_cols=3 })
    eq(t.tile_rows, 2, "kept tile_rows"); eq(t.tile_cols, 3, "kept tile_cols")
    size(t, 1, 1, "transpose with sizes")
    size(from("scale_row", { tile_rows=1 }), 1, 1, "scale_row tile_rows=1")
    same(from("mul_matrix", { tile_rows=2, tile_cols=2, values={{5}} }).values,
        {{5,0},{0,0}}, "partial matrix values")
    same(from("set_row", { tile_cols=3, values={{1,2}} }).values, {{1,2,0}}, "set_row fill")
    same(from("set_col", { tile_rows=3, values={{1}} }).values, {{1},{0},{0}}, "set_col fill")

    -- Out-of-range and beyond-size values are kept; given params are kept.
    local big = from("add_matrix", { values={{42,-30},{7}} })
    same(big.values, {{42,-30},{7}}, "extra values kept")
    local p = from("add_rows", { params={src=9, scalar=0} })
    same(p.params, { src=9, dst=2, scalar=0 }, "given params kept")

    -- Explicit width / height win over the footprint, each on its own.
    size(from("set_row", { width=3, height=2 }), 3, 2, "explicit size")
    size(from("scale_row", { width=2 }), 2, 4, "explicit width only")
    size(from("scale_col", { height=2 }), 4, 2, "explicit height only")
    print("PASS: op_tiles tile_from_def fills runtime values")
end

do
    local entry = { kind="op", op="add_matrix", x=1, y=1, tile_rows=1, tile_cols=2,
                    values={{3}}, params={ extra={1} } }
    local t = OpTiles.tile_from_def(entry)
    same(entry.values, {{3}}, "entry values not filled in place")
    t.values[1][1] = 8
    t.params.extra[1] = 8
    eq(entry.values[1][1], 3, "values are a deep copy")
    eq(entry.params.extra[1], 1, "params are a deep copy")

    local bare = { kind="op", op="swap_rows", params={} }
    OpTiles.tile_from_def(bare)
    eq(next(bare.params), nil, "entry params not filled in place")
    print("PASS: op_tiles tile_from_def copies")
end

-- ── resize_actions ─────────────────────────────────────────────────────────

do
    local ROWS, COLS = "grow_row shrink_row", "grow_col shrink_col"
    for _, op in ipairs(ALL_OPS) do
        local t = OpTiles.new_tile(op, 2)
        local want = ({
            add_matrix = "grow_col grow_row",
            sub_matrix = "grow_col grow_row",
            mul_matrix = "grow_col grow_row",
            scale_row  = "shrink_row",
            scale_col  = "shrink_col",
            set_row    = "grow_col",
            set_col    = ROWS,
        })[op] or ""
        eq(actions(t), want, "new " .. op .. " actions")
        t.locked = false
        eq(actions(t), want, op .. " ignores locked")
    end
    for _, op in ipairs(MATRIX_OPS) do
        eq(actions({ op=op, tile_rows=2, tile_cols=3 }), COLS .. " " .. ROWS, op .. " middle")
        eq(actions({ op=op, tile_rows=4, tile_cols=4 }), "shrink_col shrink_row", op .. " max")
        eq(actions({ op=op }), "grow_col grow_row", op .. " no sizes")
    end
    eq(actions({ op="scale_row" }), "shrink_row", "scale_row without tile_rows is 4")
    eq(actions({ op="scale_row", tile_rows=1 }), "grow_row", "scale_row min")
    eq(actions({ op="scale_col" }), "shrink_col", "scale_col without tile_cols is 4")
    eq(actions({ op="scale_col", tile_cols=2 }), COLS, "scale_col middle")
    eq(actions({ op="set_row", tile_cols=4 }), "shrink_col", "set_row max")
    eq(actions({ op="set_col", tile_rows=1 }), "grow_row", "set_col min")
    print("PASS: op_tiles resize_actions")
end

-- ── resize ─────────────────────────────────────────────────────────────────

do
    for _, op in ipairs(ALL_OPS) do
        for _, action in ipairs({ "grow_col", "shrink_col", "grow_row", "shrink_row", "bogus" }) do
            local t = OpTiles.new_tile(op, 2)
            local before = OpTiles.new_tile(op, 2)
            local allowed = (" " .. actions(t) .. " "):find(" " .. action .. " ", 1, true) ~= nil
            eq(OpTiles.resize(t, action), allowed, op .. " " .. action .. " result")
            if allowed then
                local w, h = OpTiles.footprint(op, t.tile_rows, t.tile_cols)
                size(t, w, h, op .. " " .. action)
                assert(t.width ~= before.width or t.height ~= before.height,
                    op .. " " .. action .. " changes the footprint")
            else
                same(t, before, op .. " " .. action .. " leaves the tile alone")
            end
        end
    end
    print("PASS: op_tiles resize allowed and refused actions")
end

do
    for _, op in ipairs(MATRIX_OPS) do
        local fill = op == "mul_matrix" and 1 or 0
        local t = OpTiles.new_tile(op, 2)
        t.values[1][1] = 5

        for n = 2, 4 do
            assert(OpTiles.resize(t, "grow_col"), op .. " grow_col")
            eq(t.tile_cols, n, op .. " cols"); eq(t.values[1][n], fill, op .. " col fill")
        end
        eq(OpTiles.resize(t, "grow_col"), false, op .. " col limit")
        for n = 2, 4 do
            assert(OpTiles.resize(t, "grow_row"), op .. " grow_row")
            eq(t.tile_rows, n, op .. " rows")
            same(t.values[n], { fill, fill, fill, fill }, op .. " row fill")
        end
        eq(OpTiles.resize(t, "grow_row"), false, op .. " row limit")
        size(t, 4, 4, op .. " full")
        eq(t.values[1][1], 5, op .. " keeps old values")

        t.values[1][4], t.values[4][1] = -7, -8
        assert(OpTiles.resize(t, "shrink_col"), op .. " shrink_col")
        assert(OpTiles.resize(t, "shrink_row"), op .. " shrink_row")
        eq(#t.values, 3, op .. " rows dropped"); eq(#t.values[1], 3, op .. " cols dropped")
        eq(t.values[4], nil, op .. " row 4 gone"); eq(t.values[1][4], nil, op .. " col 4 gone")
        size(t, 3, 3, op .. " shrunk")
        assert(OpTiles.resize(t, "grow_col"))
        assert(OpTiles.resize(t, "grow_row"))
        eq(t.values[1][4], fill, op .. " regrown col"); eq(t.values[4][1], fill, op .. " regrown row")
        eq(t.values[1][1], 5, op .. " still keeps old values")
    end

    -- Stale entries beyond the size (from an import) are overwritten or removed.
    local t = OpTiles.tile_from_def({ kind="op", op="mul_matrix", values={{2,9},{9}} })
    assert(OpTiles.resize(t, "grow_col"))
    same(t.values, {{2,1}}, "stale values replaced on grow")
    print("PASS: op_tiles resize matrix ops")
end

do
    local r = OpTiles.new_tile("set_row", 2)
    r.values[1][1] = 3
    assert(OpTiles.resize(r, "grow_col"))
    same(r.values, {{3,0}}, "set_row grow"); size(r, 3, 1, "set_row grown")
    r.values[1][2] = 6
    assert(OpTiles.resize(r, "shrink_col"))
    same(r.values, {{3}}, "set_row shrink"); size(r, 2, 1, "set_row shrunk")
    assert(OpTiles.resize(r, "grow_col"))
    same(r.values, {{3,0}}, "set_row regrow shows the fill")

    local c = OpTiles.new_tile("set_col", 2)
    c.values[1][1] = 3
    assert(OpTiles.resize(c, "grow_row"))
    same(c.values, {{3},{0},{0}}, "set_col grow"); size(c, 1, 4, "set_col grown")
    c.values[3][1] = 6
    assert(OpTiles.resize(c, "shrink_row"))
    same(c.values, {{3},{0}}, "set_col shrink"); size(c, 1, 3, "set_col shrunk")
    assert(OpTiles.resize(c, "grow_row"))
    same(c.values, {{3},{0},{0}}, "set_col regrow shows the fill")
    print("PASS: op_tiles resize set_row and set_col")
end

do
    local cases = {
        { op="scale_row", key="row", shrink="shrink_row", grow="grow_row" },
        { op="scale_col", key="col", shrink="shrink_col", grow="grow_col" },
    }
    for _, c in ipairs(cases) do
        local t = OpTiles.new_tile(c.op, 2)
        t.params[c.key] = 4
        assert(OpTiles.resize(t, c.shrink))
        eq(t.params[c.key], 3, c.op .. " selected band pulled inside")
        t.params[c.key] = 1
        assert(OpTiles.resize(t, c.shrink))
        eq(t.params[c.key], 1, c.op .. " selected band inside is kept")
        assert(OpTiles.resize(t, c.grow))
        eq(t.params[c.key], 1, c.op .. " grow keeps the band")
        eq(t.params.scalar, 2, c.op .. " scalar untouched")
        eq(t.values, nil, c.op .. " has no values")

        -- Without params there is nothing to clamp.
        local bare = { kind="op", op=c.op }
        assert(OpTiles.resize(bare, c.shrink))
        eq(bare.params, nil, c.op .. " adds no params")
    end

    -- set_row's row index is not a size: resizing leaves it alone.
    local r = OpTiles.new_tile("set_row", 2)
    r.params.row = 4
    assert(OpTiles.resize(r, "grow_col"))
    eq(r.params.row, 4, "set_row row untouched")

    -- A tile without values gets a value block of the new size.
    local m = { kind="op", op="add_matrix" }
    assert(OpTiles.resize(m, "grow_row"))
    eq(m.values[2][1], 0, "fill on a tile without values")
    size(m, 1, 2, "tile without sizes")
    print("PASS: op_tiles resize scale bands")
end
