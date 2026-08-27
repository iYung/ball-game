-- Regression test: switching from one LevelScene to the next must not error.
-- SceneManager calls the outgoing scene's :on_exit() once its fade-out
-- completes; LevelScene's metatable wasn't chained to Scene, so on_exit
-- (defined only on Scene) resolved to nil and crashed on the first real
-- level transition — never caught before because the placeholder demo this
-- was built from only ever called sm:switch() once, at boot.

local runner = require("lua/headless/runner")

local ctx = runner.setup(function(input, sm)
    return require("game/scenes/level_scene").new(1, nil, sm)
end)

-- Drop the player right at level 1's exit gap, facing out, with enough speed
-- to cross the boundary on the next tick.
local scene = ctx.sm.current
scene.player.x = 640
scene.player.y = 5
scene.player.heading = -math.pi / 2
scene.player.speed = 300

-- One tick crosses out of bounds and starts the scene switch/fade.
runner.tick(ctx.input, ctx.sm, 1, 1 / 60)

-- The fade-out lasts 0.3s; keep ticking past it so on_exit actually fires.
runner.tick(ctx.input, ctx.sm, 30, 1 / 60)

assert(ctx.sm.current ~= nil, "sm.current should not be nil after a level transition")
assert(ctx.sm.current.level_id == 2, "should have switched to level 2, got " .. tostring(ctx.sm.current.level_id))
print("PASS: level_transition: switching levels calls on_exit without error")

print("ALL TESTS PASSED")
