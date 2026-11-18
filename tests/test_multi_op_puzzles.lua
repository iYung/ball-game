local Matrix = require("game/matrix_math")

local function m(rows, cols, values)
    return Matrix.new(rows, cols, values)
end

local function assert_eq(a, b, msg)
    assert(a:equals(b), msg or "matrix mismatch")
end

-- Puzzle 12: "Negate & Swap"
-- negate → swap_rows(1,2)
do
    local input  = m(2, 2, {{1,2},{3,4}})
    local target = m(2, 2, {{-3,-4},{-1,-2}})
    local result = input:negate():swap_rows(1, 2)
    assert_eq(result, target, "puzzle 12: negate then swap_rows")
    -- verify order matters: same result with swap-then-negate (commutative here)
    local result2 = input:swap_rows(1, 2):negate()
    assert_eq(result2, target, "puzzle 12: swap_rows then negate (same result)")
    print("PASS: puzzle 12 - Negate & Swap")
end

-- Puzzle 13: "Flip & Scale"
-- transpose → scale_row(2, -1)
do
    local input  = m(2, 2, {{1,2},{3,4}})
    local target = m(2, 2, {{1,3},{-2,-4}})
    local result = input:transpose():scale_row(2, -1)
    assert_eq(result, target, "puzzle 13: transpose then scale_row")
    -- verify single-op paths don't reach target
    assert(not input:transpose():equals(target),  "puzzle 13: transpose alone is insufficient")
    assert(not input:scale_row(2, -1):equals(target), "puzzle 13: scale_row alone is insufficient")
    print("PASS: puzzle 13 - Flip & Scale")
end

-- Puzzle 14: "Elimination"
-- scale_row(1, 0.5) → add_rows(1, 2, -4)
do
    local input  = m(3, 3, {{2,0,0},{4,1,0},{0,0,1}})
    local target = m(3, 3, {{1,0,0},{0,1,0},{0,0,1}})
    local result = input:scale_row(1, 0.5):add_rows(1, 2, -4)
    assert_eq(result, target, "puzzle 14: scale_row then add_rows")
    -- verify single-op paths don't reach target
    assert(not input:scale_row(1, 0.5):equals(target), "puzzle 14: scale_row alone is insufficient")
    assert(not input:add_rows(1, 2, -4):equals(target), "puzzle 14: add_rows alone is insufficient")
    print("PASS: puzzle 14 - Elimination")
end

-- Puzzle 15: "Scale & Swap"
-- swap_rows(1, 3) → scale_row(3, -1)
do
    local input  = m(3, 3, {{1,2,3},{0,0,0},{7,8,9}})
    local target = m(3, 3, {{7,8,9},{0,0,0},{-1,-2,-3}})
    local result = input:swap_rows(1, 3):scale_row(3, -1)
    assert_eq(result, target, "puzzle 15: swap_rows then scale_row")
    -- verify single-op paths don't reach target
    assert(not input:swap_rows(1, 3):equals(target),  "puzzle 15: swap_rows alone is insufficient")
    assert(not input:scale_row(3, -1):equals(target), "puzzle 15: scale_row alone is insufficient")
    print("PASS: puzzle 15 - Scale & Swap")
end

-- Puzzle 16: "Triple Threat"
-- transpose → negate → scale_row(1, 2)
do
    local input  = m(2, 2, {{1,2},{3,4}})
    local target = m(2, 2, {{-2,-6},{-2,-4}})
    local result = input:transpose():negate():scale_row(1, 2)
    assert_eq(result, target, "puzzle 16: transpose then negate then scale_row")
    -- verify two-op paths don't reach target
    assert(not input:transpose():negate():equals(target),    "puzzle 16: transpose+negate alone is insufficient")
    assert(not input:transpose():scale_row(1, 2):equals(target), "puzzle 16: transpose+scale_row alone is insufficient")
    assert(not input:negate():scale_row(1, 2):equals(target),    "puzzle 16: negate+scale_row alone is insufficient")
    print("PASS: puzzle 16 - Triple Threat")
end

print("ALL MULTI-OP PUZZLE TESTS PASSED")
