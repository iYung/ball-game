-- HeadlessInput: a scriptable drop-in replacement for lua/core/input.lua.
-- State is driven by explicit test calls (press/hold/release) rather than
-- love.keyboard.isDown, so it works in a windowless/headless LOVE process.

local HeadlessInput = {}
HeadlessInput.__index = HeadlessInput

function HeadlessInput.new()
    return setmetatable({
        _held    = {},   -- actions held via hold() until release()
        _queued  = {},   -- single-frame presses from press()
        _down    = {},   -- computed each frame: _held ∪ _queued
        _pressed = {},   -- computed each frame: rising edges
    }, HeadlessInput)
end

-- Queue a single-frame press: fires _pressed=true for exactly one frame.
-- Consecutive press() calls on adjacent frames both fire — the key does NOT
-- stay in _down between frames (unlike hold()).
function HeadlessInput:press(action)
    self._queued[action] = true
end

-- Hold action down until release() is called.  is_down() returns true every
-- frame; pressed() never fires (no repeated rising edge).
function HeadlessInput:hold(action)
    self._held[action] = true
end

-- Clear action from both held and queued state.
function HeadlessInput:release(action)
    self._held[action]   = nil
    self._queued[action] = nil
end

-- Advance one frame.  _down is rebuilt from _held + _queued each frame so
-- single-frame presses don't linger and back-to-back press() calls both fire.
function HeadlessInput:update()
    local new_down    = {}
    local new_pressed = {}

    for action in pairs(self._held) do
        new_down[action] = true
    end

    for action in pairs(self._queued) do
        if not new_down[action] then
            new_pressed[action] = true  -- rising edge: not already held
        end
        new_down[action] = true
    end
    self._queued = {}

    self._down    = new_down
    self._pressed = new_pressed
end

-- Returns true if action is currently held down (mirrors Input:is_down).
function HeadlessInput:is_down(action)
    return self._down[action] == true
end

-- Returns true only on the frame the action first went down (mirrors Input:pressed).
function HeadlessInput:pressed(action)
    return self._pressed[action] == true
end

return HeadlessInput
