-- Matrix add / multiply, the two-cell ops, their grid tiles, firing rules and drawing.
local Ops     = require("lua/game/ops")
local Matrix  = require("lua/game/matrix_math")
local Grid    = require("lua/game/grid")
local TwoCell = require("lua/game/two_cell")
local OpTile  = require("lua/game/op_tile")
local Stubs   = require("lua/headless/stubs")

local function eq(got, want, label)
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function same(got, want, label)
    if type(want) ~= "table" then return eq(got, want, label) end
    eq(type(got), "table", label .. " type")
    for k, v in pairs(want) do same(got[k], v, label .. "." .. tostring(k)) end
    for k in pairs(got) do
        assert(want[k] ~= nil, label .. ": unexpected key " .. tostring(k))
    end
end

local function M(values)
    return Matrix.new(#values, #values[1], values)
end

local function shape(rows, cols)
    return Matrix.new(rows, cols)
end

-- Matrix add and multiply -----------------------------------------------------
do
    local a, b = M({ { 1, -2 }, { 0, 4 } }), M({ { 5, 2 }, { -3, -9 } })
    local sum = a:add(b)
    same(sum.values, { { 6, 0 }, { -3, -5 } }, "sum")
    assert(sum ~= a and sum ~= b, "add returns a new matrix")
    same(a.values, { { 1, -2 }, { 0, 4 } }, "add left unchanged")
    same(b.values, { { 5, 2 }, { -3, -9 } }, "add right unchanged")

    local l, r = M({ { 1, 2, 3 }, { 4, 5, -6 } }), M({ { 7, 8 }, { 9, 10 }, { -1, 2 } })
    local p = l:mul(r)
    eq(p.rows, 2, "product rows"); eq(p.cols, 2, "product cols")
    same(p.values, { { 22, 34 }, { 79, 70 } }, "product")
    local q = r:mul(l)
    eq(q.rows, 3, "swapped rows"); eq(q.cols, 3, "swapped cols")
    same(q.values, { { 39, 54, -27 }, { 49, 68, -33 }, { 7, 8, -15 } }, "swapped product")
    same(l.values, { { 1, 2, 3 }, { 4, 5, -6 } }, "mul left unchanged")
    same(r.values, { { 7, 8 }, { 9, 10 }, { -1, 2 } }, "mul right unchanged")
    same(M({ { 2 }, { 3 } }):mul(M({ { 4, 5 } })).values, { { 8, 10 }, { 12, 15 } }, "outer product")

    local neg = -1 * 0
    eq(tostring(M({ { neg } }):add(M({ { neg } })).values[1][1]), "0", "add -0")
    eq(tostring(M({ { 0 } }):mul(M({ { -3 } })).values[1][1]), "0", "mul -0")

    eq(pcall(a.add, a, shape(2, 3)), false, "add rejects cols")
    eq(pcall(a.add, a, shape(3, 2)), false, "add rejects rows")
    eq(pcall(a.mul, a, shape(3, 2)), false, "mul rejects inner sizes")
end

-- Ops ---------------------------------------------------------------------------
do
    eq(#Ops.ORDER, 10, "classic ops stay ten")
    same(Ops.MATRIX_ORDER, { "matrix_add", "matrix_mul" }, "MATRIX_ORDER")
    same(Ops.FACINGS, { "right", "bottom", "left", "top" }, "FACINGS")
    same(Ops.OFFSETS, { right = { dx = 1, dy = 0 }, bottom = { dx = 0, dy = 1 },
                        left = { dx = -1, dy = 0 }, top = { dx = 0, dy = -1 } }, "OFFSETS")

    for _, op in ipairs(Ops.ORDER) do eq(Ops.is_two_cell(op), false, op .. " one cell") end
    eq(Ops.is_two_cell("negate"), false, "unknown one cell")

    for op, label in pairs({ matrix_add = "M+", matrix_mul = "Mx" }) do
        eq(Ops.is_op(op), true, op .. " is_op")
        eq(Ops.is_two_cell(op), true, op .. " two cell")
        eq(Ops.has_scalar(op), false, op .. " no scalar")
        eq(Ops.has_edge(op), false, op .. " no edge")
        eq(Ops.range(op), nil, op .. " no range")
        eq(Ops.label(op), label, op .. " label")
        eq(Ops.tile_text(op), label, op .. " tile_text")
        eq(Ops.tile_text(op, { facing = "top" }), label, op .. " tile_text with facing")
        same(Ops.params(op), { facing = "right" }, op .. " defaults")
        same(Ops.params(op, { facing = "left", scalar = 3, edge = "top" }), { facing = "left" },
             op .. " overrides")
        eq(Ops.validate(op), true, op .. " validate nil")
        eq(Ops.validate(op, {}), true, op .. " validate empty")
        for _, facing in ipairs(Ops.FACINGS) do
            eq(Ops.validate(op, { facing = facing }), true, op .. " " .. facing)
        end
        for _, bad in ipairs({ "up", 2, false }) do
            local ok, message = Ops.validate(op, { facing = bad })
            eq(ok, false, op .. " bad facing")
            eq(message, "Invalid facing: " .. tostring(bad), op .. " bad facing message")
        end
        for _, part in ipairs({ "left", "centre", "right" }) do
            local params = { facing = "bottom" }
            Ops.click(op, params, part)
            same(params, { facing = "bottom" }, op .. " click " .. part)
        end
        eq(Ops.tool_label(op, "right"),  label .. ">", op .. " tool right")
        eq(Ops.tool_label(op, "bottom"), label .. "v", op .. " tool bottom")
        eq(Ops.tool_label(op, "left"),   label .. "<", op .. " tool left")
        eq(Ops.tool_label(op, "top"),    label .. "^", op .. " tool top")
        eq(Ops.tool_label(op),           label .. ">", op .. " tool default")
        eq(Ops.fixed_label(op),          label .. ">!", op .. " fixed default")
        eq(Ops.fixed_label(op, { facing = "top" }), label .. "^!", op .. " fixed top")
    end

    eq(Ops.next_facing("right"), "bottom", "next right")
    eq(Ops.next_facing("bottom"), "left", "next bottom")
    eq(Ops.next_facing("left"), "top", "next left")
    eq(Ops.next_facing("top"), "right", "next top")
    eq(Ops.next_facing(nil), "bottom", "next nil")

    for facing, want in pairs({ right = { 5, 4 }, bottom = { 4, 5 },
                                left = { 3, 4 }, top = { 4, 3 } }) do
        local px, py = Ops.partner(4, 4, facing)
        eq(px, want[1], facing .. " partner x"); eq(py, want[2], facing .. " partner y")
    end
    local px, py = Ops.partner(2, 7)
    eq(px, 3, "default partner x"); eq(py, 7, "default partner y")

    eq(Ops.merge_error("matrix_add", shape(2, 3), shape(2, 3)), nil, "add fits")
    eq(Ops.merge_error("matrix_add", shape(2, 3), shape(2, 2)),
       "FAIL — can't add 2x3 and 2x2", "add cols")
    eq(Ops.merge_error("matrix_add", shape(1, 2), shape(3, 2)),
       "FAIL — can't add 1x2 and 3x2", "add rows")
    eq(Ops.merge_error("matrix_mul", shape(2, 3), shape(3, 4)), nil, "mul fits")
    eq(Ops.merge_error("matrix_mul", shape(2, 3), shape(2, 2)),
       "FAIL — can't multiply 2x3 by 2x2", "mul inner")

    local a, b = M({ { 1, 2 }, { 3, 4 } }), M({ { 0, 1 }, { 1, 0 } })
    same(Ops.combine("matrix_add", a, b).values, { { 1, 3 }, { 4, 4 } }, "combine add")
    same(Ops.combine("matrix_mul", a, b).values, { { 2, 1 }, { 4, 3 } }, "combine mul")
    same(Ops.combine("matrix_mul", b, a).values, { { 3, 4 }, { 1, 2 } }, "combine mul order")
    same(a.values, { { 1, 2 }, { 3, 4 } }, "combine left unchanged")
    same(b.values, { { 0, 1 }, { 1, 0 } }, "combine right unchanged")
end

-- Grid --------------------------------------------------------------------------
local function two(facing, extra)
    local tile = { kind = "op", op = "matrix_add", params = { facing = facing } }
    for k, v in pairs(extra or {}) do tile[k] = v end
    return tile
end

local function used(grid)
    local n = 0
    for y = 1, grid.h do
        for x = 1, grid.w do
            if grid.cells[y][x] then n = n + 1 end
        end
    end
    return n
end

for _, facing in ipairs(Ops.FACINGS) do
    local g = Grid.new(3, 3)
    local tile = two(facing)
    local px, py = Ops.partner(2, 2, facing)
    eq(g:fits(2, 2, tile), true, facing .. " fits")
    g:put(2, 2, tile)
    eq(used(g), 2, facing .. " two cells")
    eq(g:get(2, 2), tile, facing .. " anchor")
    eq(g:get(px, py), tile, facing .. " partner resolves")
    same(g.cells[py][px], { ref = true, ax = 2, ay = 2 }, facing .. " ref")
    eq(g:fits(2, 2, two(facing)), false, facing .. " anchor occupied")
    same(g:two_cell_tiles(), { { x = 2, y = 2, rx = px, ry = py, tile = tile } },
         facing .. " listed")

    -- Clearing either cell removes both.
    g:clear(2, 2)
    eq(used(g), 0, facing .. " clear anchor")
    g:put(2, 2, tile)
    g:clear(px, py)
    eq(used(g), 0, facing .. " clear partner")
    g:put(2, 2, tile)
    g:clear_all()
    eq(used(g), 0, facing .. " clear_all")

    -- Locked tiles stay.
    g:put(2, 2, two(facing, { locked = true }))
    g:clear(2, 2); g:clear(px, py); g:clear_all()
    eq(used(g), 2, facing .. " locked stays")

    -- Partner occupied.
    local o = Grid.new(3, 3)
    o:set(px, py, { kind = "gap" })
    eq(o:fits(2, 2, tile), false, facing .. " partner occupied")

    -- Partner off the grid: the anchor sits on the edge the facing points at.
    local d = Ops.OFFSETS[facing]
    local ex, ey = 2 + d.dx, 2 + d.dy
    local e = Grid.new(3, 3)
    eq(e:fits(ex, ey, tile), false, facing .. " partner off grid")
    eq(pcall(e.put, e, ex, ey, tile), false, facing .. " put asserts")
    eq(used(e), 0, facing .. " failed put writes nothing")

    -- Rotate from either cell with all room free: next clockwise facing.
    for _, from_partner in ipairs({ false, true }) do
        local r = Grid.new(3, 3)
        local t = two(facing)
        r:put(2, 2, t)
        local cx, cy = 2, 2
        if from_partner then cx, cy = px, py end
        eq(r:rotate(cx, cy), true, facing .. " rotates")
        eq(t.params.facing, Ops.next_facing(facing), facing .. " rotated facing")
        local nx, ny = Ops.partner(2, 2, t.params.facing)
        eq(used(r), 2, facing .. " still two cells")
        eq(r:get(nx, ny), t, facing .. " new partner")
        eq(r.cells[py][px], nil, facing .. " old partner free")
    end

    -- The next cell is occupied: skip to the one after.
    local next1 = Ops.next_facing(facing)
    local next2 = Ops.next_facing(next1)
    local s = Grid.new(3, 3)
    local t = two(facing)
    s:put(2, 2, t)
    local bx, by = Ops.partner(2, 2, next1)
    s:set(bx, by, { kind = "gap" })
    eq(s:rotate(2, 2), true, facing .. " skips occupied")
    eq(t.params.facing, next2, facing .. " skipped facing")

    -- None free: nothing changes.
    local n = Grid.new(3, 3)
    local u = two(facing)
    n:put(2, 2, u)
    for _, other in ipairs(Ops.FACINGS) do
        if other ~= facing then
            local x, y = Ops.partner(2, 2, other)
            n:set(x, y, { kind = "gap" })
        end
    end
    eq(n:rotate(px, py), false, facing .. " none free")
    eq(u.params.facing, facing, facing .. " facing kept")
    eq(n:get(px, py), u, facing .. " partner kept")
    eq(used(n), 5, facing .. " grid unchanged")
end

do
    -- Edge skipping: in a corner only right and bottom are on the grid.
    local g = Grid.new(3, 3)
    local tile = two("bottom")
    g:put(1, 1, tile)
    eq(g:rotate(1, 1), true, "corner rotate")
    eq(tile.params.facing, "right", "left and top are skipped")

    -- Missing params mean facing right; rotating creates them.
    local d = Grid.new(3, 3)
    local bare = { kind = "op", op = "matrix_mul" }
    eq(d:fits(3, 1, bare), false, "bare tile faces right")
    d:put(1, 1, bare)
    eq(d:get(2, 1), bare, "bare partner")
    eq(d:rotate(2, 1), true, "bare rotates")
    eq(bare.params.facing, "bottom", "bare facing")
    d:put(2, 2, { kind = "op", op = "matrix_mul", params = {} })
    eq(d:two_cell_tiles()[2].rx, 3, "empty params face right")

    -- One-cell tiles.
    local o = Grid.new(3, 3)
    local gap = { kind = "gap" }
    eq(o:fits(0, 1, gap), false, "off grid")
    eq(o:fits(3, 3, gap), true, "one cell on the edge")
    eq(o:fits(3, 3, { kind = "op", op = "flip_h" }), true, "classic op is one cell")
    o:put(3, 3, gap)
    eq(used(o), 1, "put one cell")
    eq(o:fits(3, 3, gap), false, "occupied")
    eq(o:rotate(3, 3), false, "cannot rotate a gap")
    eq(o:rotate(1, 1), false, "cannot rotate nothing")
    eq(o:rotate(0, 1), false, "cannot rotate off grid")
    same(o:two_cell_tiles(), {}, "no two-cell tiles")

    -- Reading order of the left-operand cell, whatever the facing.
    local r = Grid.new(6, 6)
    r:put(5, 3, two("left"))
    r:put(1, 3, two("top"))
    r:put(6, 1, two("bottom"))
    local order = {}
    for _, e in ipairs(r:two_cell_tiles()) do order[#order + 1] = e.x .. "," .. e.y end
    eq(table.concat(order, " "), "6,1 1,3 5,3", "reading order")
end

-- TwoCell -------------------------------------------------------------------------
local function body(x, y, rows, cols)
    local values = {}
    for r = 1, rows do
        values[r] = {}
        for c = 1, cols do values[r][c] = r + c end
    end
    return { x = x, y = y, matrix = Matrix.new(rows, cols, values) }
end

local function tiles(...)
    local g = Grid.new(12, 12)
    for _, spec in ipairs({ ... }) do
        g:put(spec[1], spec[2], { kind = "op", op = spec[3], params = { facing = spec[4] } })
    end
    return g:two_cell_tiles()
end

do
    local b = body(2, 3, 2, 3)  -- columns 2..4, rows 3..4
    eq(TwoCell.covers(b, 2, 3), true, "top-left")
    eq(TwoCell.covers(b, 4, 4), true, "bottom-right")
    eq(TwoCell.covers(b, 1, 3), false, "left of")
    eq(TwoCell.covers(b, 5, 3), false, "right of")
    eq(TwoCell.covers(b, 2, 2), false, "above")
    eq(TwoCell.covers(b, 2, 5), false, "below")
end

do
    local list = tiles({ 4, 4, "matrix_add", "right" })
    local a, b = body(4, 4, 1, 1), body(5, 4, 1, 1)
    local away = body(9, 9, 1, 1)

    eq(TwoCell.judge({}, a, b), nil, "no tiles")
    eq(TwoCell.judge(list, away, nil), nil, "nothing covered")
    eq(TwoCell.judge(list, a, nil), nil, "one cell, single matrix")
    eq(TwoCell.judge(list, b, nil), nil, "right cell only")
    eq(TwoCell.judge(list, away, b), nil, "second matrix waits")

    local hit = TwoCell.judge(list, a, b)
    eq(hit.status, nil, "merge has no status")
    eq(hit.entry, list[1], "merge entry")
    eq(hit.left, a, "left body"); eq(hit.right, b, "right body")
    same(hit.matrix.values, { { 4 } }, "merge result")
    local swapped = TwoCell.judge(list, b, a, {})
    eq(swapped.left, a, "left follows the cell"); eq(swapped.right, b, "right follows the cell")

    same(TwoCell.judge(list, body(4, 4, 1, 2), nil), { status = "both_inputs" }, "a on both")
    same(TwoCell.judge(list, away, body(4, 4, 1, 2)), { status = "both_inputs" }, "b on both")

    same(TwoCell.judge(list, body(3, 3, 2, 2), body(5, 4, 3, 2)),
         { status = "bad_shape", message = "FAIL — can't add 2x2 and 3x2" }, "bad shape")
    same(TwoCell.judge(list, body(5, 4, 3, 2), body(3, 3, 2, 2)),
         { status = "bad_shape", message = "FAIL — can't add 2x2 and 3x2" }, "left named first")

    -- Rotated: the left operand is above, below or right of the right operand.
    for _, facing in ipairs(Ops.FACINGS) do
        local l = tiles({ 4, 4, "matrix_mul", facing })
        local px, py = Ops.partner(4, 4, facing)
        local left, right = body(4, 4, 1, 1), body(px, py, 1, 1)
        local res = TwoCell.judge(l, right, left)
        eq(res.left, left, facing .. " left"); eq(res.right, right, facing .. " right")
        same(res.matrix.values, { { 4 } }, facing .. " product")
    end

    -- Disarmed tiles are ignored, for merges and for both inputs.
    local off = { ["4,4"] = true }
    eq(TwoCell.judge(list, a, b, off), nil, "disarmed merge")
    eq(TwoCell.judge(list, body(4, 4, 1, 2), nil, off), nil, "disarmed both inputs")
end

do
    -- A later "both inputs" beats an earlier merge or shape error.
    local list = tiles({ 2, 1, "matrix_add", "right" }, { 2, 5, "matrix_add", "bottom" })
    local a, b = body(2, 1, 1, 1), body(3, 1, 1, 1)
    local tall = body(2, 5, 2, 1)
    eq(TwoCell.judge(list, a, b).entry, list[1], "merge without the violation")
    local merged_first = tiles({ 2, 1, "matrix_add", "right" }, { 3, 2, "matrix_add", "bottom" })
    same(TwoCell.judge(merged_first, a, body(3, 1, 3, 1)), { status = "both_inputs" },
         "both inputs before merge")
    same(TwoCell.judge(merged_first, a, body(3, 1, 3, 2)), { status = "both_inputs" },
         "both inputs before shape check")
    same(TwoCell.judge(list, tall, nil), { status = "both_inputs" }, "second tile violation")

    -- Otherwise the first tile in list order with both cells covered decides.
    local two_ready = tiles({ 2, 1, "matrix_add", "right" }, { 2, 2, "matrix_mul", "right" })
    local left, right = body(2, 1, 2, 1), body(3, 1, 2, 1)
    local first = TwoCell.judge(two_ready, left, right)
    eq(first.entry, two_ready[1], "first tile merges")
    eq(first.status, nil, "later bad shape is not reached")
    local bad_first = tiles({ 2, 1, "matrix_mul", "right" }, { 2, 2, "matrix_add", "right" })
    same(TwoCell.judge(bad_first, left, right),
         { status = "bad_shape", message = "FAIL — can't multiply 2x1 by 2x1" },
         "first tile's error")

    -- A half-covered earlier tile does not stop a later one.
    local later = tiles({ 8, 1, "matrix_add", "right" }, { 2, 5, "matrix_add", "right" })
    local res = TwoCell.judge(later, body(8, 1, 1, 1), body(2, 5, 1, 1))
    eq(res, nil, "two half-covered tiles")
    local ready = tiles({ 2, 1, "matrix_add", "right" }, { 2, 5, "matrix_add", "bottom" })
    local got = TwoCell.judge(ready, body(2, 6, 1, 1), body(2, 5, 1, 1))
    eq(got.entry, ready[2], "later tile merges")
end

do
    local list = tiles({ 2, 2, "matrix_add", "right" }, { 6, 6, "matrix_mul", "top" })
    local disarmed = {}
    TwoCell.disarm(disarmed, list, body(10, 10, 1, 1))
    same(disarmed, {}, "disarm nothing")
    TwoCell.disarm(disarmed, list, body(3, 2, 1, 1))
    same(disarmed, { ["2,2"] = true }, "disarm by right cell")
    TwoCell.disarm(disarmed, list, body(6, 6, 1, 1))
    same(disarmed, { ["2,2"] = true, ["6,6"] = true }, "disarm by left cell")

    TwoCell.rearm(disarmed, list, body(2, 2, 1, 1))
    same(disarmed, { ["2,2"] = true }, "still on the left cell")
    TwoCell.rearm(disarmed, list, body(3, 2, 1, 1))
    same(disarmed, { ["2,2"] = true }, "still on the right cell")
    TwoCell.rearm(disarmed, list, body(4, 2, 1, 1))
    same(disarmed, {}, "re-armed after leaving")

    local stale = { ["9,9"] = true, ["2,2"] = true }
    TwoCell.rearm(stale, list, body(2, 2, 1, 1))
    same(stale, { ["2,2"] = true }, "keys with no tile are dropped")
    TwoCell.rearm(stale, {}, body(2, 2, 1, 1))
    same(stale, {}, "no tiles")
end

-- Drawing -------------------------------------------------------------------------
do
    local FONTS = { cell = {}, ui = {} }
    local CS = 52
    local rects, fonts_used = {}, {}
    local colour, current_font
    local g = love.graphics
    local orig = { rectangle = g.rectangle, setColor = g.setColor, setFont = g.setFont,
                   printf = g.printf, newFont = g.newFont }
    local made = 0
    g.newFont = function(...) made = made + 1; return orig.newFont(...) end
    g.rectangle = function(mode, x, y, w, h)
        rects[#rects + 1] = { shape = table.concat({ mode, x, y, w, h }, ","), colour = colour }
    end
    g.setColor = function(r, gr, b, a)
        colour = table.concat({ r, gr, b }, ",")
        eq(a, 1, "solid colours only")
    end
    g.setFont = function(f) current_font = f end
    g.printf = function(text, x, y, ...)
        fonts_used[#fonts_used + 1] = { text = text, x = x, y = y, font = current_font }
        orig.printf(text, x, y, ...)
    end

    local function reset()
        rects, fonts_used = {}, {}
        Stubs.clear_text()
    end

    local OUTLINE = {
        right  = "line,101,201,102,50",
        bottom = "line,101,201,50,102",
        left   = "line,49,201,102,50",
        top    = "line,101,149,50,102",
    }
    local large
    for _, op in ipairs(Ops.MATRIX_ORDER) do
        local label = Ops.label(op)
        for _, facing in ipairs(Ops.FACINGS) do
            reset()
            local tag = op .. " " .. facing
            OpTile.draw({ kind = "op", op = op, params = { facing = facing } },
                        100, 200, CS, FONTS, { marks = true, immutable = false })
            eq(table.concat(Stubs.drawn_text(), " "),
               "L " .. label .. " R " .. label, tag .. " texts (no marks)")
            local d = Ops.OFFSETS[facing]
            local rx, ry = 100 + d.dx * CS, 200 + d.dy * CS
            eq(#rects, 3, tag .. " two fills and one border")
            eq(rects[1].shape, "fill,100,200,52,52", tag .. " left cell")
            eq(rects[2].shape, table.concat({ "fill", rx, ry, CS, CS }, ","), tag .. " right cell")
            assert(rects[1].colour ~= rects[2].colour, tag .. " distinct shades")
            eq(rects[3].shape, OUTLINE[facing], tag .. " shared border")
            eq(fonts_used[1].x, 100, tag .. " L x")
            eq(fonts_used[3].x, rx, tag .. " R x")
            large = large or fonts_used[1].font
            eq(fonts_used[1].font, large, tag .. " L large font")
            eq(fonts_used[3].font, large, tag .. " R large font")
            assert(large ~= FONTS.cell and large ~= FONTS.ui, tag .. " own large font")
            eq(fonts_used[2].font, FONTS.cell, tag .. " label font")
        end
    end
    assert(made <= 1, "the large font is created once")

    reset()
    OpTile.draw({ kind = "op", op = "matrix_add" }, 0, 0, CS, FONTS, {})
    eq(rects[2].shape, "fill,52,0,52,52", "nil params face right")

    local badge_colour = {}
    for _, role in ipairs({ "L", "R" }) do
        reset()
        OpTile.draw_badge(role, 100, 200, CS, FONTS.ui)
        eq(table.concat(Stubs.drawn_text(), " "), role, role .. " badge text")
        eq(fonts_used[1].font, FONTS.ui, role .. " badge font")
        eq(rects[1].shape, "fill,102,202,14,14", role .. " badge in the corner")
        eq(#rects, 2, role .. " badge fill and border")
        badge_colour[role] = rects[1].colour
    end
    assert(badge_colour.L ~= badge_colour.R, "badge shades differ")

    for name, fn in pairs(orig) do g[name] = fn end
end

print("PASS: matrix ops, two-cell tiles, firing rules and drawing")
