-- Puzzle editor: navigation, tile placement, erase, copy flash, back, and test flow.
return {
    {
        name  = "open editor from start screen",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { assert_text  = "PUZZLE EDITOR" },
        },
    },
    {
        name  = "place source, sink and gap on the grid",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:source" } },
            { assert_button = { id = "editor:pal:source", selected = true } },
            { click_cell   = { 2, 2 } },
            { assert_tile  = { x = 2, y = 2, kind = "source" } },
            { click_button = { id = "editor:pal:sink" } },
            { click_cell   = { 8, 8 } },
            { assert_tile  = { x = 8, y = 8, kind = "sink" } },
            { click_button = { id = "editor:pal:gap" } },
            { click_cell   = { 5, 5 } },
            { assert_tile  = { x = 5, y = 5, kind = "gap" } },
        },
    },
    {
        name  = "place an op tile then right-click to erase it",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:transpose" } },
            { assert_button = { id = "editor:pal:transpose", selected = true } },
            { click_cell   = { 4, 4 } },
            { assert_tile  = { x = 4, y = 4, kind = "op", op = "transpose" } },
            { right_click_cell = { 4, 4 } },
            { assert_tile  = { x = 4, y = 4 } },
        },
    },
    {
        name  = "copy button produces Copied! flash",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:copy" } },
            { assert_text  = "Copied!" },
            { wait         = 1 },
            { assert_text  = "Copied!" },
        },
    },
    {
        name  = "back button returns to start screen",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:back" } },
            { assert_text  = "MATRIX PUSH" },
        },
    },
    {
        name  = "test button opens matrix scene; Menu returns to editor",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:test" } },
            { assert_text  = "INPUT" },
            { click_button = { id = "cmd:menu" } },
            { assert_text  = "PUZZLE EDITOR" },
        },
    },
    {
        name  = "escape key exits editor to start screen",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { press        = "escape" },
            { assert_text  = "MATRIX PUSH" },
        },
    },
    {
        name  = "pusher placement",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:pusher" } },
            { assert_button = { id = "editor:pal:pusher", selected = true } },
            { click_cell   = { 3, 3 } },
            { assert_tile  = { x = 3, y = 3, kind = "pusher" } },
            { right_click_cell = { 3, 3 } },
            { assert_tile  = { x = 3, y = 3 } },
        },
    },
    {
        name  = "op allowlist toggle",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            -- toggle transpose on
            { click_button = { id = "editor:allow:transpose" } },
            { assert_button = { id = "editor:allow:transpose", selected = true } },
            -- toggle it off
            { click_button = { id = "editor:allow:transpose" } },
            { assert_button = { id = "editor:allow:transpose", selected = false } },
        },
    },
    {
        name  = "input matrix row spinner and value cell",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            -- increment input rows from 2 to 3
            { click_button = { id = "editor:input_rows_inc" } },
            -- decrement back to 2
            { click_button = { id = "editor:input_rows_dec" } },
            -- increment input cols from 2 to 3
            { click_button = { id = "editor:input_cols_inc" } },
            -- decrement back
            { click_button = { id = "editor:input_cols_dec" } },
            -- same for target
            { click_button = { id = "editor:target_rows_inc" } },
            { click_button = { id = "editor:target_rows_dec" } },
            { click_button = { id = "editor:target_cols_inc" } },
            { click_button = { id = "editor:target_cols_dec" } },
            -- click a matrix value cell (left side = decrement, right side = increment)
            { click_button = { id = "editor:input_cell:1,1" } },
            { click_button = { id = "editor:target_cell:1,1" } },
        },
    },
    {
        name  = "name field focus and text input",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:name" } },
            { assert_button = { id = "editor:name", selected = true } },
            -- text_input is driven by press steps in the harness only via key_pressed;
            -- backspace removes the last char from the initial empty name (no-op on empty)
            { press = "backspace" },
            -- return unfocuses
            { press = "return" },
            { assert_button = { id = "editor:name", selected = false } },
        },
    },
    {
        name  = "paste with valid clipboard loads puzzle",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            -- Copy first to populate the stub clipboard
            { click_button = { id = "editor:copy" } },
            { assert_text  = "Copied!" },
            -- Paste back — should succeed silently (no error flash)
            { click_button = { id = "editor:paste" } },
            { assert_text  = "PUZZLE EDITOR" },
        },
    },
}
