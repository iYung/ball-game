-- A 2x3 and a 3x2 cannot be added: turn INPUT 2 first. Transposing makes it wider, so
-- the pusher that sends it into T must not be in the way of its new shape.
-- Reference solution (place T at (7,4); M+ facing right, left operand (5,4)):
--   Pushers: A(1,4), B(10,6), C(10,4), D(3,3).
--   Timeline: t1 A right, B left; t2 A stop, B stop, C left; t3 C stop, D down.
--   t1: SRC 2 is pushed by its bottom row into T and becomes 2x3, clear of B.
--   Merge at t2: SRC 1 + T(SRC 2) = {{5,2,4},{2,4,2}} at (3,4).
--   D pushes the sum down; it covers the sink (4,8) at t5. WIN.
return {
    name    = "Stand to Add",
    grid_w  = 10, grid_h = 10,
    source  = { x=2, y=4 },
    source2 = { x=8, y=4 },
    sink    = { x=4, y=8 },
    ops     = { "transpose", "matrix_add" },
    input   = { rows=2, cols=3, values={ {1,2,3}, {0,1,2} } },
    input2  = { rows=3, cols=2, values={ {4,2}, {0,3}, {1,0} } },
    target  = { rows=2, cols=3, values={ {5,2,4}, {2,4,2} } },
}
