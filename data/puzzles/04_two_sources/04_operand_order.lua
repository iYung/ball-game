-- Multiplication has an order. The target is INPUT 2 x INPUT 1, but SRC 2 starts on the
-- right, so the Mx tile must be turned to put its L cell on that side.
-- (INPUT 1 x INPUT 2 is 3x3 and misses the target.)
-- Reference solution (place Mx facing left: left operand (6,3), right operand (5,3)):
--   Pushers: A(1,3), B(10,3), C(6,2).
--   Timeline: t1 A right, B left; t2 B stop (SRC 2 waits on the L cell);
--             t3 A stop, C down.
--   Merge at t2: SRC 2 x SRC 1 = {{5,2},{2,10}} at (6,3).
--   C pushes the product down; it covers the sink (7,7) at t5. WIN.
return {
    name    = "Operand Order",
    grid_w  = 10, grid_h = 10,
    source  = { x=2, y=3 },
    source2 = { x=7, y=3 },
    sink    = { x=7, y=7 },
    ops     = { "matrix_mul" },
    input   = { rows=3, cols=2, values={ {1,0}, {2,1}, {0,3} } },
    input2  = { rows=2, cols=3, values={ {1,2,0}, {0,1,3} } },
    target  = { rows=2, cols=2, values={ {5,2}, {2,10} } },
}
