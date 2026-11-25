-- test_cutscene.lua
-- Unit tests for CutsceneScene error paths in on_enter() and portrait loading.

local S = require("tests/support/shipped")
local CutsceneScene = require("lua/game/scenes/cutscene_scene")

local function mock_sm()
    local switched_to = {}
    return {
        switch      = function(_, s) switched_to[#switched_to + 1] = s end,
        _switched   = switched_to,
    }
end

-- on_enter() with love.filesystem.load returning nil (file not found).
-- Expected: scene switches to _next_scene without crashing.
do
    local orig_load = love.filesystem.load
    love.filesystem.load = function() return nil, "not found" end

    local sm   = mock_sm()
    local next = {}  -- dummy next scene
    local cs   = CutsceneScene.new(S.world("combos"), next, sm)
    local ok, err = pcall(function() cs:on_enter() end)

    love.filesystem.load = orig_load

    assert(ok, "on_enter with nil chunk must not raise: " .. tostring(err))
    assert(#sm._switched == 1, "must switch to next_scene when chunk is nil, got " .. #sm._switched)
    assert(sm._switched[1] == next, "must switch to the provided next_scene")
    print("PASS: cutscene on_enter switches when load returns nil")
end

-- on_enter() with chunk returning a non-table value (bad data).
-- Expected: scene switches to _next_scene without crashing.
do
    local orig_load = love.filesystem.load
    love.filesystem.load = function()
        return function() return "not a table" end  -- chunk returns a string, not a beats table
    end

    local sm   = mock_sm()
    local next = {}
    local cs   = CutsceneScene.new(S.world("combos"), next, sm)
    local ok, err = pcall(function() cs:on_enter() end)

    love.filesystem.load = orig_load

    assert(ok, "on_enter with bad data must not raise: " .. tostring(err))
    assert(#sm._switched == 1, "must switch to next_scene on bad data, got " .. #sm._switched)
    print("PASS: cutscene on_enter switches when chunk returns non-table")
end

-- _get_portrait() when love.filesystem.getInfo reports the file exists:
-- exercises lines 88–92 (loads or caches the image).
do
    local orig_getInfo  = love.filesystem.getInfo
    local orig_newImage = love.graphics.newImage

    -- Pretend the portrait file exists.
    love.filesystem.getInfo = function(path)
        if path:find("portraits/") then
            return { type = "file", size = 1 }
        end
        return orig_getInfo(path)
    end
    -- Return a stub image so pcall(newImage) succeeds.
    love.graphics.newImage = function()
        return { getDimensions = function() return 64, 64 end }
    end

    local cs = CutsceneScene.new(S.world("combos"), {}, mock_sm())
    -- Directly exercise the portrait cache / load path.
    local img = cs:_get_portrait("TEST_SPEAKER")

    love.filesystem.getInfo = orig_getInfo
    love.graphics.newImage  = orig_newImage

    -- Should have cached and returned the stub image (truthy).
    assert(img ~= nil and img ~= false, "_get_portrait must return image when file exists, got " .. tostring(img))
    print("PASS: cutscene _get_portrait loads image when file exists")
end

-- _draw_portrait(): when image exists, draws it (lines 99–107).
do
    local orig_getInfo  = love.filesystem.getInfo
    local orig_newImage = love.graphics.newImage

    love.filesystem.getInfo = function(path)
        if path:find("portraits/") then return { type = "file", size = 1 } end
        return orig_getInfo(path)
    end
    love.graphics.newImage = function()
        return { getDimensions = function() return 64, 64 end }
    end

    local cs = CutsceneScene.new(S.world("combos"), {}, mock_sm())
    cs._fade_alpha = 1  -- ensure drawing happens
    local ok, err = pcall(function() cs:_draw_portrait("TEST_SPEAKER") end)

    love.filesystem.getInfo = orig_getInfo
    love.graphics.newImage  = orig_newImage

    assert(ok, "_draw_portrait with image must not raise: " .. tostring(err))
    print("PASS: cutscene _draw_portrait draws image path without error")
end

print("ALL CUTSCENE TESTS PASSED")
