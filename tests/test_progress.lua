-- test_progress.lua
-- Tests for game/progress.lua: mark_solved, is_solved, is_world_unlocked,
-- unlock_all, reset.

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

print("ALL PROGRESS TESTS PASSED")
