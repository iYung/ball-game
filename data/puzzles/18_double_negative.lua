-- "Double Negative": locked rotate_90 fires during RIGHT, two player edge_scale tiles fire during DOWN.
-- Wall-A: y=4, x=1–5 (open x=6–10). No other walls.
-- Route: RIGHT×4 (2,2→6,2), DOWN×6 (6,2→6,8), LEFT×5 (6,8→1,8). Sink (1,9) ✓
-- Pushers: A at (1,3) RIGHT×4; B at (7,1) DOWN×6; C at (8,8) LEFT×5.
-- Locked rotate_90(CW) at (5,3): fires at step 2 anchor=(4,2) [fp (4–5)×(2–3)].
-- Player x-1 right at (7,4): fires at step 5 anchor=(6,3) [fp (6–7)×(3–4)].
-- Player x-1 bottom at (7,6): fires at step 7 anchor=(6,5) [fp (6–7)×(5–6)].
-- Transform: {{-2,1},{3,-4}} → rotate_90(CW) → {{3,-2},{-4,1}} → x-1 right → {{3,2},{-4,-1}}
--            → x-1 bottom → {{3,2},{4,1}} ✓
return {
    name   = "Double Negative",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = { "edge_scale" },
    input  = { rows=2, cols=2, values={ {-2,1},{3,-4} } },
    target = { rows=2, cols=2, values={ {3,2},{4,1} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    },
    locked = {
        { kind="op", op="rotate_90", x=5, y=3 },
    },
}
