-- The idle input-matrix preview must stay hidden until a pusher is placed.
local runner = require("lua/headless/runner")
local Stubs  = require("lua/headless/stubs")
local Matrix = require("lua/game/matrix_math")

local function drawn_preview(scene)
    Stubs.clear_text()
    scene:draw_travelling_matrix()
    for _, t in ipairs(Stubs.drawn_text()) do
        if t == "0.5" then return true end
    end
    return false
end

local ctx   = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
local scene = ctx.sm.current
scene.input_matrix = Matrix.new(1, 1, {{0.5}})

assert(not drawn_preview(scene), "preview drawn before any pusher was placed")
scene:_place_tile_at(5, 1, { kind = "pusher" })
assert(drawn_preview(scene), "preview missing after a pusher was placed")
print("PASS: idle preview hidden until a pusher is placed")
