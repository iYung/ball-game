-- The Two Sources puzzles built around preparing a matrix before the merge: the
-- intended preparation reaches the target, and doing it elsewhere or not at all misses.

local PuzzleLoader = require("lua/game/puzzle_loader")
local Matrix       = require("lua/game/matrix_math")
local Ops          = require("lua/game/ops")
local S            = require("tests/support/shipped")

local function matrix(m) return Matrix.new(m.rows, m.cols, m.values) end

local function load(id)
    local n = S.puzzle(id)
    local found = false
    for _, i in ipairs(PuzzleLoader.world_indices(S.world("two_sources"))) do
        found = found or i == n
    end
    assert(found, id .. " is in Two Sources")
    local def = PuzzleLoader.load(n)
    return def, matrix(def.input), matrix(def.input2), matrix(def.target)
end

local function add(a, b) return Ops.combine("matrix_add", a, b) end
local function scaled(m, k) return m:scalar_mul(k) end

do
    local _, a, b, target = load("take_away")
    assert(add(a, scaled(b, -1)):equals(target), "target is INPUT 1 - INPUT 2")
    for k = -9, 9 do
        assert(not add(scaled(a, k), b):equals(target), "scaling INPUT 1 misses, k = " .. k)
        assert(not scaled(add(a, b), k):equals(target), "scaling the sum misses, k = " .. k)
    end
    print("PASS: Take Away needs INPUT 2 negated before the sum")
end

do
    local _, a, b, target = load("stand_to_add")
    assert(Ops.merge_error("matrix_add", a, b), "the raw inputs cannot be added")
    assert(add(a, b:transpose()):equals(target), "target is INPUT 1 + T(INPUT 2)")
    assert(not add(a:transpose(), b):transpose():equals(a), "sanity: a merge changes INPUT 1")
    print("PASS: Stand to Add needs a transpose before the sum")
end

do
    local _, a, b, target = load("two_preps")
    local a2, bf = scaled(a, 2), b:flip_h()
    assert(add(a2, bf):equals(target), "target is 2 x INPUT 1 + FLh(INPUT 2)")
    assert(not add(a, bf):equals(target), "skipping the scale misses")
    assert(not add(a2, b):equals(target), "skipping the flip misses")
    for k = -9, 9 do
        assert(not scaled(add(a, b), k):equals(target), "scaling only the sum misses")
        assert(not scaled(add(a, b):flip_h(), k):equals(target), "preparing only the sum misses")
        assert(not add(scaled(a, k), b):flip_h():equals(target), "flipping the sum misses")
    end
    print("PASS: Two Preps needs both preparations before the sum")
end

print("ALL TWO SOURCE PREP DATA TESTS PASSED")
