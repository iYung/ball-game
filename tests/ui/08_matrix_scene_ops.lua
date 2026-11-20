-- tests/ui/08_matrix_scene_ops.lua
-- Exercises op-tile parameter cell clicks in MatrixScene:
--   add_matrix value cell, scalar_mul ref cell (generic PARAM_DEFS path),
--   set_row anchor (dc=0) and value cell (dc=1),
--   set_col param (dr=0) and value cell (dr=1),
--   scale_col band-select then scalar adjust,
--   swap_cols strip left/right inc/dec.
--
-- Puzzle 1 has no `ops` restriction so all palette buttons are shown.
-- Puzzle 18 (world 4) restricts to swap_cols and scale_col.

return {

    -- ── Spec 1: add_matrix value cell + scalar_mul generic PARAM_DEFS path ──
    {
        name  = "add_matrix value cell and scalar_mul param ref cell",
        given = { solved = {} },
        steps = {
            { press = "return" },
            { click_button = { id = "puzzle:1" } },
            { assert_text = "Identity Check" },

            -- add_matrix is 1×1; value cell is the tile itself (dc=0, dr=0).
            { click_button = { id = "palette:add_matrix" } },
            { click_cell = { 5, 1 } },
            { assert_tile = { x=5, y=1, kind="op" } },
            { click_cell = { 5, 1, part="left"  } },  -- dec value[1][1]
            { click_cell = { 5, 1, part="right" } },  -- inc value[1][1]

            -- scalar_mul is 2×1; ref cell (dc=1) is handled by the generic
            -- PARAM_DEFS elseif-is_r branch (lines ~2058–2075).
            { click_button = { id = "palette:scalar_mul" } },
            { click_cell = { 5, 2 } },
            { assert_tile = { x=5, y=2, kind="op" } },
            { click_cell = { 6, 2, part="left"  } },  -- ref dc=1 → dec scalar
            { click_cell = { 6, 2, part="right" } },  -- inc scalar
        },
    },

    -- ── Spec 2: set_row anchor (dc=0) and value cell (dc=1) ─────────────────
    {
        name  = "set_row anchor param and value cell clicks",
        given = { solved = {} },
        steps = {
            { press = "return" },
            { click_button = { id = "puzzle:1" } },
            { assert_text = "Identity Check" },

            -- set_row is 2×1: anchor at (5,1), ref at (6,1).
            { click_button = { id = "palette:set_row" } },
            { click_cell = { 5, 1 } },
            { assert_tile = { x=5, y=1, kind="op" } },

            -- Anchor (dc=0): row selector — left/right dec/inc the row param.
            { click_cell = { 5, 1, part="left"  } },
            { click_cell = { 5, 1, part="right" } },

            -- Ref cell (dc=1): value dec/inc.
            { click_cell = { 6, 1, part="left"  } },
            { click_cell = { 6, 1, part="right" } },
        },
    },

    -- ── Spec 3: set_col param cell (dr=0) and value cell (dr=1) ─────────────
    {
        name  = "set_col param and value cell clicks",
        given = { solved = {} },
        steps = {
            { press = "return" },
            { click_button = { id = "puzzle:1" } },
            { assert_text = "Identity Check" },

            -- set_col is 1×2: anchor at (5,1), ref at (5,2).
            { click_button = { id = "palette:set_col" } },
            { click_cell = { 5, 1 } },
            { assert_tile = { x=5, y=1, kind="op" } },

            -- Anchor (dr=0): col-param selector.
            { click_cell = { 5, 1, part="left"  } },
            { click_cell = { 5, 1, part="right" } },

            -- Ref cell (dr=1): value dec/inc.
            { click_cell = { 5, 2, part="left"  } },
            { click_cell = { 5, 2, part="right" } },
        },
    },

    -- ── Spec 4: scale_col band-select + scalar, swap_cols strip clicks ───────
    -- Puzzle 18 (Column Work) restricts the palette to scale_col and swap_cols.
    -- Requires worlds 1–3 complete to unlock world 4.
    {
        name  = "scale_col band select and scalar, swap_cols strip clicks (puzzle 18)",
        given = { solved = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16} },
        steps = {
            { press = "return" },
            { click_button = { id = "world:next" } },  -- world 1 → world 2
            { click_button = { id = "world:next" } },  -- world 2 → world 3
            { click_button = { id = "world:next" } },  -- world 3 → world 4
            { click_button = { id = "puzzle:18" } },
            { assert_text = "Column Work" },

            -- scale_col is 4×1; place at (4,1) → cells (4,1)…(7,1).
            { click_button = { id = "palette:scale_col" } },
            { click_cell = { 4, 1 } },
            { assert_tile = { x=4, y=1, kind="op" } },

            -- Click (5,1): dc=1, band=2; default params.col=1 → band≠col →
            -- band-select branch: params.col becomes 2.
            { click_cell = { 5, 1 } },

            -- Click (5,1) again: now band=2 == params.col=2 → scalar-adjust.
            { click_cell = { 5, 1, part="left"  } },  -- dec scalar
            { click_cell = { 5, 1, part="right" } },  -- inc scalar

            -- swap_cols is 2×1; place at (4,2) → cells (4,2),(5,2).
            { click_button = { id = "palette:swap_cols" } },
            { click_cell = { 4, 2 } },
            { assert_tile = { x=4, y=2, kind="op" } },

            -- Strip 2 (dc=1, key=col_b): inc from 2 → 3; 3≠col_a(1) → allowed.
            { click_cell = { 5, 2, part="right" } },
            -- Strip 1 (dc=0, key=col_a): inc from 1 → 2; 2≠col_b(3) → allowed.
            { click_cell = { 4, 2, part="right" } },
            -- Strip 1 again: dec from 2 → 1; 1≠col_b(3) → allowed.
            { click_cell = { 4, 2, part="left"  } },
        },
    },
}
