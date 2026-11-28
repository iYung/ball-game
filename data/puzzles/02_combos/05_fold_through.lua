-- The first gate is two rows tall and the second two columns wide, so the matrix
-- must be transposed between them, and the arithmetic has to fit around that.
-- Reference solution (place -k (3) at (5,2), xk^ (-2, left) at (6,3), -k (1) at (7,2),
-- T at (10,3)):
--   Pushers: A(1,2), B(8,1), C(10,8).
--   Timeline: t1 A right; t7 A stop, B down; t12 B stop, C left. WIN at t16.
return {
    name   = "Fold Through",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=3, y=8 },
    ops    = { "transpose", "edge_scale", "scalar_sub" },
    input  = { rows=2, cols=3, values={ {1,2,3}, {4,5,6} } },
    target = { rows=3, cols=2, values={ {3,-3}, {-2,1}, {-1,2} } },
    gaps   = {
        {x=6,y=1},
        {x=6,y=4},
        {x=6,y=5},
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=10,y=6},
    },
}
