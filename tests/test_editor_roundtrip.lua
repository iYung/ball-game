-- Editor export and import: Copy text, the Test table and Paste describe the same tiles.
local runner      = require("lua/headless/runner")
local OpTiles     = require("lua/game/op_tiles")
local EditorScene = require("lua/game/scenes/editor_scene")

local function new_editor()
    local ctx = runner.setup(function(_, sm) return EditorScene.new(sm) end)
    runner.tick(ctx.input, ctx.sm, 1)
    return ctx.sm.current
end

local function same(got, want, msg)
    if type(want) ~= "table" then
        assert(got == want, msg .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
        return
    end
    assert(type(got) == "table", msg .. ": expected a table, got " .. tostring(got))
    for k, v in pairs(want) do same(got[k], v, msg .. "." .. tostring(k)) end
    for k in pairs(got) do
        assert(want[k] ~= nil, msg .. ": unexpected key " .. tostring(k))
    end
end

local function entry_at(def, x, y)
    for _, e in ipairs(def.locked or {}) do
        if e.x == x and e.y == y then return e end
    end
end

local ALL_OPS = {
    "transpose", "scale_row", "swap_rows", "negate", "scalar_mul", "add_matrix",
    "sub_matrix", "mul_matrix", "set_row", "add_rows", "scale_col", "swap_cols",
    "add_cols", "set_col", "rotate_90", "flip_h", "flip_v", "abs",
}

-- Edited params and values: negative and out of range, never equal to a default
local function edit(tile)
    local n = 0
    local keys = {}
    for k in pairs(tile.params) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        n = n + 1
        tile.params[k] = (n % 2 == 1) and -(n + 2) or (n + 20)
    end
    for r, row in ipairs(tile.values or {}) do
        for c in ipairs(row) do
            row[c] = ((r + c) % 2 == 0) and -(10 * r + c) or (10 * r + c)
        end
    end
end

local function check_round_trip(scene, label)
    local def  = scene:_build_def()
    local text = scene:_serialize()
    local chunk = assert(load(text), label .. ": text does not parse:\n" .. text)
    same(chunk(), def, label .. " text vs def")

    local other = new_editor()
    other:_load_def(chunk())
    same(other:_build_def(), def, label .. " reload")
    assert(other:_serialize() == text, label .. ": second export differs")
    return def, text
end

-- Every op, resized to each end of its range, with edited params and values
for _, op in ipairs(ALL_OPS) do
    for _, direction in ipairs({ "none", "grow", "shrink" }) do
        local s = new_editor()
        local tile = OpTiles.new_tile(op, 2)
        if direction ~= "none" then
            local again = true
            while again do
                again = false
                for _, action in ipairs(OpTiles.resize_actions(tile)) do
                    if action:sub(1, #direction) == direction then
                        again = OpTiles.resize(tile, action) or again
                    end
                end
            end
        end
        edit(tile)
        s._grid:set_multi_2d(3, 3, tile, tile.width, tile.height)
        s._grid:set_multi_2d(8, 1, { kind="source", locked=true, width=2, height=2 }, 2, 2)
        s._source = { x=8, y=1 }
        s._grid:set(9, 9, { kind="sink", locked=true })
        s._sink = { x=9, y=9 }

        local label = op .. " " .. direction
        local def = check_round_trip(s, label)
        local e = entry_at(def, 3, 3)
        assert(e and e.op == op, label .. ": entry exported")
        same(e.params, next(tile.params) and tile.params or nil, label .. " params")
        same(e.values, tile.values, label .. " values")
        assert(e.tile_rows == tile.tile_rows and e.tile_cols == tile.tile_cols, label .. " sizes")
        assert((e.width or 1) == tile.width and (e.height or 1) == tile.height,
            label .. " footprint")
    end
end
print("PASS: editor round trip for every op")

-- A whole puzzle: several tiles, pushers, gaps, op allowlist, name and matrices
do
    local s = new_editor()
    local matrix = OpTiles.new_tile("add_matrix", 2)
    OpTiles.resize(matrix, "grow_col")
    OpTiles.resize(matrix, "grow_row")
    matrix.values = { { -9, 12 }, { 0, -30 } }
    s._grid:set_multi_2d(1, 5, matrix, 2, 2)
    s._grid:set(5, 5, { kind="pusher", locked=true, id=3 })
    s._grid:set(6, 5, { kind="gap", locked=true })
    s._grid:set_multi_2d(1, 1, { kind="source", locked=true, width=2, height=2 }, 2, 2)
    s._source = { x=1, y=1 }
    s._grid:set(10, 9, { kind="sink", locked=true })
    s._sink = { x=10, y=9 }
    s._allowed_ops = { negate=true, abs=true }
    s._name = 'Say "hi"'
    s._input.values = { { -1, 2 }, { 3, -4 } }
    local def, text = check_round_trip(s, "puzzle")
    assert(#def.locked == 2 and #def.gaps == 1 and #def.ops == 2, "puzzle contents")
    assert(text:find("values={ {-9,12}, {0,-30} }", 1, true), "nested values: " .. text)
    print("PASS: editor round trip for a whole puzzle")

    -- A built def is a copy of the grid
    local e = entry_at(def, 1, 5)
    e.values[1][1] = 77
    e.params = { scalar=77 }
    def.input.values[1][1] = 77
    assert(matrix.values[1][1] == -9, "tile values untouched")
    assert(next(matrix.params) == nil, "tile params untouched")
    assert(s._input.values[1][1] == -1, "input values untouched")

    local scalar = OpTiles.new_tile("scalar_mul", 2)
    s._grid:set_multi_2d(1, 8, scalar, 2, 1)
    local built = s:_build_def()
    entry_at(built, 1, 8).params.scalar = 77
    assert(scalar.params.scalar == 2, "tile params are copied")

    -- Loading copies too: the grid does not share tables with the pasted def
    local source_def = s:_build_def()
    local other = new_editor()
    other:_load_def(source_def)
    entry_at(source_def, 1, 5).values[1][1] = 55
    entry_at(source_def, 1, 8).params.scalar = 55
    assert(other._grid:get(1, 5).values[1][1] == -9, "loaded values are copied")
    assert(other._grid:get(1, 8).params.scalar == 2, "loaded params are copied")
    print("PASS: editor defs do not share tables")
end

-- Without a placed source or sink, Copy and Test use the same default positions, and a
-- tile on one of those cells survives Paste
do
    local s = new_editor()
    local def = check_round_trip(s, "empty editor")
    assert(def.source.x == 1 and def.source.y == 1, "default source")
    assert(def.sink.x == 10 and def.sink.y == 10, "default sink")

    s._grid:set_multi_2d(1, 1, OpTiles.new_tile("scalar_mul", 2), 2, 1)
    s._grid:set(10, 10, OpTiles.new_tile("negate", 2))
    local covered = check_round_trip(s, "tiles on default positions")
    assert(entry_at(covered, 1, 1).op == "scalar_mul", "tile on the default source cell")
    assert(entry_at(covered, 10, 10).op == "negate", "tile on the default sink cell")
    print("PASS: editor default source and sink")
end

-- Older text without values, sizes or footprints loads with the runtime fills
do
    local s = new_editor()
    s:_load_def(load([[return {
    source = { x=1, y=1 },
    sink   = { x=10, y=10 },
    locked = {
        { kind="op", op="mul_matrix", x=4, y=1 },
        { kind="op", op="set_col",    x=5, y=1 },
        { kind="op", op="scale_col",  x=1, y=4 },
        { kind="op", op="scale_row",  x=6, y=1 },
        { kind="op", op="add_rows",   x=1, y=6 },
    },
    input  = { rows=2, cols=2, values={ {1,0},{0,1} } },
    target = { rows=2, cols=2, values={ {1,0},{0,1} } },
}]])())
    local def = check_round_trip(s, "older text")
    local mul = entry_at(def, 4, 1)
    same(mul.values, { { 0 } }, "mul_matrix fills 0")
    assert(mul.tile_rows == 1 and mul.tile_cols == 1 and not mul.width, "mul_matrix size")
    local col = entry_at(def, 5, 1)
    assert(col.tile_rows == 1 and col.height == 2, "set_col size")
    same(col.params, { col=1 }, "set_col params")
    assert(entry_at(def, 1, 4).width == 4, "scale_col footprint")
    assert(entry_at(def, 6, 1).height == 4, "scale_row footprint")
    same(entry_at(def, 1, 6).params, { src=1, dst=2, scalar=1 }, "add_rows params")
    print("PASS: editor loads older text")
end

-- A tile whose footprint would cover an earlier tile or leave the grid is skipped
do
    local s = new_editor()
    s:_load_def({
        source = { x=1, y=1 }, sink = { x=3, y=5 },
        locked = {
            { kind="op", op="negate",     x=3, y=5 },
            { kind="op", op="add_matrix", x=2, y=5, tile_cols=2 },  -- covers the negate
            { kind="op", op="add_matrix", x=10, y=8, tile_cols=2 }, -- off the grid
        },
        gaps   = { { x=3, y=5 }, { x=11, y=1 } },
        input  = { rows=1, cols=1, values={ {1} } },
        target = { rows=1, cols=1, values={ {1} } },
    })
    assert(s._grid:get(3, 5).op == "negate", "earlier tile intact")
    assert(s._grid:get(2, 5) == nil and s._grid:get(10, 8) == nil, "misfits skipped")
    assert(s._sink == nil, "sink does not overwrite a tile")
    print("PASS: editor import never overlaps")
end

-- The shipped puzzle files paste with every locked tile, gap, source and sink in place
do
    local PuzzleLoader = require("lua/game/puzzle_loader")
    for n = 1, PuzzleLoader.count() do
        local puzzle = PuzzleLoader.load(n)
        local s = new_editor()
        s:_load_def(puzzle)
        local def = check_round_trip(s, "puzzle " .. n)
        assert(s._source and s._sink, "puzzle " .. n .. ": source and sink placed")
        assert(#(def.gaps or {}) == #(puzzle.gaps or {}), "puzzle " .. n .. ": gaps")
        assert(#(def.locked or {}) == #(puzzle.locked or {}), "puzzle " .. n .. ": locked")
        for _, want in ipairs(puzzle.locked or {}) do
            local got = entry_at(def, want.x, want.y)
            assert(got and got.kind == want.kind and got.op == want.op, "puzzle " .. n .. ": entry")
            same(got.params, want.params, "puzzle " .. n .. " params")
            assert(got.tile_rows == want.tile_rows, "puzzle " .. n .. " tile_rows")
        end
    end

    local file = assert(love.filesystem.load("data/puzzles/23_locked_scale.lua"))()
    local s = new_editor()
    s:_load_def(file)
    local tile = s._grid:get(5, 3)
    assert(tile.tile_rows == 1 and tile.width == 1 and tile.height == 1, "footprint from tile_rows=1")
    assert(s._grid:get(5, 4).kind == "gap", "the cell below keeps its gap")
    print("PASS: editor loads the shipped puzzles")
end
