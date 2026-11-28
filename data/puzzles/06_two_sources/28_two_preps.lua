-- Each input needs its own op before the sum: INPUT 1 doubled, INPUT 2 mirrored.
-- Reference solution (place xk (k = 2) at (4,4); FLh at (6,6); M+ facing bottom,
-- left operand (4,5), right operand (4,6)):
--   Pushers: A(4,1), B(9,6), C(3,4).
--   Timeline: t1 A down, B left; t3 A stop; t4 B stop, C right.
--   t1: both prep tiles fire. SRC 1 waits on the L cell from t2.
--   Merge at t3: 2 x SRC 1 + FLh(SRC 2) = {{7,6},{6,1}} at (4,4).
--   C pushes the sum right; it covers the sink (8,5) at t6. WIN.
return {
    name    = "Two Preps",
    grid_w  = 10, grid_h = 10,
    source  = { x=4, y=2 },
    source2 = { x=7, y=6 },
    sink    = { x=8, y=5 },
    ops     = { "scalar_mul", "flip_h", "matrix_add" },
    input   = { rows=2, cols=2, values={ {1,3}, {2,0} } },
    input2  = { rows=2, cols=2, values={ {0,5}, {1,2} } },
    target  = { rows=2, cols=2, values={ {7,6}, {6,1} } },
}
