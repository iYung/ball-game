-- "Absolute Rotation": locked rotate_90 fires during RIGHT, player abs fires during DOWN.
-- Wall-A: y=4, x=1–5 (open x=6–10). No other walls.
-- Route: RIGHT×4 (2,2→6,2), DOWN×6 (6,2→6,8), LEFT×5 (6,8→1,8). Sink (1,9) ✓
-- Pushers: A at (1,3) RIGHT×4; B at (7,1) DOWN×6; C at (8,8) LEFT×5.
-- Locked rotate_90(CW) at (5,3): fires at step 2 anchor=(4,2) [fp (4–5)×(2–3)].
-- Player abs at (7,5): fires at step 6 anchor=(6,4) [fp (6–7)×(4–5)].
-- Transform: {{-2,1},{3,-4}} → rotate_90(CW) → {{3,-2},{-4,1}} → abs → {{3,2},{4,1}} ✓
return {
    name   = "Absolute Rotation",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = { "abs" },
    input  = { rows=2, cols=2, values={ {-2,1},{3,-4} } },
    target = { rows=2, cols=2, values={ {3,2},{4,1} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    },
    locked = {
        { kind="op", op="rotate_90", x=5, y=3 },
    },
}
