local _visual_test = nil
local _visual_mode = false
do
    local headless, visual, test_file = false, false, nil
    for _, v in ipairs(arg or {}) do
        if     v == "--headless" then headless = true
        elseif v == "--visual"   then visual   = true
        elseif (headless or visual) and not test_file and v:sub(1, 1) ~= "-" then
            test_file = v
        end
    end
    if headless then
        require("lua/headless/stubs")
        require("lua/headless/runner").run(test_file)
        return
    end
    if visual then
        _visual_test = test_file
        _visual_mode = true
    end
end

love.graphics.setDefaultFilter("nearest", "nearest")

local SceneManager = require("lua/core/scene_manager")
local SubwayScene  = require("game/scenes/subway_scene")

local LOGICAL_W, LOGICAL_H = 1280, 720
local canvas

local manager

function love.load()
    love.window.setIcon(love.image.newImageData("assets/images/icon.png"))

    canvas = love.graphics.newCanvas(LOGICAL_W, LOGICAL_H)
    canvas:setFilter("nearest", "nearest")

    manager = SceneManager.new(LOGICAL_W, LOGICAL_H)
    manager:switch(SubwayScene.new())
end

function love.update(dt)
    manager:update(dt)
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0)
    manager:draw()
    love.graphics.setCanvas()

    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if manager.current and manager.current.keypressed then
        manager.current:keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    -- Convert from window coords to logical canvas coords
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth()  - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    local lx = (x - ox) / scale
    local ly = (y - oy) / scale
    if manager.current and manager.current.mousepressed then
        manager.current:mousepressed(lx, ly, button)
    end
end

function love.mousereleased(x, y, button)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth()  - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    local lx = (x - ox) / scale
    local ly = (y - oy) / scale
    if manager.current and manager.current.mousereleased then
        manager.current:mousereleased(lx, ly, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth()  - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    local lx  = (x  - ox) / scale
    local ly  = (y  - oy) / scale
    local ldx = dx / scale
    local ldy = dy / scale
    if manager.current and manager.current.mousemoved then
        manager.current:mousemoved(lx, ly, ldx, ldy)
    end
end

function love.wheelmoved(x, y)
    if manager.current and manager.current.wheelmoved then
        manager.current:wheelmoved(x, y)
    end
end
