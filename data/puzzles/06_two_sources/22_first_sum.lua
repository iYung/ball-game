-- Two sources meet on a locked M+: the sum is the only matrix that may reach the sink.
-- Reference solution (no tiles to place; locked M+ left operand (5,4), facing right):
--   Pushers: A(1,4), B(9,4), C(4,3).
--   Timeline: t1 A right, B left; t2 B stop (SRC 2 waits on the R cell);
--             t3 A stop, C down.
--   Merge at t2: SRC 1 + SRC 2 = {{6,2},{4,6}} at (4,4).
--   C pushes the sum down; it covers the sink (5,7) at t4. WIN.
return {
    name    = "First Sum",
    grid_w  = 10, grid_h = 10,
    source  = { x=2, y=4 },
    source2 = { x=7, y=4 },
    sink    = { x=5, y=7 },
    ops     = {},
    locked  = {
        { kind="op", op="matrix_add", x=5, y=4, params={ facing="right" } },
    },
    input   = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    input2  = { rows=2, cols=2, values={ {5,0}, {1,2} } },
    target  = { rows=2, cols=2, values={ {6,2}, {4,6} } },
}
