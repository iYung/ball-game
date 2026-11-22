-- Timeline zone styling & overflow: scroll_up / scroll_down buttons.
--
-- Verifies that tl:scroll_up and tl:scroll_down are registered in
-- ui_elements() once a pusher is placed on the board.  The invariant
-- check that runs every frame (UIRunner.check_invariants) validates that
-- each button has a non-zero rect within the 1280×720 screen and does not
-- overlap any other element — that is the hit-testability guarantee.
--
-- With puzzle 1 (2×2 matrix) the HUD is short enough that all 8 possible
-- pushers fit in the visible row area, so both buttons are disabled when
-- only one pusher is placed.  The spec confirms they are present-but-
-- disabled and that assert_button does not error; it does not attempt
-- click_button because the framework requires enabled=true for that step.
--
-- A second spec exercises the teal background by asserting the timeline
-- label is still drawn after placement (regression guard: a broken
-- background draw would likely crash or skip the draw call entirely).

return {
    {
        name  = "tl:scroll_up and tl:scroll_down registered after pusher placed",
        given = { solved = {} },
        steps = {
            -- Navigate to puzzle 1 from the start screen.
            { press        = "return" },
            { click_button = { id = "puzzle:1" } },
            { assert_text  = "Identity Check" },

            -- Place a pusher on the board.
            { click_button = "P" },
            { assert_button = { id = "palette:pusher", selected = true } },
            { click_cell   = { 5, 5 } },
            { assert_tile  = { x = 5, y = 5, kind = "pusher" } },

            -- Scroll_up and scroll_down are now registered (disabled: only
            -- one pusher, all rows fit in view).
            { assert_button = { id = "tl:scroll_up",   enabled = false } },
            { assert_button = { id = "tl:scroll_down", enabled = false } },
        },
    },

    {
        name  = "timeline label still drawn after background draw (regression)",
        given = { solved = {} },
        steps = {
            { press        = "return" },
            { click_button = { id = "puzzle:1" } },
            { assert_text  = "Identity Check" },

            -- Place a pusher so the timeline row area is active.
            { click_button = "P" },
            { click_cell   = { 3, 3 } },

            -- The TIMELINE header must still be drawn after the zone
            -- background rect is painted beneath it.
            { assert_text  = "TIMELINE" },
        },
    },
}
