-- test_basics.lua
-- Minimal example demonstrating the headless test infrastructure.

local runner = require("lua/headless/runner")

-- Test 1: a fresh LevelScene can be ticked without error.
-- scene_factory receives (input, sm) from runner.setup; LevelScene.new takes
-- (level_id, entry, sm), so we start level 1 at its default spawn.
local ctx = runner.setup(function(input, sm)
    return require("game/scenes/level_scene").new(1, nil, sm)
end)

runner.tick(ctx.input, ctx.sm, 10)

assert(ctx.sm.current ~= nil, "sm.current should not be nil after tick")
print("PASS: scene ticks without error")

print("ALL TESTS PASSED")
