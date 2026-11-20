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

print("ALL TESTS PASSED")
