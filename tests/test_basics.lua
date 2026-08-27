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
    return require("game/scenes/game_scene").new()
end)

runner.tick(ctx.input, ctx.sm, 10)

assert(ctx.sm.current ~= nil, "sm.current should not be nil after tick")
print("PASS: scene ticks without error")

print("ALL TESTS PASSED")
