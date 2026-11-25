-- Arch route: RIGHT×4, DOWN×6, LEFT×5. Player places transpose and scalar_mul (x-1).
-- Locked edge_scale(edge=top,s=3) at (5,3) fires step2 going RIGHT to anchor(4,2):
--   old fp(3-4)×(2-3) → new fp(4-5)×(2-3), newly-entered x=5: (5,3).
-- Player transpose at (7,4): fires DOWN step1 (step5); x-1 at (7,6): fires DOWN step3 (step7).
-- Chain: {{1,2},{0,1}} → x3 top → {{3,6},{0,1}} →transpose→ {{3,0},{6,1}} → x-1 → {{-3,0},{-6,-1}}✓
-- Pushers: A(1,2)R×4, B(7,1)D×6, C(8,8)L×5. Sink(1,9)✓
return {
    name   = "Locked Scale, Full Maze",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = { "transpose", "scalar_mul" },
    locked = {
        { kind="op", op="edge_scale", x=5, y=3, params={edge="top", scalar=3} },
    },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    },
    input  = { rows=2, cols=2, values={ {1,2}, {0,1} } },
    target = { rows=2, cols=2, values={ {-3,0}, {-6,-1} } },
}
