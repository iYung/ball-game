-- A shaft two cells wide: every matrix in it covers both columns, and stepping into the
-- side exit touches the sink. Two matrices can never stand side by side, so M+ only
-- works turned upright.
-- Reference solution (place M+ facing bottom, left operand (4,4), right operand (4,5)):
--   Pushers: A(4,1), B(4,9), C(3,5).
--   Timeline: t1 A down, B up; t2 A stop (SRC 1 waits on the L cell);
--             t3 B stop, A down; t5 A stop, C right.
--   Merge at t2: SRC 1 + SRC 2 = {{3,3},{5,1}} at (4,3).
--   A pushes the sum down to (4,5); C pushes it onto the sink (6,5) at t5. WIN.
return {
    name    = "Turned Sum",
    grid_w  = 10, grid_h = 10,
    source  = { x=4, y=2 },
    source2 = { x=4, y=7 },
    sink    = { x=6, y=5 },
    ops     = { "matrix_add" },
    input   = { rows=2, cols=2, values={ {2,-1}, {0,3} } },
    input2  = { rows=2, cols=2, values={ {1,4}, {5,-2} } },
    target  = { rows=2, cols=2, values={ {3,3}, {5,1} } },
    gaps    = {
        {x=1,y=1},{x=2,y=1},{x=3,y=1},{x=6,y=1},{x=7,y=1},{x=8,y=1},{x=9,y=1},{x=10,y=1},
        {x=1,y=2},{x=2,y=2},{x=3,y=2},{x=6,y=2},{x=7,y=2},{x=8,y=2},{x=9,y=2},{x=10,y=2},
        {x=1,y=3},{x=2,y=3},{x=3,y=3},{x=6,y=3},{x=7,y=3},{x=8,y=3},{x=9,y=3},{x=10,y=3},
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=6,y=4},{x=7,y=4},{x=8,y=4},{x=9,y=4},{x=10,y=4},
        {x=1,y=5},{x=2,y=5},{x=7,y=5},{x=8,y=5},{x=9,y=5},{x=10,y=5},
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=7,y=6},{x=8,y=6},{x=9,y=6},{x=10,y=6},
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},{x=10,y=7},
        {x=1,y=8},{x=2,y=8},{x=3,y=8},{x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},{x=10,y=8},
        {x=1,y=9},{x=2,y=9},{x=3,y=9},{x=6,y=9},{x=7,y=9},{x=8,y=9},{x=9,y=9},{x=10,y=9},
        {x=1,y=10},{x=2,y=10},{x=3,y=10},{x=6,y=10},{x=7,y=10},{x=8,y=10},{x=9,y=10},{x=10,y=10},
    },
}
