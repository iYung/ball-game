-- Ordered Ops: scale_row + swap_rows, same Z-route as puzzle 6
-- Only scale_row-first ordering produces the target:
--   scale_row(r=1,s=2) then swap_rows(1,2): {{2,4},{3,4}} → {{3,4},{2,4}} ✓
--   swap_rows(1,2) then scale_row(r=1,s=2): {{3,4},{1,2}} → {{6,8},{1,2}} ✗
return {
    name   = "Ordered Ops",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "scale_row", "swap_rows" },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {3,4}, {2,4} } },
    gaps   = {
        {x=1,y=3},{x=4,y=3},{x=5,y=3},
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
        {x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
}
