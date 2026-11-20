-- Drag/drop tool (Mv) coverage.
--
-- The spec vocabulary sends mouse_pressed and mouse_released as one atomic
-- click step, so true hold-move-release drag cannot be exercised here.
-- What IS reachable:
--   * palette drag selection (click_button "Mv")
--   * mouse_pressed drag-mode + no tile → early return branch
--   * mouse_pressed drag-mode + tile  → pickup + grid.clear
--   * mouse_released valid drop (ghost == source, now empty after pickup)
--
-- Unreachable without vocab extension:
--   * mouse_moved update-ghost branch (requires drag active across steps)
--   * ghost preview in draw_grid (no frame renders while drag is live)
--   * _clear_drag via invalid drop or right-click cancel
--
-- Puzzle 10 "Set Row" (world 2, ops={"set_row"}) is used because its
-- restricted palette fits in the visible window, so "Mv" is always on screen.

return {
    {
        name  = "drag tool: click empty cell is a no-op",
        given = { solved = { 1, 2, 3, 4, 5 } },
        steps = {
            { press        = "return" },
            { press        = "right" },                    -- world 1 → world 2 (no cutscene)
            { click_button = { id = "puzzle:10" } },       -- Set Row: restricted palette
            { click_button = "Mv" },
            { assert_button = { id = "palette:drag", selected = true } },
            -- click_cell on empty cell (1,1) in drag mode → mouse_pressed finds no tile → early return
            { click_cell = { 1, 1 } },
            -- grid unchanged — (1,1) is still empty
            { assert_tile = { x = 1, y = 1 } },
        },
    },
    {
        name  = "drag tool: click on tile picks up and re-drops at same position",
        given = { solved = { 1, 2, 3, 4, 5 } },
        steps = {
            { press        = "return" },
            { press        = "right" },                    -- world 1 → world 2 (no cutscene)
            { click_button = { id = "puzzle:10" } },       -- Set Row: restricted palette
            -- place a pusher so there is something to drag
            { click_button = "P" },
            { click_cell   = { 1, 5 } },
            { assert_tile  = { x = 1, y = 5, kind = "pusher" } },
            -- switch to drag tool
            { click_button = "Mv" },
            { assert_button = { id = "palette:drag", selected = true } },
            -- clicking the pusher in drag mode: press picks it up (clears source),
            -- release finds the ghost at the now-empty source → valid drop back
            { click_cell  = { 1, 5 } },
            { assert_tile = { x = 1, y = 5, kind = "pusher" } },
            -- erase tool still works after switching away from drag
            { right_click_cell = { 1, 5 } },
            { assert_tile = { x = 1, y = 5 } },
        },
    },
}
