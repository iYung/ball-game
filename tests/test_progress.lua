-- test_progress.lua
-- Tests for game/progress.lua: mark_solved, is_solved, is_world_unlocked,
-- unlock_all, reset.

local S = require("tests/support/shipped")
local Progress     = require("lua/game/progress")
local PuzzleLoader = require("lua/game/puzzle_loader")

-- Always start clean so test order doesn't matter.
Progress.reset()

-- ── is_solved / mark_solved ───────────────────────────────────────────────────

assert(not Progress.is_solved(1), "puzzle 1 not solved after reset")
Progress.mark_solved(1)
assert(Progress.is_solved(1), "puzzle 1 solved after mark_solved")
assert(not Progress.is_solved(2), "puzzle 2 still not solved")
print("PASS: mark_solved / is_solved")

-- mark_solved is idempotent
Progress.mark_solved(1)
assert(Progress.is_solved(1), "idempotent mark_solved still solved")
print("PASS: mark_solved idempotent")

-- ── is_world_unlocked ─────────────────────────────────────────────────────────

Progress.reset()

-- World 1 is always unlocked, even with no progress.
assert(Progress.is_world_unlocked(1), "world 1 always unlocked")
print("PASS: world 1 always unlocked")

-- World 2 locked when world 1 is incomplete.
assert(not Progress.is_world_unlocked(2), "world 2 locked with no progress")
print("PASS: world 2 locked with no progress")

-- Solve all world-1 puzzles; world 2 should unlock.
local world1 = PuzzleLoader.world(1)
for _, p in ipairs(world1.puzzles) do
    Progress.mark_solved(p.index)
end
assert(Progress.is_world_unlocked(2), "world 2 unlocked after completing world 1")
assert(not Progress.is_world_unlocked(3), "world 3 still locked (world 2 not done)")
print("PASS: world 2 unlocked after world 1 complete; world 3 still locked")

-- Solve world 2; world 3 should unlock.
local world2 = PuzzleLoader.world(2)
for _, p in ipairs(world2.puzzles) do
    Progress.mark_solved(p.index)
end
assert(Progress.is_world_unlocked(3), "world 3 unlocked after completing worlds 1 and 2")
print("PASS: world 3 unlocked after worlds 1+2 complete")

-- ── unlock_all ────────────────────────────────────────────────────────────────

Progress.reset()
assert(not Progress.is_world_unlocked(2), "world 2 locked after reset")
Progress.unlock_all()
for w = 1, PuzzleLoader.world_count() do
    assert(Progress.is_world_unlocked(w),
        string.format("world %d unlocked after unlock_all", w))
end
for n = 1, PuzzleLoader.count() do
    assert(Progress.is_solved(n),
        string.format("puzzle %d solved after unlock_all", n))
end
print("PASS: unlock_all marks all worlds and puzzles solved")

-- ── reset ─────────────────────────────────────────────────────────────────────

Progress.reset()
for n = 1, PuzzleLoader.count() do
    assert(not Progress.is_solved(n),
        string.format("puzzle %d not solved after reset", n))
end
assert(not Progress.is_world_unlocked(2), "world 2 locked after reset")
print("PASS: reset clears all progress")

-- ── is_cutscene_seen / mark_cutscene_seen ────────────────────────────────────

Progress.reset()

-- Unseen by default after reset.
assert(not Progress.is_cutscene_seen(2), "world 2 cutscene not seen after reset")
assert(not Progress.is_cutscene_seen(3), "world 3 cutscene not seen after reset")
print("PASS: cutscenes unseen after reset")

-- Seen after mark.
Progress.mark_cutscene_seen(2)
assert(Progress.is_cutscene_seen(2), "world 2 cutscene seen after mark")
print("PASS: mark_cutscene_seen sets seen")

-- Other worlds unaffected.
assert(not Progress.is_cutscene_seen(3), "world 3 cutscene still unseen")
print("PASS: mark_cutscene_seen does not affect other worlds")

-- Idempotent: marking twice does not error.
Progress.mark_cutscene_seen(2)
assert(Progress.is_cutscene_seen(2), "world 2 still seen after second mark")
print("PASS: mark_cutscene_seen idempotent")

-- reset clears cutscene state.
Progress.reset()
assert(not Progress.is_cutscene_seen(2), "world 2 cutscene cleared by reset")
print("PASS: reset clears cutscene seen state")

-- ── _load() coverage ─────────────────────────────────────────────────────────

-- _load() new format: {solved={...}, cutscenes={...}}
-- Strategy: save the original cached module, replace with a fresh load for testing,
-- then restore the original so other modules' cached references remain valid.
do
    local orig_read    = love.filesystem.read
    local orig_getInfo = love.filesystem.getInfo
    local orig_module  = package.loaded["lua/game/progress"]

    -- Simulate a save file in new format.
    love.filesystem.read    = function() return "return {solved={10,11},cutscenes={2}}\n" end
    love.filesystem.getInfo = function(path)
        if path == "progress.lua" then return { type = "file", size = 0 } end
        return orig_getInfo(path)
    end

    -- Temporarily replace with a fresh load so _load() runs with our stubs.
    package.loaded["lua/game/progress"] = nil
    local P2 = require("lua/game/progress")

    assert(P2.is_solved(S.puzzle("set_row")), "_load new fmt: puzzle 10 solved")
    assert(P2.is_solved(S.puzzle("rotate_gap")), "_load new fmt: puzzle 11 solved")
    assert(not P2.is_solved(S.puzzle("identity")), "_load new fmt: puzzle 1 not solved")
    assert(P2.is_cutscene_seen(S.world("combos")), "_load new fmt: cutscene 2 seen")
    assert(not P2.is_cutscene_seen(S.world("basics")), "_load new fmt: cutscene 1 not seen")

    love.filesystem.read    = orig_read
    love.filesystem.getInfo = orig_getInfo
    -- Restore original module so other modules' cached references stay valid.
    package.loaded["lua/game/progress"] = orig_module
    orig_module.reset()
    print("PASS: _load() new format")
