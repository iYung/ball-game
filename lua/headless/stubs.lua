-- lua/headless/stubs.lua
-- Installs no-op replacements into the `love` global before any game module
-- loads. Required when running with --headless (love.graphics is nil).

local noop = function() end

-- Stub image returned by any love.graphics.new*() call.
local function make_stub_image()
  return {
    getWidth      = function() return 120 end,
    getHeight     = function() return 120 end,
    getDimensions = function() return 120, 120 end,
    setFilter     = noop,
  }
end

-- Build the graphics stub table with explicit stubs first, then a catch-all
-- __index metatable that returns a no-op (or a new*-style factory) for any
-- unknown key.
local graphics_stub = {}

-- Explicit stubs ---------------------------------------------------------
graphics_stub.setDefaultFilter = noop
graphics_stub.setCanvas        = noop
graphics_stub.setColor         = noop
graphics_stub.setShader        = noop
graphics_stub.setBlendMode     = noop
graphics_stub.setFilter        = noop
graphics_stub.draw             = noop
graphics_stub.rectangle        = noop
graphics_stub.print            = noop
graphics_stub.printf           = noop
graphics_stub.push             = noop
graphics_stub.pop              = noop
graphics_stub.translate        = noop
graphics_stub.scale            = noop
graphics_stub.clear            = noop
graphics_stub.getFont          = function() return {} end

-- Global screen dimension query (not the stub-image version).
graphics_stub.getDimensions = function() return 1280, 720 end

-- Catch-all: any unknown key returns a no-op, except new* returns a factory.
setmetatable(graphics_stub, {
  __index = function(_, key)
    if type(key) == "string" and key:sub(1, 3) == "new" then
      return make_stub_image
    end
    return noop
  end,
})

-- Install stubs into the love global ------------------------------------
love.graphics = graphics_stub

love.keyboard = love.keyboard or {}
love.keyboard.isDown = function() return false end

love.window = love.window or {}
love.window.getFullscreen = function() return false end
love.window.setFullscreen = function() end

love.filesystem = love.filesystem or {}
love.filesystem.getInfo = function() return nil end

love.audio = love.audio or {}

-- Stub source object returned by newSource.
local function make_stub_source()
  local src = {}
  src.clone      = function() return make_stub_source() end
  src.setLooping = noop
  src.setVolume  = noop
  src.setPitch   = noop
  src.play       = noop
  src.stop       = noop
  src.isPlaying  = function() return false end
  return src
end

love.audio.newSource  = function(path, type) return make_stub_source() end
love.audio.play       = noop
