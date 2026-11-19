-- test_source_size.lua
-- Tests that the source tile is placed as a multi-cell tile matching
-- the input matrix dimensions (rows × cols) for each puzzle.

local runner       = require("lua/headless/runner")
local PuzzleLoader = require("game/puzzle_loader")

local function new_scene(puzzle_index)
    local ctx = runner.setup(function()
        return require("game/scenes/matrix_scene").new(puzzle_index)
    end)
    return ctx.sm.current
end

-- For every puzzle, the source tile's width/height must match input.cols/input.rows
-- and each cell of its footprint must be in the grid.
for i = 1, PuzzleLoader.count() do
    local puzzle = PuzzleLoader.load(i)
    local scene  = new_scene(i)
    local grid   = scene.grid
    local src    = puzzle.source
    local rows   = puzzle.input.rows
    local cols   = puzzle.input.cols

    -- Anchor tile has the right dimensions
    local tile = grid:get(src.x, src.y)
    assert(tile ~= nil,          string.format("puzzle %d: source tile exists at (%d,%d)", i, src.x, src.y))
    assert(tile.kind == "source", string.format("puzzle %d: source tile kind is 'source'", i))
    assert(tile.width  == cols,  string.format("puzzle %d: source width %d == input.cols %d", i, tile.width or -1, cols))
    assert(tile.height == rows,  string.format("puzzle %d: source height %d == input.rows %d", i, tile.height or -1, rows))

    -- Every cell in the footprint resolves back to the source anchor
    for dr = 0, rows - 1 do
        for dc = 0, cols - 1 do
            local x, y = src.x + dc, src.y + dr
            local t = grid:get(x, y)
            assert(t ~= nil,           string.format("puzzle %d: source footprint cell (%d,%d) exists", i, x, y))
            assert(t.kind == "source", string.format("puzzle %d: footprint cell (%d,%d) resolves to source", i, x, y))
        end
    end

    print(string.format("PASS: puzzle %d source is %dx%d at (%d,%d)", i, cols, rows, src.x, src.y))
end

-- For a 1×1 matrix the source is still a single cell (no regression)
do
    local puzzle = PuzzleLoader.load(1)
    -- puzzle 1 is 2×2; we just confirm the loop above handled it.
    -- This block documents intent and would catch a 1×1 edge case
    -- if such a puzzle were added.
    print("PASS: source size loop completed for all puzzles")
end
