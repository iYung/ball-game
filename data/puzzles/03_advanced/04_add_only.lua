-- The only adder reaches the top row and only adds. Taking 3 off the left column means
-- turning it to the top, negating, adding, negating back and turning home.
-- Reference solution (place R90! at (4,2), x-1! at (5,2), +3^! at (6,2), x-1! at (7,2),
-- R90! at (8,2), (9,2) and (8,4)):
--   Pushers: A(1,2), B(8,1), C(10,9).
--   Timeline: t1 A right; t7 A stop, B down; t13 B stop, C left. WIN at t17.
return {
    name   = "Add Only",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=3, y=8 },
    ops       = {},
    fixed_ops = {
        "rotate_90",
        { op = "edge_add", params = { edge = "top", scalar = 3 } },
        { op = "scalar_mul", params = { scalar = -1 } },
    },
    input  = { rows=2, cols=2, values={ {5,1}, {2,7} } },
    target = { rows=2, cols=2, values={ {2,1}, {-1,7} } },
    gaps   = {
        {x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},
        {x=4,y=5},{x=5,y=5},{x=6,y=5},{x=7,y=5},{x=1,y=5},{x=2,y=5},{x=3,y=5},
        {x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},
        {x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},
    },
}
