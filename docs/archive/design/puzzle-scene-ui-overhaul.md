# Puzzle Scene UI Overhaul

## Goal

Re-layout the puzzle scene (`MatrixScene`) in the style of a factory-programming game (reference: the Opus Magnum-like screenshot):

- **Matrix ops on the left** — a column of draggable op tiles, dragged onto the grid.
- **Timeline is the whole bottom bar** — 4 command lanes (rows) x up to 60 ticks (columns), scrolls horizontally.
- **Pusher instructions bottom-left** — a pusher selector on top, then `up / down / left / right / stop` chips. Chips are dragged onto the timeline.
- **Pushers keep doing a command until told otherwise** — a command is a state change, not a one-tick action.
- **Run controls bottom-right** — Run (start), Reset, Menu, Continue (on win).

## Decisions already made (from the user)

1. Timeline does **not** loop. Commands persist across empty slots and after the last slot; the final command is held.
2. The 4 rows are **command lanes, not pusher rows**. A tick can hold up to 4 commands, aimed at any pushers. 60 is the max number of ticks (columns).
3. The selector at the top of the instruction palette picks one of the pushers **already placed on the board**. A chip dragged onto the timeline is stamped with that pusher's letter (e.g. `B ↑`). Not tied to rows.
4. Matrix ops are dragged onto the board; pusher instructions are dragged onto the timeline.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — layout constants, palette/op column, instruction palette, timeline panel, drag handling, `ui_elements()`, `start_run`, `do_step`, status/stuck rules
- `lua/game/pusher_sim.lua` — pusher state (current direction) and per-tick command application
- `lua/game/scenes/solution_recap_scene.lua` — replays the run from `board.timeline`; must read the new timeline format
- `lua/game/hud.lua` — HUD rectangle moves/resizes (matrix display on the right)
- `lua/headless/ui_runner.lua` — drag helpers if a drag-to-timeline step is needed
- `tests/*.lua`, `tests/ui/*.lua` — specs that reference `slot:`, `tl:`, `palette:`, `CELL_SIZE`, `PALETTE_Y`, `timeline`, `cmds` (see "What changes → tests")
- `docs/pusher-physics.md`, `README.md` — command-persistence wording (verification phase only)

## What changes

### Layout (1280x720)

```
+--------+------------------------------+----------------------+
| OPS    |  10x10 grid (cell ~52px)     |  HUD: input/current/ |
| column |                              |  target matrices     |
| (drag) |                              |                      |
+--------+------------------------------+----------------------+
| PUSHER | TIMELINE: 4 lanes x 60 ticks, horizontal scroll     | RUN  |
| select | tick header, current-tick marker                    | RESET|
| ^ v < >| (cells show "<pusher letter> <arrow>")              | MENU |
| stop   |                                                     |      |
+--------+-----------------------------------------------------+------+
```

- Bottom bar roughly 180px high, so the grid shrinks from 63px to about 52px cells. Grid origin moves right to clear the ops column.
- Ops column on the left: all op buttons plus `Mv` (move) and `[X]` (erase), scrollable if it overflows. The current `P` (place pusher) button stays here, because placing a pusher on the board is a grid placement.
- Ops are **dragged** from the column onto a grid cell. Click-to-select then click-cell keeps working so existing behavior and tests stay valid.

### Timeline model

- `self.timeline[lane][tick] = { pusher = id, cmd = "up"|"down"|"left"|"right"|"stop" }`, lanes 1-4, ticks 1-60.
- Dragging a chip onto a cell writes it; dropping on an occupied cell replaces it; right-click or dragging it off removes it.
- One command per pusher per tick: if the same pusher already has a command in that tick (other lane), the new drop replaces that one rather than creating a conflict.
- The length-control buttons (`-`/`+`) go away; the timeline is a fixed 60 columns. Horizontal scroll buttons / mouse wheel scroll it; the run auto-scrolls to follow the current tick.

### Simulation

- Each pusher has a persistent `dir` (initially `stop`).
- At the start of tick *t*, every command in column *t* sets its pusher's `dir`. Then the existing `Sim.advance` physics runs with each pusher stepping in its `dir`.
- `stop` sets `dir` to none. A pusher with no command ever stays stopped.
- Walls/other pusher/gap: pusher stays put but **keeps** its `dir` (it will push again once something clears). Matrix-conflict rules from `docs/pusher-physics.md` are unchanged.
- End-of-run rules: sink reached → win/fail as before; blocked as before; `MAX_TICKS` timeout as before. "Stuck" now means: all commands have been issued (tick > last used column) and a tick moved nothing.

### Run controls

- Run/Reset/Menu/Continue move to bottom right with the same enable rules (`_cmd_enabled`). Existing status banner stays, repositioned above the bottom bar.

### UI registry

- Every new element is in `ui_elements()` and hit-tests through `UI.element_at`: ops column buttons, pusher selector buttons, instruction chips, timeline cells (`slot:<lane>:<tick>`), scroll buttons. Drags are driven through `mouse_pressed`/`mouse_released` the same way `tests/ui/07_drag_drop.lua` does today.

### Tests

The old model (per-pusher rows, looping, cycling slots by click) is replaced, so specs that exercise `slot:A:n` cycling and `tl:dec/inc` cannot keep their old expectations. Per `CLAUDE.md` rule 2 each rewritten expectation will be listed in the verification report with the reason. All puzzle-solving specs (`01`, `04`, `06`) keep their goal (puzzle gets solved) but program the timeline with the new chips. Puzzle data and solutions in `tests/` that rely on `cmds` per tick need translating to command-on-change form.

## What stays the same

- Matrix math, op semantics, grid, gaps, source/sink, puzzle data files (`data/puzzles/*`).
- Pusher collision/force rules (`docs/pusher-physics.md`): dedupe, opposing = blocked, diagonal corner checks, landing rules.
- Level select, world locking, cutscenes, settings menu, progress/save format.
- Solution recap flow (Continue button -> recap); only its timeline input format changes.
- Music handling.

## Open questions

None blocking. Defaults I picked that you can veto at review:

1. Placing a chip for a pusher that already has a command that tick **replaces** it (not an error).
2. Ops column and pusher/erase tools are shown as a scrollable column if the full op set does not fit in about 520px of height.
3. Saved/WIP timeline state (if any exists in the save file) from the old format is dropped, not migrated. I'll confirm in the checklist phase whether anything is persisted.

## Implementation notes (added at verification)

- The `timeout` status and `MAX_TICKS = 500` were removed. With persistent commands and a 60-tick timeline a run always ends as stuck, blocked, win or fail first, so the path was unreachable.
- Run-button layout is a 2x2 block bottom-right; the ops column is 2 buttons wide and scrolls with `palette:scroll_up/down`.
- Mouse-wheel scrolling of the timeline is not implemented (no scene receives `wheelmoved`); scroll buttons only.
