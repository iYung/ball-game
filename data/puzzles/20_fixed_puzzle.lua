-- Arch route: RIGHT×4, DOWN×6 (x-1 fires), LEFT×5. No player ops — just pushers.
-- Locked scalar_mul (x-1) at (6,6) fires when matrix passes DOWN from anchor(6,4) to (6,5):
--   old fp(6-7)×(4-5) → new fp(6-7)×(5-6), newly-entered y=6: (6,6).
-- Pushers: A(1,2)R×4, B(7,1)D×6, C(8,8)L×5. Sink(1,9): anchor(1,8)→fp(1-2)×(8-9)→(1,9)✓
return {
    name   = "Mandatory Negate, Arch Path",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = {},
    locked = {
        { kind="op", op="scalar_mul", x=6, y=6, params={scalar=-1} },
    },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-1,-2}, {-3,-4} } },
}
