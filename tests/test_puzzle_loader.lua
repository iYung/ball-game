-- test_puzzle_loader.lua
-- Covers PuzzleLoader error paths: out-of-range indices and failed filesystem.load.

local PuzzleLoader = require("lua/game/puzzle_loader")

-- ── load: out-of-range indices ───────────────────────────────────────────────

local ok, err = pcall(PuzzleLoader.load, 0)
assert(not ok, "load(0) should error")
assert(err:find("out of range"), "load(0) error mentions out of range: " .. tostring(err))
print("PASS: load(0) out-of-range error")

ok, err = pcall(PuzzleLoader.load, 999)
assert(not ok, "load(999) should error")
assert(err:find("out of range"), "load(999) error mentions out of range: " .. tostring(err))
print("PASS: load(999) out-of-range error")

-- ── world: out-of-range indices ──────────────────────────────────────────────

ok, err = pcall(PuzzleLoader.world, 0)
assert(not ok, "world(0) should error")
assert(err:find("out of range"), "world(0) error mentions out of range: " .. tostring(err))
print("PASS: world(0) out-of-range error")

ok, err = pcall(PuzzleLoader.world, 999)
assert(not ok, "world(999) should error")
assert(err:find("out of range"), "world(999) error mentions out of range: " .. tostring(err))
print("PASS: world(999) out-of-range error")

-- ── load: failed filesystem.load ────────────────────────────────────────────
-- Stub love.filesystem.load to return nil so the "could not load" branch fires.

local orig_fs_load = love.filesystem.load
love.filesystem.load = function(path) return nil, "injected error" end

ok, err = pcall(PuzzleLoader.load, 1)
assert(not ok, "load(1) with stubbed filesystem should error")
assert(err:find("could not load"), "error mentions 'could not load': " .. tostring(err))
assert(err:find("injected error"), "error includes filesystem message: " .. tostring(err))
print("PASS: load with failed filesystem.load hits 'could not load' branch")

love.filesystem.load = orig_fs_load

print("ALL PUZZLE LOADER TESTS PASSED")
