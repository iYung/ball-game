-- test_cutscene_scene.lua
-- Covers uncovered paths in lua/game/scenes/cutscene_scene.lua:
--   Lines 53-55  (not chunk path in on_enter)
--   Lines 58-61  (bad data returned by chunk in on_enter)
--   Lines 82-94  (_get_portrait with existing / missing / empty-name cases)

local CutsceneScene = require("lua/game/scenes/cutscene_scene")

-- Helper: minimal mock scene_manager that records switch() calls.
local function make_mock_sm()
    local sm = { switched = false, switched_to = nil }
    sm.switch = function(_, scene)
        sm.switched = true
        sm.switched_to = scene
    end
    return sm
end

-- ── Gap 1: love.filesystem.load returns nil (lines 53-55) ───────────────────

local orig_fs_load = love.filesystem.load

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(99, "menu", sm)

    love.filesystem.load = function(_path) return nil, "not found" end
    scene:on_enter()
    love.filesystem.load = orig_fs_load

    assert(sm.switched,          "on_enter(): chunk=nil should call scene_manager:switch")
    assert(sm.switched_to == "menu",
        "on_enter(): should switch to next_scene ('menu'), got: " .. tostring(sm.switched_to))
    print("PASS: on_enter() with nil chunk switches to next_scene")
end

-- ── Gap 2: chunk returns non-table (lines 58-61) ────────────────────────────

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(99, "menu", sm)

    -- chunk runs fine but returns a string, not a table
    love.filesystem.load = function(_path) return function() return "bad" end end
    scene:on_enter()
    love.filesystem.load = orig_fs_load

    assert(sm.switched,
        "on_enter(): chunk returning non-table should call scene_manager:switch")
    assert(sm.switched_to == "menu",
        "on_enter(): should switch to next_scene after bad data, got: " .. tostring(sm.switched_to))
    print("PASS: on_enter() with non-table beats switches to next_scene")
end

-- ── Gap 3a: _get_portrait with empty / nil name (line 83 guard) ─────────────

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(1, "menu", sm)

    local result_nil   = scene:_get_portrait(nil)
    local result_empty = scene:_get_portrait("")
    assert(result_nil   == nil, "_get_portrait(nil) should return nil")
    assert(result_empty == nil, "_get_portrait('') should return nil")
    print("PASS: _get_portrait() returns nil for nil/empty name")
end

-- ── Gap 3b: _get_portrait with existing portrait file (lines 88-91) ─────────

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(1, "menu", sm)

    -- Stub filesystem.getInfo to report the portrait exists.
    local orig_getInfo = love.filesystem.getInfo
    love.filesystem.getInfo = function(path)
        if path == "assets/portraits/alice.png" then
            return { type = "file", size = 0 }
        end
        return orig_getInfo(path)
    end

    -- Stub love.graphics.newImage to return a stub with getDimensions.
    local stub_img = {
        getDimensions = function() return 128, 128 end,
        getWidth      = function() return 128 end,
        getHeight     = function() return 128 end,
        setFilter     = function() end,
    }
    local orig_newImage = love.graphics.newImage
    love.graphics.newImage = function(_path) return stub_img end

    local result = scene:_get_portrait("alice")

    love.filesystem.getInfo = orig_getInfo
    love.graphics.newImage  = orig_newImage

    assert(result ~= nil and result ~= false,
        "_get_portrait('alice') should return the stub image, got: " .. tostring(result))
    assert(result == stub_img,
        "_get_portrait('alice') should return exactly the stub image object")
    print("PASS: _get_portrait() returns image for existing portrait file")
end

-- ── Gap 3c: _get_portrait when file does NOT exist (line 93-94) ─────────────

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(1, "menu", sm)

    -- Stub getInfo to always return nil (no file on disk).
    local orig_getInfo = love.filesystem.getInfo
    love.filesystem.getInfo = function(_path) return nil end

    local result = scene:_get_portrait("nobody")

    love.filesystem.getInfo = orig_getInfo

    assert(result == false,
        "_get_portrait('nobody') should return false when file absent, got: " .. tostring(result))
    print("PASS: _get_portrait() returns false when portrait file absent")
end

-- ── Gap 3d: _get_portrait cache hit ─────────────────────────────────────────

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(1, "menu", sm)

    -- Pre-seed cache with a value.
    local sentinel = { getDimensions = function() return 64, 64 end }
    scene._portrait_cache["bob"] = sentinel

    local result = scene:_get_portrait("bob")
    assert(result == sentinel,
        "_get_portrait() should return cached value directly")
    print("PASS: _get_portrait() returns cached value on second call")
end

-- ── Gap: mouse_pressed btn==1 advances scene (line 204) ─────────────────────

do
    local sm    = make_mock_sm()
    local scene = CutsceneScene.new(1, "menu", sm)
    scene:on_enter()

    local ok, err = pcall(function() scene:mouse_pressed(0, 0, 1) end)
    assert(ok, "mouse_pressed btn=1 must not error: " .. tostring(err))
    print("PASS: CutsceneScene mouse_pressed btn=1 advances scene")
end

print("ALL CUTSCENE SCENE TESTS PASSED")
