local Drawer = require("lua/core/drawer")
local Camera = require("lua/core/camera")

local Scene = {}
Scene.__index = Scene

function Scene.new(w, h)
    local self  = setmetatable({}, Scene)
    self.drawer = Drawer.new()
    self.camera = Camera.new(0, 0, w, h)
    return self
end

function Scene:update(dt) end

function Scene:draw()
    self.camera:attach()
    self.drawer:draw()
    self.camera:detach()
end

function Scene:on_enter() end

function Scene:on_exit()
    self.drawer:clear()
end

return Scene
