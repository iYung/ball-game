-- Cursor path: right to x=5,y=5 → down to y=6 (op slot) → down to y=7 → right to x=6 (op slot) → right to x=7 → up to y=5 → right to sink
-- Player must place Transpose at x=5,y=6 and x=6,y=7; two transposes cancel out → identity
return {
    name   = "Double Flip",
    grid_w = 10, grid_h = 10,
    source = { x=1, y=5, dir="right" },
    sink   = { x=10, y=5 },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    locked = {
        { x=5, y=5, kind="arrow", dir="down"  },
        { x=5, y=7, kind="arrow", dir="right" },
        { x=7, y=7, kind="arrow", dir="up"    },
        { x=7, y=5, kind="arrow", dir="right" },
    },
}
