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

-- add_matrix()
do
    -- basic 2×2 element-wise addition
    local a = m(2, 2, {{1,2},{3,4}})
    local b = m(2, 2, {{10,20},{30,40}})
    local r = a:add_matrix(b)
    assert_immutable(a, r, "add_matrix")
    assert_eq(r, m(2, 2, {{11,22},{33,44}}), "add_matrix 2x2")
    -- original unchanged
    assert(a.values[1][1] == 1, "add_matrix: original unchanged")

    -- dimension mismatch: 1×1 added to 2×2 — only overlapping cell changes
    local c = m(2, 2, {{5,6},{7,8}})
    local small = m(1, 1, {{100}})
    local r2 = c:add_matrix(small)
    assert(r2.values[1][1] == 105, "add_matrix: overlapping cell updated")
    assert(r2.values[1][2] == 6,   "add_matrix: non-overlapping col unchanged")
    assert(r2.values[2][1] == 7,   "add_matrix: non-overlapping row unchanged")
    assert(r2.values[2][2] == 8,   "add_matrix: non-overlapping cell unchanged")
    print("PASS: add_matrix")
end

-- sub_matrix()
do
    -- basic 2×2 element-wise subtraction
    local a = m(2, 2, {{10,20},{30,40}})
    local b = m(2, 2, {{1,2},{3,4}})
    local r = a:sub_matrix(b)
    assert_immutable(a, r, "sub_matrix")
    assert_eq(r, m(2, 2, {{9,18},{27,36}}), "sub_matrix 2x2")
    -- original not mutated (copy semantics)
    assert(a.values[1][1] == 10, "sub_matrix: original row1 col1 unchanged")
    assert(a.values[2][2] == 40, "sub_matrix: original row2 col2 unchanged")
    print("PASS: sub_matrix")
end

-- mul_matrix()
do
    -- basic 2×2 element-wise multiplication
    local a = m(2, 2, {{2,3},{4,5}})
    local b = m(2, 2, {{10,10},{10,10}})
    local r = a:mul_matrix(b)
    assert_immutable(a, r, "mul_matrix")
    assert_eq(r, m(2, 2, {{20,30},{40,50}}), "mul_matrix 2x2")

    -- all-ones operand returns identical matrix (identity for element-wise multiply)
    local ones = m(2, 2, {{1,1},{1,1}})
    local r2 = a:mul_matrix(ones)
    assert_eq(r2, a, "mul_matrix: all-ones operand is identity")
    print("PASS: mul_matrix")
end

-- set_row()
do
    -- replace row 2 of a 3×3 matrix with specific values
    local a = m(3, 3, {{1,2,3},{4,5,6},{7,8,9}})
    local r = a:set_row(2, {10,20,30})
    assert_immutable(a, r, "set_row")
    assert_eq(r, m(3, 3, {{1,2,3},{10,20,30},{7,8,9}}), "set_row row2")
    -- original unchanged
    assert(a.values[2][1] == 4, "set_row: original unchanged")

    -- out-of-range row returns unchanged copy (r=0)
    local r2 = a:set_row(0, {99,99,99})
    assert_eq(r2, a, "set_row: r=0 returns unchanged copy")

    -- out-of-range row returns unchanged copy (r=5 on 3-row matrix)
    local r3 = a:set_row(5, {99,99,99})
    assert_eq(r3, a, "set_row: r=5 on 3-row matrix returns unchanged copy")

    -- values shorter than cols — only specified cols change, rest unchanged
    local r4 = a:set_row(1, {77})
    assert(r4.values[1][1] == 77, "set_row: short values col1 updated")
    assert(r4.values[1][2] == 2,  "set_row: short values col2 unchanged")
    assert(r4.values[1][3] == 3,  "set_row: short values col3 unchanged")
    print("PASS: set_row")
end

-- scale_col()
do
    local a = m(2, 2, {{1,2},{3,4}})
    local r = a:scale_col(2, 3)
    assert_immutable(a, r, "scale_col")
    assert_eq(r, m(2, 2, {{1,6},{3,12}}), "scale_col result")
    print("PASS: scale_col")
end

-- swap_cols()
do
    local a = m(2, 3, {{1,2,3},{4,5,6}})
    local r = a:swap_cols(1, 3)
    assert_immutable(a, r, "swap_cols")
    assert_eq(r, m(2, 3, {{3,2,1},{6,5,4}}), "swap_cols result")
    local same = a:swap_cols(2, 2)
    assert_eq(same, a, "swap_cols same col no-op")
    print("PASS: swap_cols")
end

-- add_cols()
do
    local a = m(2, 2, {{1,0},{2,0}})
    local r = a:add_cols(1, 2, 3)
    assert_immutable(a, r, "add_cols")
    assert_eq(r, m(2, 2, {{1,3},{2,6}}), "add_cols result")
    local same = a:add_cols(1, 1, 5)
    assert(same == a, "add_cols same col is a no-op")
    print("PASS: add_cols")
end

-- set_col()
do
    local a = m(3, 2, {{1,2},{3,4},{5,6}})
    local r = a:set_col(1, {9,8,7})
    assert_immutable(a, r, "set_col")
    assert_eq(r, m(3, 2, {{9,2},{8,4},{7,6}}), "set_col result")
    print("PASS: set_col")
end

-- rotate_90()
do
    local a = m(2, 3, {{1,2,3},{4,5,6}})
    local r = a:rotate_90()
    assert_immutable(a, r, "rotate_90")
    assert_eq(r, m(3, 2, {{4,1},{5,2},{6,3}}), "rotate_90 result")
    print("PASS: rotate_90")
end

-- flip_h()
do
    local a = m(2, 3, {{1,2,3},{4,5,6}})
    local r = a:flip_h()
    assert_immutable(a, r, "flip_h")
    assert_eq(r, m(2, 3, {{3,2,1},{6,5,4}}), "flip_h result")
    print("PASS: flip_h")
end

-- flip_v()
do
    local a = m(3, 2, {{1,2},{3,4},{5,6}})
    local r = a:flip_v()
    assert_immutable(a, r, "flip_v")
    assert_eq(r, m(3, 2, {{5,6},{3,4},{1,2}}), "flip_v result")
    print("PASS: flip_v")
end

-- abs()
do
    local a = m(2, 2, {{-1,2},{-3,-4}})
    local r = a:abs()
    assert_immutable(a, r, "abs")
    assert_eq(r, m(2, 2, {{1,2},{3,4}}), "abs result")
    print("PASS: abs")
end

print("ALL TESTS PASSED")
