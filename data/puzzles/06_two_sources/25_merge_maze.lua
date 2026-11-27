-- The two inputs are both 2x3, so they cannot be multiplied as they are, and the only
-- way between the rooms is a chute two cells wide. The target is INPUT 1 x T(INPUT 2).
-- Reference solution (place T at (8,2); Mx facing right, left operand (5,7),
-- right operand (6,7)):
--   Pushers: A(4,2), B(6,1), C(1,7), D(3,6), E(1,8).
--   Timeline: t1 A right, C right; t2 A stop, C stop, B down;
--             t5 B stop, D down; t6 D stop, E right.
--   t1: SRC 2 enters T and stands up (3x2) at (6,2); SRC 1 moves onto the L cell.
--   Merge at t4: SRC 1 x T(SRC 2) = {{1,4},{1,1}} at (3,7).
--   D drops the sum a row, clear of the Mx tile (one matrix on both inputs fails);
--   E pushes it right and it covers the sink (10,9) at t12. WIN.
return {
    name    = "Merge Maze",
    grid_w  = 10, grid_h = 10,
    source  = { x=2, y=7 },
    source2 = { x=5, y=2 },
    sink    = { x=10, y=9 },
    ops     = { "transpose", "matrix_mul" },
    input   = { rows=2, cols=3, values={ {1,0,2}, {0,1,1} } },
    input2  = { rows=2, cols=3, values={ {1,1,0}, {2,0,1} } },
    target  = { rows=2, cols=2, values={ {1,4}, {1,1} } },
    gaps    = {
        {x=1,y=1},{x=2,y=1},
        {x=1,y=2},{x=2,y=2},
        {x=1,y=3},{x=2,y=3},
        {x=1,y=4},{x=2,y=4},
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},{x=8,y=5},{x=9,y=5},{x=10,y=5},
        {x=1,y=10},{x=2,y=10},{x=3,y=10},{x=4,y=10},{x=5,y=10},
        {x=6,y=10},{x=7,y=10},{x=8,y=10},{x=9,y=10},{x=10,y=10},
    },
}
