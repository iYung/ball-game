local Matrix = require("game/matrix_math")

local function m(rows, cols, values)
    return Matrix.new(rows, cols, values)
end

local function assert_eq(a, b, msg)
    assert(a:equals(b), msg or "matrix mismatch")
end

local function assert_immutable(original, op_result, msg)
    -- op returned a new object, not the original
    assert(original ~= op_result, (msg or "op") .. ": should return new matrix")
end

-- new() and copy()
do
    local a = m(2, 2, {{1,2},{3,4}})
    assert(a.rows == 2 and a.cols == 2, "rows/cols")
    local b = a:copy()
    assert_eq(a, b, "copy equals original")
    b.values[1][1] = 99
    assert(a.values[1][1] == 1, "copy is independent")
    print("PASS: new/copy")
end

-- equals()
do
    local a = m(2, 2, {{1,0},{0,1}})
    local b = m(2, 2, {{1,0},{0,1}})
    local c = m(2, 2, {{1,0},{0,2}})
    assert(a:equals(b), "equal matrices")
    assert(not a:equals(c), "unequal matrices")
    local d = m(3, 2, {{1,0},{0,1},{0,0}})
    assert(not a:equals(d), "different dimensions")
    print("PASS: equals")
end

-- transpose()
do
    local a = m(2, 2, {{1,2},{3,4}})
    local t = a:transpose()
    assert_immutable(a, t, "transpose")
    assert_eq(t, m(2, 2, {{1,3},{2,4}}), "transpose 2x2")

    local b = m(2, 3, {{1,2,3},{4,5,6}})
    local bt = b:transpose()
    assert(bt.rows == 3 and bt.cols == 2, "transpose dimensions")
    assert(bt.values[1][1] == 1 and bt.values[2][1] == 2 and bt.values[3][1] == 3, "transpose values col1")
    assert(bt.values[1][2] == 4 and bt.values[2][2] == 5 and bt.values[3][2] == 6, "transpose values col2")
    print("PASS: transpose")
end

-- double transpose = identity
do
    local a = m(2, 2, {{1,2},{3,4}})
    assert_eq(a:transpose():transpose(), a, "double transpose = original")
    print("PASS: double transpose")
end

-- scale_row()
do
    local a = m(2, 2, {{1,2},{3,4}})
    local s = a:scale_row(1, 2)
    assert_immutable(a, s, "scale_row")
    assert_eq(s, m(2, 2, {{2,4},{3,4}}), "scale_row row1 by 2")
    -- original unchanged
    assert(a.values[1][1] == 1, "scale_row: original row1 unchanged")
    print("PASS: scale_row")
end

-- add_rows()
do
    local a = m(3, 3, {{1,0,0},{2,1,0},{0,0,1}})
    -- add row1 * -2 to row2  =>  row2 becomes [0,1,0]
    local r = a:add_rows(1, 2, -2)
    assert_immutable(a, r, "add_rows")
    assert_eq(r, m(3, 3, {{1,0,0},{0,1,0},{0,0,1}}), "add_rows result")
    assert(a.values[2][1] == 2, "add_rows: original unchanged")
    print("PASS: add_rows")
end

-- swap_rows()
do
    local a = m(2, 2, {{1,2},{3,4}})
    local s = a:swap_rows(1, 2)
    assert_immutable(a, s, "swap_rows")
    assert_eq(s, m(2, 2, {{3,4},{1,2}}), "swap_rows result")
    -- double swap = original
    assert_eq(s:swap_rows(1, 2), a, "double swap = original")
    print("PASS: swap_rows")
end

-- negate()
do
    local a = m(2, 2, {{1,-2},{3,0}})
    local n = a:negate()
    assert_immutable(a, n, "negate")
    assert_eq(n, m(2, 2, {{-1,2},{-3,0}}), "negate result")
    -- double negate = original
    assert_eq(n:negate(), a, "double negate = original")
    print("PASS: negate")
end

-- scalar_mul()
do
    local a = m(2, 2, {{1,2},{3,4}})
    local s = a:scalar_mul(3)
    assert_immutable(a, s, "scalar_mul")
    assert_eq(s, m(2, 2, {{3,6},{9,12}}), "scalar_mul by 3")
    -- scalar_mul by 0 = zero matrix
    assert_eq(a:scalar_mul(0), m(2, 2, {{0,0},{0,0}}), "scalar_mul by 0")
    print("PASS: scalar_mul")
end

-- epsilon comparison
do
    local a = m(1, 1, {{1.0}})
    local b = m(1, 1, {{1.0 + 1e-12}})
    local c = m(1, 1, {{1.0 + 1e-6}})
    assert(a:equals(b), "within epsilon")
    assert(not a:equals(c), "outside epsilon")
    print("PASS: epsilon equals")
end

print("ALL TESTS PASSED")
