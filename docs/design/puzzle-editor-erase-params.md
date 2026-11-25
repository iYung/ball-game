# Puzzle editor: visible erase tool and on-tile parameter editing

## Goal

User request: "puzzle editor needs a clear option to remove placed tiles that i can click / also no modals / i also need to be able to modify the params of operations i place".

1. A visible, clickable **Erase** tool. There is no Clear All button.
2. **No modals.** Parameters are edited on the tile, as in game. The typed-value popup is removed.
3. Everything the game lets a player edit is editable in the editor: row, column and scalar params; values of `add_matrix`, `sub_matrix`, `mul_matrix`, `set_row` and `set_col`; and resizing of the tiles that can grow.
4. What the author sets survives Test, Copy and Paste.

### Current state

- **The palette overflows.** `_layout_palette` drops any button that would pass x = 810. `add_cols`, `set_col`, `rotate_90`, `flip_h`, `flip_v`, `abs` and the `[X]` erase button are never shown or registered.
- **Popup.** A left click on any cell of an op with params opens `ParamPopup`, whatever tool is selected, so left-click erase could not remove those tiles even if the button were visible. The popup has no fields for the column ops or `set_row`, and cannot edit values.
- **Defaults are incomplete.** Placed tiles have no `values`, `tile_rows` or `tile_cols`, so `mul_matrix` multiplies by 0 in Test (the in-game default is 1). Footprints come from a fixed size table.
- **`values` is lost everywhere.** `_build_def`, `_serialize` and `_load_def` all ignore it. `_serialize` also omits `width` and `height`, which `_build_def` includes.

## Affected files

| File | Change |
|---|---|
| `lua/game/scenes/editor_scene.lua` | Palette layout, erase, click rules, on-tile editing and drawing, resize, defaults, export and import, popup removal |
| `lua/game/op_tiles.lua` (new, name open) | Op tile logic and drawing shared by the editor and the puzzle scene |
| `lua/game/scenes/matrix_scene.lua` | Delegates param clicks and param cell drawing to the shared module. No behaviour change. Also copies pusher `id` (open question 1) |
| `lua/game/param_popup.lua` | Delete (the editor is its only user) |
| `tests/test_param_popup.lua` | Delete |
| `tests/ui/12_editor.lua` | Replace the two popup specs; add specs for the new behaviour |
| `tests/test_*.lua` (new) | Unit tests for the shared module and the export/import round trip |
| `lua/headless/ui_runner.lua`, `tests/test_ui_runner.lua`, `docs/testing.md` | Resize element kind (open question 2) |
| `README.md` | Verification phase, if it describes the editor |

## What changes

### Palette and erase tool

- All 23 buttons (SRC, SNK, GAP, P, 18 ops, Erase) are visible and in `ui_elements()` at once, without scrolling. They stay within 1280x720 and overlap neither each other nor the command buttons, which start at x = 820. One compact row fits (about 30px per button, smaller separators, a wider Erase button). The overflow filter that silently drops buttons goes away, so an overflow would fail the layout invariant or a spec instead of hiding a button.
- The erase button is labelled `Erase`, keeps the id `editor:pal:erase`, and is highlighted while selected.

### Click rules on the grid

| Selected | Left click on empty cell | Left click on any placed tile | Right click on any cell of a tile |
|---|---|---|---|
| Erase | nothing | erase the whole tile | erase the whole tile |
| Any placement tool | place it | param cell: edit. Anything else: nothing | erase the whole tile |
| Nothing | nothing | param cell: edit. Anything else: nothing | erase the whole tile |

- Erase works from any cell of a multi-cell tile, including source, sink, gap and pusher tiles.
- A placement tool never replaces or overwrites a tile. This differs from the game, which replaces an unlocked tile when you click a non-param cell. The editor already refuses this for ops, gaps and pushers. The sink tool must refuse too: it currently writes over any cell, which would corrupt a multi-cell tile once the popup no longer intercepts those clicks. Clearing the old sink when a new one is placed stays.
- A right click on a resize strip acts on the cell underneath.
- All editor tiles stay `locked = true`, because that is what the exported puzzle needs. The editor ignores `locked` when deciding what it may edit, resize or erase. Tiles are drawn with the editable colours and `-`/`+` marks.

