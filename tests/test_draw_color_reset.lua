-- MatrixScene:draw must leave the draw color white; main.lua composites the
-- scene canvas with the current color, so a leaked color tints the whole screen.
local runner = require("lua/headless/runner")

local last
local orig = love.graphics.setColor
love.graphics.setColor = function(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    last = { r, g, b, a or 1 }
end

local function assert_white(label)
    assert(last and last[1] == 1 and last[2] == 1 and last[3] == 1 and last[4] == 1,
        label .. ": draw ended with color " .. (last and table.concat(last, ",") or "nil"))
end

local ctx   = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
local scene = ctx.sm.current

scene:draw()
assert_white("no pusher placed")

scene:_place_tile_at(5, 1, { kind = "pusher" })
scene:draw()
assert_white("pusher placed")

love.graphics.setColor = orig
print("PASS: MatrixScene:draw leaves the draw color white")
