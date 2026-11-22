-- test_basics.lua
-- Minimal example demonstrating the headless test infrastructure.
--
-- NOTE: game/player.lua creates its own internal Input instance (it calls
-- love.keyboard.isDown directly rather than accepting an injected Input
-- object), so headless action injection into player movement is not
-- straightforward without refactoring the Player class.  This test therefore
-- limits itself to observable state that does not require controlling the
-- player via HeadlessInput.

local runner = require("lua/headless/runner")

-- Test 1: a fresh GameScene can be ticked without error.
-- scene_factory receives (input, sm) from runner.setup but GameScene.new()
-- takes no arguments; simply ignore the args and return a new scene.
local ctx = runner.setup(function(input, sm)
    return require("lua/game/scenes/matrix_scene").new()
end)

runner.tick(ctx.input, ctx.sm, 10)

assert(ctx.sm.current ~= nil, "sm.current should not be nil after tick")
print("PASS: scene ticks without error")

-- Test: clear skips a locked tile
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(4, 4)
    g:set(2, 2, { kind = "pusher", locked = true })
    g:clear(2, 2)
    assert(g:get(2, 2) ~= nil, "clear: locked tile must not be removed")
    assert(g:get(2, 2).locked == true, "clear: locked tile must remain locked")
    print("PASS: clear skips locked tile")
end

-- Test: clear follows ref cells when tile.width is nil
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(4, 4)
    -- Place anchor at (1,1) without a .width field, then manually place a ref
    -- cell at (2,1) pointing back to (1,1).
    g:set(1, 1, { kind = "op" })   -- no .width
    g:set(2, 1, { ref = true, ax = 1, ay = 1 })
    g:clear(1, 1)
    assert(g.cells[1][1] == nil, "clear: anchor cell must be wiped")
    assert(g.cells[1][2] == nil, "clear: trailing ref cell must also be wiped")
    print("PASS: clear follows ref cells when width is nil")
end

-- Test: clear() locked-tile guard (line 104)
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(3, 3)
    g:set(1, 1, { kind = "tile", locked = true })
    g:clear(1, 1)
    assert(g.cells[1][1] ~= nil, "clear: locked tile must not be removed (line 104)")
    assert(g.cells[1][1].locked == true, "clear: locked tile must remain locked (line 104)")
    print("PASS: clear() locked-tile guard (line 104)")
end

-- Test: clear() rightward-ref scan when width is nil (lines 108-120)
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(4, 4)
    -- Anchor at (2,2) with no .width; manually attach a ref cell to its right
    g:set(2, 2, { kind = "op" })   -- no .width field
    g:set(3, 2, { ref = true, ax = 2, ay = 2 })
    g:clear(2, 2)
    assert(g.cells[2][2] == nil, "clear: anchor cell must be wiped (line 108)")
    assert(g.cells[2][3] == nil, "clear: trailing ref cell must be wiped (lines 108-120)")
    print("PASS: clear() rightward-ref scan when width is nil (lines 108-120)")
end

-- Test: get_anchor() out-of-bounds returns the same coords (line 41)
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(3, 3)
    local rx, ry = g:get_anchor(0, 0)
    assert(rx == 0, "get_anchor: out-of-bounds x should be returned as-is (line 41)")
    assert(ry == 0, "get_anchor: out-of-bounds y should be returned as-is (line 41)")
    print("PASS: get_anchor() out-of-bounds path (line 41)")
end

-- Test: get_anchor() on a ref cell returns the anchor coords (lines 43-44)
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(4, 4)
    g:set(1, 1, { kind = "op", width = 2 })
    g:set(2, 1, { ref = true, ax = 1, ay = 1 })
    local ax, ay = g:get_anchor(2, 1)
    assert(ax == 1, "get_anchor: ref cell must resolve to anchor x (lines 43-44)")
    assert(ay == 1, "get_anchor: ref cell must resolve to anchor y (lines 43-44)")
    print("PASS: get_anchor() ref-cell path (lines 43-44)")
end

-- Test: get_anchor on out-of-bounds coordinate returns the same coords unchanged.
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(4, 4)
    local rx, ry = g:get_anchor(999, 999)
    assert(rx == 999 and ry == 999, "get_anchor: out-of-bounds returns input coords")
    print("PASS: get_anchor returns coords unchanged when out of bounds")
end

-- Test: get_anchor on a ref cell resolves to the anchor.
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(4, 4)
    -- Place a 2-wide tile; the ref cell at (2,1) should resolve back to (1,1).
    g:set_multi_2d(1, 1, { kind = "op" }, 2, 1)
    local ax, ay = g:get_anchor(2, 1)
    assert(ax == 1 and ay == 1, "get_anchor: ref cell resolves to anchor, got " .. ax .. "," .. ay)
    print("PASS: get_anchor resolves ref cell to anchor")
end

-- Test: Grid:set_multi() places anchor + ref cells (covers in_bounds_multi too)
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(5, 5)
    local tile = { kind = "op", op = "negate" }
    g:set_multi(1, 1, tile, 3)
    assert(g.cells[1][1] == tile, "set_multi: anchor at (1,1)")
    assert(g.cells[1][2] and g.cells[1][2].ref, "set_multi: ref cell at (2,1)")
    assert(g.cells[1][2].ax == 1 and g.cells[1][2].ay == 1, "set_multi: ref points to anchor")
    assert(g.cells[1][3] and g.cells[1][3].ref, "set_multi: ref cell at (3,1)")
    print("PASS: Grid:set_multi() places anchor and ref cells")
end

-- Test: Grid:clear_all() removes non-locked tiles, preserves locked ones
do
    local Grid = require("lua/game/grid")
    local g = Grid.new(5, 5)
    g:set(1, 1, { kind = "pusher" })
    g:set(2, 2, { kind = "op", op = "negate" })
    g:set(3, 3, { kind = "pusher", locked = true })
    g:clear_all()
    assert(g:get(1, 1) == nil, "clear_all: removes pusher")
    assert(g:get(2, 2) == nil, "clear_all: removes op tile")
    assert(g:get(3, 3) ~= nil, "clear_all: preserves locked tile")
    print("PASS: Grid:clear_all() removes non-locked tiles")
end

print("ALL TESTS PASSED")