### On-tile editing

Click targets and limits match the game. "Thirds" means the left third decrements, the right third increments and the centre does nothing. Values and scalars are limited to -9..9.

| Op | Footprint (cols x rows) | Editing | Resize |
|---|---|---|---|
| `scalar_mul` | 2x1 | cell 2: scalar, thirds | none |
| `scale_row` | 1 x `tile_rows` (starts 4) | click a band to select the row; thirds on the selected band change the scalar | rows 1-4 |
| `scale_col` | `tile_cols` (starts 4) x 1 | same, for columns | cols 1-4 |
| `swap_rows` / `swap_cols` | 1x2 / 2x1 | each cell: thirds, 1-4, the two may not be equal | none |
| `add_rows` / `add_cols` | 4x1 | cells 2-4: source, destination, scalar; thirds | none |
| `set_row` | (1 + `tile_cols`) x 1, starts 1 col | first cell: row, thirds; other cells: values | cols 1-4 |
| `set_col` | 1 x (1 + `tile_rows`), starts at input row count | first cell: column, thirds; other cells: values | rows 1-4 |
| `add_matrix`, `sub_matrix`, `mul_matrix` | `tile_cols` x `tile_rows`, starts 1x1 | every cell: value, thirds | rows and cols 1-4 |
| `transpose`, `negate`, `rotate_90`, `flip_h`, `flip_v`, `abs` | 1x1 | none | none |

- New tiles get the game's default params and values (`add`/`sub`/`set` fill 0, `mul` fills 1). A newly grown row or column uses the same fill.
- Each tile shows its current values on its cells, and still shows which op it is.
- Footprint always equals what the table says, at placement, after resize and after import. A placement that does not fit in free, in-bounds cells is refused.
- Shrinking drops the removed values. Shrinking `scale_row` or `scale_col` also pulls the selected band back inside the tile.

### Param ranges and input matrix size

- The upper limit for `add_rows` source and destination and for the `set_row` row is the current input row count. For `add_cols` source and destination and the `set_col` column it is the current input column count.
- Swap indices stay 1-4 and scale bands are limited by tile size, as in game.
- Limits are read live from this editor's input matrix. Changing the input size or pasting a puzzle never rewrites stored params. The next `-` or `+` click on an out-of-range value brings it into range. Runtime already tolerates such values (clamped, or no effect for `set_row`).
- The starting size of `set_col` follows the input row count at placement time only. Later input resizes do not change placed tiles.
- The shared logic takes the dimensions as an argument. It must not mutate a module-level limits table, as `MatrixScene.load_puzzle` does today.

### Resize strips

