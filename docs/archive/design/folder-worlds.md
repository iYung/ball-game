# Worlds from folder layout

## Goal

Adding a level means putting one file in the right folder. The game finds it and
places it in the right world and order. No Lua list needs editing. Text copied
from the puzzle editor works as that file unchanged.

## Folder layout

```
data/
  cutscenes/world_0.lua          game intro (unchanged)
  puzzles/
    01_basics/
      01_identity.lua
      ...
      05_scale.lua
    02_combos/
      cutscene.lua               was data/cutscenes/world_2.lua
      06_row_swap.lua
      ...
    03_advanced/
      cutscene.lua               was data/cutscenes/world_3.lua
      ...
    04_transforms/
    05_fixed_pieces/
```

Rules:

- Each folder in `data/puzzles/` that holds at least one puzzle is a world.
  Empty folders are ignored.
- The number prefix (`NN_`) sets the order, compared as a number. Gaps are
  allowed. Entries without a prefix come after numbered ones, alphabetically.
  Equal numbers are ordered by name.
- World name = folder name without the prefix, `_` as space, each word
  capitalised (`05_fixed_pieces` is "Fixed Pieces").
- Puzzle display name stays the `name` field in the file.
- Every `.lua` file in a world folder is a puzzle, except `cutscene.lua`.
  Other files are ignored.
- **Puzzle id** = filename without prefix and `.lua` (`identity`). **World id**
  is the same for the folder (`basics`). Both must be unique across the game;
  a duplicate is an error naming both paths.
- A puzzle file directly in `data/puzzles/` belongs to no world. A test fails
  on it so it cannot go unnoticed.

The 21 shipped puzzles keep their filenames, order, worlds and names.

## Affected files

| File | Change |
|---|---|
| `data/puzzles/**`, `data/cutscenes/world_{2,3}.lua` | Move into world folders |
| `lua/game/puzzle_loader.lua` | Discover worlds and puzzles from folders |
| `lua/game/progress.lua` | Save by id, convert old saves, new unlock rule |
| `lua/game/scenes/cutscene_scene.lua`, `level_select_scene.lua` | Take a world's cutscene from its folder |
| `lua/game/scenes/editor_scene.lua` | Keep `fixed_ops` through Paste, Copy and Test |
| `scripts/build_web.sh` | Expected unchanged (zips both folders recursively); verify |
| `tests/` | New loader, save and editor tests; update old ones listed below |
| `README.md`, `docs/testing.md` | How to add a level |

## What changes

### Loader

`PuzzleLoader` scans with `love.filesystem.getDirectoryItems`, replacing both
hardcoded tables. The public functions (`load(n)`, `count()`, `world(w)`,
`world_count()`) keep their shape: `n` is the position in the flattened order,
so level select, "Next puzzle" and `Puzzle N/total` need no rework. It gains a
way to get a puzzle's id, a world's id and a world's cutscene path.

### Saves

Positions shift when a level is inserted, so the save stores ids (version 3):

```lua
return {version=3,solved={"flip","identity"},cutscenes={0,"combos"}}
```

- Version 2 and unversioned saves are converted on load through a fixed table of
  today's 21 puzzles and 5 worlds (unversioned ones still go through the old
  23-to-21 remap first). The table never changes when levels are added.
- Ids with no matching file are kept, so a temporarily removed level stays
  solved when it returns.
- `mark_solved(n)` and `is_solved(n)` still take positions.
- The intro cutscene stays `0`.

Moving or renumbering a puzzle keeps its solved mark. Renaming it resets it.

### Unlocking

A world is open if it is first, if every puzzle in all earlier worlds is solved,
**or if any puzzle in it or a later world is solved**. Adding a level to an early
world therefore never locks players out of where they had been.

Limit: a player who had opened a world but solved nothing there will find it
locked again until they solve the new level.

### Cutscenes

A world's cutscene is `cutscene.lua` in its folder, and "seen" is remembered by
world id. As today, the first world's cutscene does not play on tab switch.

### Editor

Copy already produces the puzzle file format, so the workflow is: Copy, create
`data/puzzles/<world>/<NN>_<id>.lua`, paste. There are two gaps, both hit by
puzzles 19 and 20: Paste drops `fixed_ops`, and an empty `ops = {}` ("no
editable tools") is copied back as omitted ("all tools"). The editor will carry
both through Paste, Copy and Test. It gets no controls for editing fixed tools;
clicking any tool toggle replaces the empty list.

## What stays the same

- Puzzle file contents and cutscene file format.
- Level select, game and recap screens.
- Clipboard is the only export; no file is written by the editor.
- Paste still reads text as data and never runs it.

## Limits

- A world fits **10 puzzles** on the level select screen (the largest has 6
  today). A test fails above 10; scrolling is not part of this feature.
- World tabs share the screen width, so long names get tight beyond about 8
  worlds.
- A new level needs a game restart (or a web rebuild) to appear.

## Existing tests that must change

- `tests/test_def_parser.lua` lists `data/puzzles` as a flat folder.
- `tests/test_progress_migration.lua` asserts the exact version 2 save text.

Both expectations become wrong by design. Tests that pin the shipped worlds and
the count of 21 (`tests/test_puzzle_data.lua`, `tests/test_world_select.lua`)
are relaxed to structural checks. Other tests and specs that find puzzles by
position are changed to find them by filename, with the same assertions, so that
a level can be inserted anywhere without breaking CI. Any other old test that
fails points to a bug in the change.

## Open questions

None. Saves by filename, cutscenes in world folders, clipboard-only export and
the unlock rule were confirmed.
