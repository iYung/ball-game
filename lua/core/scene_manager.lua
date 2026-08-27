local SceneManager = {}
SceneManager.__index = SceneManager

local FADE_DURATION = 0.3

function SceneManager.new(w, h)
    local self        = setmetatable({}, SceneManager)
    self._w           = w or 1280
    self._h           = h or 720
    self.current      = nil
    self._prev        = nil   -- old scene drawn during fade-out
    self._fade_state  = "idle"
    self._fade_alpha  = 0
    return self
end

function SceneManager:switch(scene)
    if not self.current then
        -- First load: no fade
        self.current = scene
        if self.current then self.current:on_enter() end
    else
        -- Keep old scene for drawing during fade-out; swap logic immediately
        self._prev       = self.current
        self.current     = scene
        if self.current then self.current:on_enter() end
        self._fade_state = "out"
        self._fade_alpha = 0
    end
end

function SceneManager:update(dt)
    if self.current then self.current:update(dt) end

    if self._fade_state == "out" then
        self._fade_alpha = self._fade_alpha + dt / FADE_DURATION
        if self._fade_alpha >= 1 then
            self._fade_alpha = 1
            if self._prev then
                self._prev:on_exit()
                self._prev = nil
            end
            self._fade_state = "in"
        end
    elseif self._fade_state == "in" then
        self._fade_alpha = self._fade_alpha - dt / FADE_DURATION
        if self._fade_alpha <= 0 then
            self._fade_alpha = 0
            self._fade_state = "idle"
        end
    end
end

function SceneManager:draw()
    -- During fade-out draw the old scene so it appears to darken
    local scene = (self._fade_state == "out" and self._prev) or self.current
    if scene then scene:draw() end

    if self._fade_alpha > 0 then
        love.graphics.setColor(0, 0, 0, self._fade_alpha)
        love.graphics.rectangle("fill", 0, 0, self._w, self._h)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return SceneManager