- A resizable tile shows `+` and `-` strips as in game. They are hidden while Erase is selected, so every cell of a tile erases.
- Each visible strip is an element in `ui_elements()` (kind `resize`, id naming the anchor and action), listed before the grid cells so hit-testing finds it first. Clicks go through `UI.element_at`.
- A `+` strip exists only when the size is below 4 and every newly covered cell is in bounds and empty. The game does not check this and can overwrite neighbours. It also means no strip ever leaves the grid or reaches the palette. A `-` strip exists only when the size is above 1.
- Strips must not overlap each other and must leave the centre and the `-`/`+` thirds of value cells clickable. Geometry, in fractions of a cell (open question 3):
  - grow cols: left third of the free column to the right, over the tile's height
  - grow rows: top third of the free row below, starting one third in from the left (avoids the corner shared with a neighbour's grow-cols strip)
  - shrink cols: right third of the top quarter of the top-right tile cell
  - shrink rows: middle third of the bottom quarter of the bottom-left tile cell
- The lock icon must not sit under a strip; drop or move it in the editor.

### Export and import

- Copy, Test and Paste preserve `params`, `values`, `tile_rows`, `tile_cols` and the footprint (`width`, `height`) for every tile. `values` is a nested table and is copied, not shared.
- The clipboard text and the Test table describe the same tiles. Building both from one source prevents further drift.
- On import, an explicit `width`/`height` wins (as in `MatrixScene`). Otherwise the footprint is derived from the op and `tile_rows`/`tile_cols`, so existing puzzle files such as `23_locked_scale.lua` (`tile_rows=1`) load with the right size.
- Missing fields in older text are filled with what the game would do at runtime, not with new-tile defaults: sizes 1, except `scale_row`/`scale_col` 4; values 0 (also for `mul_matrix`); params as `Sim.apply_op` assumes them (indices 1, second index 2, scalar 1).

### Sharing with MatrixScene

Recommendation: share what is correct and identical, keep the rest separate.

- **Move to the shared module:** op symbols, default params, param limits (given matrix dimensions), "apply this click to this tile cell", and the param and value cell drawing (given cell rect, fonts and an editable flag, since cell size is 52 in game and 63 in the editor). These are the bulk of the code and would drift if copied. Existing tests and `tests/ui/08_matrix_scene_ops.lua` cover them and must pass unchanged.
- **Keep separate:** default tile construction, footprint calculation, resize mutation and strip layout. The game versions have bugs (wrong footprints for `scale_col` and `set_col` at placement and for `set_row` after growing; growing overwrites neighbours) and rely on `locked`/`Grid:clear` semantics that block editor use. Sharing them would either copy the bugs or change game behaviour. The editor gets correct versions in the shared module; `MatrixScene` can adopt them in a separate fix.
- `MatrixScene` private methods and fields used by existing tests (`_place_tile_at`, `_resize_tile`, `_expand_rects`, `draw_*`) keep working.

### Tests

- Deleting `tests/test_param_popup.lua` is legitimate: it tests only `ParamPopup`, which the user asked to remove, and nothing else uses the module.
- The specs "click placed op with params opens popup; confirm updates tile" and "param popup: escape cancels without changing params" assert the removed behaviour (popup text, typing, Enter, Esc). They are replaced by specs for on-tile editing. The verification report must say so.
- New UI specs, driven by real input: Erase visible, selectable and erasing a multi-cell tile from a non-anchor cell; every palette button present; param and value edits asserted by drawn text; each resize direction by clicking its strip element; a blocked grow offers no strip; Copy then Paste keeps edits.
- `assert_text` is a weak check for single digits and specs cannot read the clipboard, so exact round-trip fidelity needs unit tests.
- CI requires 100% line coverage of `lua/game/`, including the new module.
- Rendering at the new button size and tile layout needs a manual check with `love .` or the web preview.

## What stays the same

- `MatrixScene` behaviour in play, including its resize strips remaining unregistered.
- Puzzle data files and the def format (only fields the game already reads).
- Editor HUD: name field, matrix editors and their click behaviour, op allowlist.
- Command buttons, Escape, name typing, source refit on input resize.
- Selecting a tool and placing source, sink, gap, pusher and ops.
- Right-click erase.

## Open questions

All resolved: the user approved the design with every recommended answer.

1. **Test crashes whenever a pusher is placed.** The def carries no pusher `id` and `MatrixScene.load_puzzle` does not copy one; reproduced as errors at `matrix_scene.lua:691` (two pushers) and `:1569` (one). Paste also loses ids. **Resolved: fix it here**, as its own checklist task (export and import `id`, assign a free one A-H when missing, limit to 8, copy it in `load_puzzle`).
2. **Registering resize strips.** Strips lie on grid cells. **Resolved: register them** as kind `resize`; the runner allows overlap only between `resize` and `cell`, all other overlaps still fail. Includes a runner unit test and a `docs/testing.md` update.
3. **Strip geometry.** The game's strips cover part of the `+` third and the bottom `-`/`+` marks. **Resolved: use the proposed geometry in the editor only**, so strips do not cover the value `-`/`+` zones. The game is unchanged.
4. **Param ranges on input resize.** **Resolved: non-destructive.** Stored params are not rewritten; the next click clamps. As in game, the limits ignore dimension changes mid-run (for example after `transpose`).
5. **Typed values.** **Resolved:** new edits are whole numbers in -9..9. Imported values outside the range are kept until clicked.
