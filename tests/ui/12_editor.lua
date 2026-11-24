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
            { text_input   = "X" },
            { press        = "backspace" },
            { press        = "return" },
            { assert_button = { id = "editor:name", selected = false } },
        },
    },
    {
        name  = "press E key on title screen opens editor",
        given = { solved = {} },
        steps = {
            { press       = "e" },
            { assert_text = "PUZZLE EDITOR" },
        },
    },
    {
        name  = "paste with invalid clipboard shows parse error",
        given = { solved = {} },
        steps = {
            { click_button   = "Editor" },
            { set_clipboard  = "not valid lua!!!" },
            { click_button   = { id = "editor:paste" } },
            { assert_text    = "Parse error" },
        },
    },
    {
        name  = "refit source: source grows with input rows",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:source" } },
            { click_cell   = { 1, 1 } },
            { assert_tile  = { x = 1, y = 1, kind = "source" } },
            { click_button = { id = "editor:input_rows_inc" } },
            { assert_tile  = { x = 1, y = 1, kind = "source" } },
        },
    },
    {
        name  = "refit source: source cleared when resize goes out of bounds",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:source" } },
            { click_cell   = { 9, 9 } },
            { assert_tile  = { x = 9, y = 9, kind = "source" } },
            -- input is 2x2, source at (9,9) covers (9-10, 9-10); inc rows → 2x3 → (9,9-11) OOB
            { click_button = { id = "editor:input_rows_inc" } },
            { assert_tile  = { x = 9, y = 9 } },
        },
    },
    {
        name  = "refit source: source cleared when blocked by existing tile",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:source" } },
            { click_cell   = { 1, 1 } },
            { assert_tile  = { x = 1, y = 1, kind = "source" } },
            -- place a tile at (3,1) — outside old 2x2 footprint but within new 3x2 after inc cols
            { click_button = { id = "editor:pal:gap" } },
            { click_cell   = { 3, 1 } },
            { assert_tile  = { x = 3, y = 1, kind = "gap" } },
            -- inc cols: source tries to expand to 3x2, but (3,1) is occupied → source cleared
            { click_button = { id = "editor:input_cols_inc" } },
            { assert_tile  = { x = 1, y = 1 } },
        },
    },
    {
        name  = "click placed op with params opens popup; confirm updates tile",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:scalar_mul" } },
            { click_cell   = { 5, 5 } },
            { assert_tile  = { x = 5, y = 5, kind = "op", op = "scalar_mul" } },
            -- clicking the same cell again opens the param popup
            { click_cell   = { 5, 5 } },
            { assert_text  = "scalar_mul" },
            -- type a value and confirm
            { text_input   = "3" },
            { press        = "return" },
            -- popup is closed again
            { assert_text  = "PUZZLE EDITOR" },
        },
    },
    {
        name  = "param popup: escape cancels without changing params",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:scalar_mul" } },
            { click_cell   = { 3, 3 } },
            { click_cell   = { 3, 3 } },
            { assert_text  = "scalar_mul" },
            { press        = "escape" },
            { assert_text  = "PUZZLE EDITOR" },
        },
    },
    {
        name  = "paste full puzzle def and round-trip copy + test",
        given = { solved = {} },
        steps = {
            { click_button  = "Editor" },
            { set_clipboard = [[return {
    name   = "RoundTrip",
    grid_w = 10, grid_h = 10,
    source = { x=3, y=1 },
    sink   = { x=8, y=8 },
    locked = {
        { kind="op", op="scalar_mul", x=5, y=5, width=2, height=1, tile_rows=2, tile_cols=2, params={scalar=3} },
        { kind="op", op="transpose",  x=1, y=5 },
        { kind="op", op="scale_row",  x=1, y=1, height=4 },
    },
    gaps   = { {x=7,y=7} },
    ops    = { "transpose" },
    input  = { rows=2, cols=2, values={ {1,2},{3,4} } },
    target = { rows=2, cols=2, values={ {1,2},{3,4} } },
}]] },
            -- paste loads _load_def (covers 723-793 including tile_rows/tile_cols)
            { click_button  = { id = "editor:paste" } },
            { assert_tile   = { x = 5, y = 5, kind = "op", op = "scalar_mul" } },
            -- copy re-serializes (covers 820-876 including params/tile_rows/tile_cols/gaps/ops)
            { click_button  = { id = "editor:copy" } },
            { assert_text   = "Copied!" },
            -- test opens MatrixScene (_build_def covers 674, 685-695, 703, 718)
            { click_button  = { id = "editor:test" } },
            { assert_text   = "INPUT" },
            { click_button  = { id = "cmd:menu" } },
            { assert_text   = "PUZZLE EDITOR" },
        },
    },
}
