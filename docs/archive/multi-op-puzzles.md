# Multi-Op Puzzles Checklist

- [x] Task A — `data/puzzles/12_negate_swap.lua` — create puzzle file: name="Negate & Swap", ops={"negate","swap_rows"}, input 2×2 [[1,2],[3,4]], target [[-3,-4],[-1,-2]]
- [x] Task B — `data/puzzles/13_flip_scale.lua` — create puzzle file: name="Flip & Scale", ops={"transpose","scale_row"}, input 2×2 [[1,2],[3,4]], target [[1,3],[-2,-4]]
- [x] Task C — `data/puzzles/14_elimination.lua` — create puzzle file: name="Elimination", ops={"add_rows","scale_row"}, input 3×3 [[2,0,0],[4,1,0],[0,0,1]], target [[1,0,0],[0,1,0],[0,0,1]]
- [x] Task D — `data/puzzles/15_scale_swap.lua` — create puzzle file: name="Scale & Swap", ops={"scale_row","swap_rows"}, input 3×3 [[1,2,3],[0,0,0],[7,8,9]], target [[7,8,9],[0,0,0],[-1,-2,-3]]
- [x] Task E — `data/puzzles/16_triple.lua` — create puzzle file: name="Triple Threat", ops={"transpose","negate","scale_row"}, input 2×2 [[1,2],[3,4]], target [[-2,-6],[-2,-4]]
- [x] Task F — `game/puzzle_loader.lua` — append the five new puzzle paths ("data/puzzles/12_negate_swap.lua" through "16_triple.lua") to the PUZZLES list
