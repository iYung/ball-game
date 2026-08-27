local Input = {}
Input.__index = Input

function Input.new(key_map)
    local self    = setmetatable({}, Input)
    self._map     = key_map
    self._down    = {}
    self._pressed = {}
    return self
end

function Input:update()
    local new_pressed = {}
    for action, keys in pairs(self._map) do
        local down = false
        for _, key in ipairs(keys) do
            if love.keyboard.isDown(key) then
                down = true
                break
            end
        end
        if down and not self._down[action] then
            new_pressed[action] = true
        end
        self._down[action] = down
    end
    self._pressed = new_pressed
end

function Input:is_down(action)
    return self._down[action] == true
end

function Input:pressed(action)
    return self._pressed[action] == true
end

return Input
