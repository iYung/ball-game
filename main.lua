local _visual_test = nil
local _visual_mode = false
local _visual_co   = nil
local _runner      = nil
do
    local headless, visual, coverage, test_file = false, false, false, nil
    for _, v in ipairs(arg or {}) do
        if     v == "--headless"  then headless  = true
        elseif v == "--visual"    then visual    = true
        elseif v == "--coverage"  then coverage  = true
        elseif (headless or visual) and not test_file and v:sub(1, 1) ~= "-" then
            test_file = v
        end
    end
    if headless then
        require("lua/headless/stubs")
        local cov
        if coverage then
            cov = require("lua/headless/coverage")
            cov.start()
            local orig_quit = love.event.quit
            love.event.quit = function(code)
                cov.report()
                orig_quit(code)
            end
        end
        require("lua/headless/runner").run(test_file)
        return
    end
    if visual then
        _visual_test = test_file
        _visual_mode = true
    end
end

love.graphics.setDefaultFilter("nearest", "nearest")

local SceneManager   = require("lua/core/scene_manager")
local StartScene     = require("lua/game/scenes/start_scene")
local SettingsState  = require("lua/game/settings_state")
local Save           = require("lua/core/save")

local LOGICAL_W, LOGICAL_H = 1280, 720
local canvas

local manager

function love.load()
    love.window.setIcon(love.image.newImageData("assets/images/icon.png"))

    canvas = love.graphics.newCanvas(LOGICAL_W, LOGICAL_H)
    canvas:setFilter("nearest", "nearest")

    if _visual_mode then
        if _visual_test == nil then
            print("FAIL: --visual requires a test file path")
            love.event.quit(1)
            return
        end
        if _visual_test:sub(1, 9) == "tests/ui/" then
            print("FAIL: --visual does not work with UI specs; use --headless for those")
            love.event.quit(1)
            return
        end
        _runner = require("lua/headless/runner")
        _runner._visual = true
        _visual_co = coroutine.create(function()
            local ok, err = pcall(dofile, _visual_test)
            if ok then
                print("PASS")
                love.event.quit(0)
            else
                print("FAIL: " .. tostring(err))
                love.event.quit(1)
            end
        end)
        return
    end

    local settings_state = SettingsState.from_save(Save.read_settings())

    manager = SceneManager.new(LOGICAL_W, LOGICAL_H)
    manager:switch(StartScene.new(manager, settings_state))
end

function love.update(dt)
    if _visual_co then
        local ok, err = coroutine.resume(_visual_co)
        if not ok then
            print("FAIL: " .. tostring(err))
            love.event.quit(1)
        end
        return
    end
    manager:update(dt)
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0)
    if _runner and _runner._active_sm then
        _runner._active_sm:draw()
    elseif manager then
        manager:draw()
    end
    love.graphics.setCanvas()

    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

function love.keypressed(key)
    manager:key_pressed(key)
end

function love.mousepressed(x, y, btn)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    local lx = (x - ox) / scale
    local ly = (y - oy) / scale
    manager:mouse_pressed(lx, ly, btn)
end

function love.mousemoved(x, y)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    local lx = (x - ox) / scale
    local ly = (y - oy) / scale
    manager:mouse_moved(lx, ly)
end

function love.mousereleased(x, y, btn)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    local lx = (x - ox) / scale
    local ly = (y - oy) / scale
    manager:mouse_released(lx, ly, btn)
end

function love.textinput(text)
    manager:text_input(text)
end
