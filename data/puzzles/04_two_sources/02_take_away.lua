-- There is no subtract tile for two matrices: negate INPUT 2 on its way to the locked M+.
-- Reference solution (place xk at (7,4) with k = -1):
--   Pushers: A(1,4), B(10,4), C(4,3).
--   Timeline: t1 A right, B left; t3 A stop, B stop, C down.
--   t1: SRC 2 enters the xk tile and is negated. Merge at t2: {{4,1},{1,5}} at (4,4).
--   C pushes the sum down; it covers the sink (5,8) at t5. WIN.
return {
    name    = "Take Away",
    grid_w  = 10, grid_h = 10,
    source  = { x=2, y=4 },
    source2 = { x=8, y=4 },
    sink    = { x=5, y=8 },
    ops     = { "scalar_mul" },
    locked  = {
        { kind="op", op="matrix_add", x=5, y=4, params={ facing="right" } },
    },
    input   = { rows=2, cols=2, values={ {5,3}, {4,6} } },
    input2  = { rows=2, cols=2, values={ {1,2}, {3,1} } },
    target  = { rows=2, cols=2, values={ {4,1}, {1,5} } },
}
