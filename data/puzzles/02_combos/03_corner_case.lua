-- Three edge ops that share corners, so their order shows in the corner values.
-- Reference solution (place +k^ (3, top) at (5,2), xk^ (2, left) at (6,3),
-- +k^ (1, bottom) at (8,6)):
--   Pushers: A(1,3), B(8,1), C(10,7).
--   Timeline: t1 A right; t6 A stop, B down; t10 B stop, C left. WIN at t13.
return {
    name   = "Corner Case",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=3, y=8 },
    ops    = { "edge_scale", "edge_add" },
    input  = { rows=3, cols=3, values={ {1,2,3}, {4,5,6}, {7,8,9} } },
    target = { rows=3, cols=3, values={ {8,5,6}, {8,5,6}, {15,9,10} } },
    gaps   = {
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},{x=6,y=5},{x=10,y=5},
    },
}
