-- "Corridor Cross": narrow corridor forces matrix to remain 2×3 (pre-transpose) while passing.
-- Corridor at x=5–6 is open only at y=5–6 (2 rows); 3×2 (post-transpose) is 3 rows tall and
-- cannot pass (its bottom row at y=7 hits the gap at x=5,y=7 or x=6,y=7).
-- After the corridor, player places transpose; 3×2 then navigates down to sink (9,8).
-- Upper-right wall (x=7–10, y=1–4) shapes the post-corridor space; (10,4) left open so
-- a pusher there can drive the 3×2 matrix down after two post-corridor right pushes.
-- Route: RIGHT×5 (source→corridor), transpose fires at (9,5) step 5, RIGHT×2 (3×2 to 9,5),
--        DOWN×1 pusher at (10,4), matrix at (9,6) → sink (9,8) covered. Win!
return {
    name   = "Corridor Cross",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    sink   = { x=9, y=8 },
    ops    = { "transpose" },
    input  = { rows=2, cols=3, values={ {1,2,3},{4,5,6} } },
    target = { rows=3, cols=2, values={ {1,4},{2,5},{3,6} } },
    gaps = {
        -- Corridor walls at x=5 and x=6, open only y=5–6
        {x=5,y=1},{x=5,y=2},{x=5,y=3},{x=5,y=4},
        {x=5,y=7},{x=5,y=8},{x=5,y=9},{x=5,y=10},
        {x=6,y=1},{x=6,y=2},{x=6,y=3},{x=6,y=4},
        {x=6,y=7},{x=6,y=8},{x=6,y=9},{x=6,y=10},
        -- Upper-right wall: x=7–10, y=1–4; (10,4) intentionally open for the down pusher
        {x=7,y=1},{x=7,y=2},{x=7,y=3},{x=7,y=4},
        {x=8,y=1},{x=8,y=2},{x=8,y=3},{x=8,y=4},
        {x=9,y=1},{x=9,y=2},{x=9,y=3},{x=9,y=4},
        {x=10,y=1},{x=10,y=2},{x=10,y=3},
    },
}
