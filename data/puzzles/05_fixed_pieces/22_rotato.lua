-- Reference solution: one rotate_90 at (4,4); the matrix crosses it and the locked tile twice.
-- Pushers: A(1,2), B(4,1), C(4,5). Right twice, then down, up, down x3 into the sink.
-- Chain: {{1,1},{1,1}} → x2 top → {{2,2},{1,1}} → rotate → {{1,2},{1,2}}
--        → x2 top → {{2,4},{1,2}} → rotate → {{1,2},{2,4}}
return {
    name   = "Rotato",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=4, y=6 },
    ops    = { "rotate_90" },
    locked = {
        { kind="op", op="edge_scale", x=5, y=2, params={edge="top", scalar=2} },
    },
    gaps   = {
        {x=8,y=1},{x=8,y=2},{x=8,y=3},{x=8,y=4},{x=8,y=5},{x=8,y=6},{x=8,y=7},{x=8,y=8},{x=1,y=9},{x=2,y=9},{x=3,y=9},{x=4,y=9},{x=5,y=9},{x=6,y=9},{x=7,y=9},{x=8,y=9},
    },
    input  = { rows=2, cols=2, values={ {1,1}, {1,1} } },
    target = { rows=2, cols=2, values={ {1,2}, {2,4} } },
}
