-- Regression: pushing a 2x3 matrix onto a T op transposes it to 3x2, moving it off
-- the T tile. Pushing it back onto T must fire T again (double transpose = identity).
--
-- Setup (puzzle fold_through, Fold Through, 2 rows x 3 cols input at source (2,2)):
--   T op at (9,2); pusher A at (1,2) given one right chip at tick 1 (the command persists).
--   Path: the matrix covers x 2-4 and moves right. When it reaches x 7-9 its right
--         column enters (9,2): T fires and it becomes 3x2 at x 7-8, off the tile.
--         The next push moves it to x 8-9, back onto (9,2): T must fire again,
--         giving the original 2x3 values.
--   The second fire is the regression: if the footprint from before the first fire is
--   kept, (9,2) still counts as covered, the tile never re-arms and the matrix stays
--   transposed.
--   T sits this far right because from a nearer cell the transposed (3 rows tall)
--   matrix runs into the gap at (6,4).
-- Everything in the worlds before Combos is solved, so the world is open.

local S = require("tests/support/shipped")

return {
    name  = "transpose re-arms after matrix dimension shrinks off the tile",
    given = { solved = S.before("combos") },
    steps = S.steps({
        { press = "return" },
        S.arrows("combos"),
        { click_button = S.row("fold_through") },
        { assert_text = "Fold Through" },

        -- Place transpose op at (9,2).
        { click_button = { id = "palette:transpose" } },
        { click_cell   = { 9, 2 } },
        { assert_tile  = { x = 9, y = 2, kind = "op", op = "transpose" } },

        -- Place pusher at (1,2).
        { click_button = { id = "palette:pusher" } },
        { click_cell   = { 1, 2 } },
        { assert_tile  = { x = 1, y = 2, kind = "pusher" } },

        -- Drag one 'right' chip to tick 1; the pusher keeps moving right.
        { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },

        -- Run; first wait for the transposed state (T fired once), then verify T
        -- fires again to restore the original matrix (double-transpose = identity).
        { click_button = "Run" },
        { wait_until   = { matrix = {{1,4},{2,5},{3,6}}, max_frames = 500 } },
        { wait_until   = { matrix = {{1,2,3},{4,5,6}}, max_frames = 500 } },
    }),
}