end

-- _load() old format: plain array {1,2,...}
do
    local orig_read    = love.filesystem.read
    local orig_getInfo = love.filesystem.getInfo
    local orig_module  = package.loaded["lua/game/progress"]

    love.filesystem.read    = function() return "return {2,13}\n" end
    love.filesystem.getInfo = function(path)
        if path == "progress.lua" then return { type = "file", size = 0 } end
        return orig_getInfo(path)
    end

    package.loaded["lua/game/progress"] = nil
    local P2 = require("lua/game/progress")

    assert(P2.is_solved(S.puzzle("flip")), "_load old fmt: puzzle 2 solved")
    assert(P2.is_solved(S.puzzle("flip_scale")), "_load old fmt: puzzle 13 solved")
    assert(not P2.is_solved(S.puzzle("identity")), "_load old fmt: puzzle 1 not solved")
    assert(not P2.is_cutscene_seen(S.world("basics")), "_load old fmt: no cutscene data")

    love.filesystem.read    = orig_read
    love.filesystem.getInfo = orig_getInfo
    package.loaded["lua/game/progress"] = orig_module
    orig_module.reset()
    print("PASS: _load() old format")
end

-- _persist() error branch: write failure is silently ignored.
do
    local orig_write = love.filesystem.write
    love.filesystem.write = function() error("disk full") end

    -- Should not raise.
    local ok = pcall(function() Progress.mark_solved(99) end)
    assert(ok, "_persist() write error must not propagate")

    love.filesystem.write = orig_write
    Progress.reset()
    print("PASS: _persist() silently ignores write failure")
end

print("ALL PROGRESS TESTS PASSED")

-- ── _load() branch coverage ───────────────────────────────────────────────────
-- These tests re-require the module with stubbed filesystem to exercise the
-- _load() body (lines 42–61) which is unreachable in normal headless runs
-- because the save file does not exist on disk.

do
    local orig_getInfo = love.filesystem.getInfo
    local orig_read    = love.filesystem.read

    -- Pretend the save file exists and contains new-format data.
    love.filesystem.getInfo = function(path)
        if path == "progress.lua" then return { type = "file" } end
        return orig_getInfo(path)
    end
    love.filesystem.read = function(path)
        if path == "progress.lua" then
            return "return {solved={1,10},cutscenes={2}}\n"
        end
        return orig_read(path)
    end

    -- Force a fresh require so _load() runs with our stubs.
    package.loaded["lua/game/progress"] = nil
    local P = require("lua/game/progress")

    assert(P.is_solved(S.puzzle("identity")), "_load new-format: puzzle 1 loaded")
    assert(not P.is_solved(S.puzzle("flip")), "_load new-format: puzzle 2 not in save")
    assert(P.is_solved(S.puzzle("set_row")), "_load new-format: puzzle 10 loaded")
    assert(P.is_cutscene_seen(S.world("combos")), "_load new-format: world 2 cutscene loaded")
    assert(not P.is_cutscene_seen(S.world("basics")), "_load new-format: world 1 cutscene not in save")
    print("PASS: _load() new-format save")

    -- Restore stubs and re-load a clean module for subsequent tests.
    love.filesystem.getInfo = orig_getInfo
    love.filesystem.read    = orig_read
    package.loaded["lua/game/progress"] = nil
    require("lua/game/progress")
end

do
    local orig_getInfo = love.filesystem.getInfo
    local orig_read    = love.filesystem.read

    -- Old-format save: plain array, no solved/cutscenes keys.
    love.filesystem.getInfo = function(path)
        if path == "progress.lua" then return { type = "file" } end
        return orig_getInfo(path)
    end
    love.filesystem.read = function(path)
        if path == "progress.lua" then
            return "return {11,13}\n"
        end
        return orig_read(path)
    end

    package.loaded["lua/game/progress"] = nil
    local P = require("lua/game/progress")

    assert(P.is_solved(S.puzzle("rotate_gap")), "_load old-format: puzzle 11 loaded")
    assert(P.is_solved(S.puzzle("flip_scale")), "_load old-format: puzzle 13 loaded")
    assert(not P.is_solved(S.puzzle("identity")), "_load old-format: puzzle 1 not in save")
    print("PASS: _load() old-format save")

    love.filesystem.getInfo = orig_getInfo
    love.filesystem.read    = orig_read
    package.loaded["lua/game/progress"] = nil
    require("lua/game/progress")
end

-- ── _persist() write-error branch (line 36: _ = err) ────────────────────────

do
    -- Fresh module so internal state is clean.
    package.loaded["lua/game/progress"] = nil
    local P = require("lua/game/progress")
    P.reset()

    local orig_write = love.filesystem.write
    love.filesystem.write = function() error("disk full") end

    -- The error must be caught inside _persist(); nothing should escape.
    local ok = pcall(function() P.mark_solved(99) end)
    assert(ok,             "write error must not escape from mark_solved")
    assert(P.is_solved(99), "puzzle 99 still marked solved despite write failure")
    print("PASS: _persist() write-error silently ignored")

    love.filesystem.write = orig_write
    -- Leave module in a clean state.
    P.reset()
    package.loaded["lua/game/progress"] = nil
    require("lua/game/progress")
end

-- Restore the original module object so other modules' cached `require("lua/game/progress")`
-- references remain consistent with what UIRunner's fresh `require()` returns.
package.loaded["lua/game/progress"] = Progress
Progress.reset()

print("ALL PROGRESS LOAD/PERSIST TESTS PASSED")
