local Matrix = require("lua/game/matrix_math")

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

local function assert_no_negative_zero(mat, msg)
    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local v = mat.values[r][c]
            assert(not (v == 0 and 1 / v == -math.huge), msg .. ": -0 at " .. r .. "," .. c)
        end
    end
end

-- op applied to src gives expected, in a new matrix, leaving src alone and without -0
local function check(src, op, args, expected, msg)
    local before = src:copy()
    local result = src[op](src, unpack(args))
    assert_immutable(src, result, msg)
    assert_eq(result, expected, msg)
    assert_eq(src, before, msg .. ": source unchanged")
    assert_no_negative_zero(result, msg)
end

-- scalar_add() / scalar_sub()
do
    local a = m(2, 3, {{1,2,3},{4,5,9}})
    check(a, "scalar_add", {7}, m(2, 3, {{8,9,10},{11,12,16}}), "scalar_add above 9")
    check(a, "scalar_add", {0}, a, "scalar_add 0")
    check(a, "scalar_sub", {5}, m(2, 3, {{-4,-3,-2},{-1,0,4}}), "scalar_sub negative results")
    check(a, "scalar_sub", {0}, a, "scalar_sub 0")
    check(m(1, 3, {{-1,0,1}}), "scalar_add", {1}, m(1, 3, {{0,1,2}}), "scalar_add one row")
    check(m(3, 1, {{1},{2},{3}}), "scalar_sub", {1}, m(3, 1, {{0},{1},{2}}), "scalar_sub one column")
    print("PASS: scalar_add/scalar_sub")
end

-- edge_scale() / edge_add() / edge_sub(): all four edges of a non-square matrix
do
    local a = m(3, 4, {{1,2,3,4},{5,6,7,8},{9,10,11,12}})
    check(a, "edge_scale", {"top", 2},    m(3, 4, {{2,4,6,8},{5,6,7,8},{9,10,11,12}}),     "edge_scale top")
    check(a, "edge_scale", {"right", 2},  m(3, 4, {{1,2,3,8},{5,6,7,16},{9,10,11,24}}),    "edge_scale right")
    check(a, "edge_scale", {"bottom", 2}, m(3, 4, {{1,2,3,4},{5,6,7,8},{18,20,22,24}}),    "edge_scale bottom")
    check(a, "edge_scale", {"left", 2},   m(3, 4, {{2,2,3,4},{10,6,7,8},{18,10,11,12}}),   "edge_scale left")
    check(a, "edge_add", {"top", 9},      m(3, 4, {{10,11,12,13},{5,6,7,8},{9,10,11,12}}), "edge_add top")
    check(a, "edge_add", {"right", 9},    m(3, 4, {{1,2,3,13},{5,6,7,17},{9,10,11,21}}),   "edge_add right")
    check(a, "edge_add", {"bottom", 9},   m(3, 4, {{1,2,3,4},{5,6,7,8},{18,19,20,21}}),    "edge_add bottom")
    check(a, "edge_add", {"left", 9},     m(3, 4, {{10,2,3,4},{14,6,7,8},{18,10,11,12}}),  "edge_add left")
    check(a, "edge_sub", {"top", 5},      m(3, 4, {{-4,-3,-2,-1},{5,6,7,8},{9,10,11,12}}), "edge_sub top")
    check(a, "edge_sub", {"right", 5},    m(3, 4, {{1,2,3,-1},{5,6,7,3},{9,10,11,7}}),     "edge_sub right")
    check(a, "edge_sub", {"bottom", 9},   m(3, 4, {{1,2,3,4},{5,6,7,8},{0,1,2,3}}),        "edge_sub bottom")
    check(a, "edge_sub", {"left", 5},     m(3, 4, {{-4,2,3,4},{0,6,7,8},{4,10,11,12}}),    "edge_sub left")
    for _, edge in ipairs({"top", "right", "bottom", "left"}) do
        check(a, "edge_add", {edge, 0}, a, "edge_add 0 " .. edge)
        check(a, "edge_sub", {edge, 0}, a, "edge_sub 0 " .. edge)
    end
    check(a, "edge_scale", {"top", 0},   m(3, 4, {{0,0,0,0},{5,6,7,8},{9,10,11,12}}),    "edge_scale 0")
    check(a, "edge_scale", {"left", -1}, m(3, 4, {{-1,2,3,4},{-5,6,7,8},{-9,10,11,12}}), "edge_scale -1")
    print("PASS: edge ops")
end

-- one-row and one-column matrices: both opposite edges are that line, changed once
do
    local row = m(1, 3, {{1,2,3}})
    for _, edge in ipairs({"top", "bottom"}) do
        check(row, "edge_scale", {edge, 3}, m(1, 3, {{3,6,9}}),  "one row scale " .. edge)
        check(row, "edge_add",   {edge, 2}, m(1, 3, {{3,4,5}}),  "one row add " .. edge)
        check(row, "edge_sub",   {edge, 2}, m(1, 3, {{-1,0,1}}), "one row sub " .. edge)
    end
    check(row, "edge_add", {"left", 2},  m(1, 3, {{3,2,3}}), "one row left")
    check(row, "edge_add", {"right", 2}, m(1, 3, {{1,2,5}}), "one row right")

    local col = m(3, 1, {{1},{2},{3}})
    for _, edge in ipairs({"left", "right"}) do
        check(col, "edge_scale", {edge, 3}, m(3, 1, {{3},{6},{9}}),  "one column scale " .. edge)
        check(col, "edge_add",   {edge, 2}, m(3, 1, {{3},{4},{5}}),  "one column add " .. edge)
        check(col, "edge_sub",   {edge, 2}, m(3, 1, {{-1},{0},{1}}), "one column sub " .. edge)
    end
    check(col, "edge_add", {"top", 2},    m(3, 1, {{3},{2},{3}}), "one column top")
    check(col, "edge_add", {"bottom", 2}, m(3, 1, {{1},{2},{5}}), "one column bottom")

    check(m(1, 1, {{4}}), "edge_add", {"top", 1}, m(1, 1, {{5}}), "1x1 edge")
    print("PASS: edge ops on one row / one column")
end

-- no operation produces or keeps -0
do
    local zeros = m(2, 2, {{0,1},{0,0}})
    check(zeros, "scalar_mul", {-1}, m(2, 2, {{0,-1},{0,0}}), "scalar_mul -1 of zeros")
    check(zeros, "scalar_mul", {-9}, m(2, 2, {{0,-9},{0,0}}), "scalar_mul -9 of zeros")
    for _, edge in ipairs({"top", "right", "bottom", "left"}) do
        assert_no_negative_zero(zeros:edge_scale(edge, -1), "edge_scale -1 " .. edge)
    end
    local negative = -1 * 0
    assert(1 / negative == -math.huge, "test setup: value is -0")
    local signed = m(2, 2, {{negative,negative},{negative,negative}})
    assert_no_negative_zero(signed, "new")
    assert_no_negative_zero(signed:copy(), "copy")
    for _, op in ipairs({"transpose", "rotate_90", "flip_h", "flip_v"}) do
        assert_no_negative_zero(signed[op](signed), op)
    end
    assert(tostring(zeros:scalar_mul(-1).values[1][1]) == "0", "zero prints without a sign")
    print("PASS: no -0")
end

print("ALL TESTS PASSED")
