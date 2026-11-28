-- Both preset tools only reach the top row: flip to bring the other row up.
-- Reference solution (place +3^! at (5,2), x2^! at (4,2), FLv at (2,5), x2^! at (5,7)):
--   Pushers: A(9,2), B(2,1), C(1,6).
--   Timeline: t1 A left; t6 A stop, B down; t10 B stop, C right. WIN at t15.
return {
    name   = "Top Only",
    grid_w = 10, grid_h = 10,
    source = { x=7, y=2 },
    sink   = { x=9, y=7 },
    ops    = { "flip_v" },
    fixed_ops = {
        { op = "edge_scale", params = { edge = "top", scalar = 2 } },
        { op = "edge_add", params = { edge = "top", scalar = 3 } },
    },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {6,8}, {8,10} } },
    gaps   = {
        {x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},{x=8,y=4},{x=9,y=4},{x=10,y=4},
        {x=4,y=5},{x=5,y=5},{x=6,y=5},{x=7,y=5},{x=8,y=5},{x=9,y=5},{x=10,y=5},
    },
}
