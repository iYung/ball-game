# Puzzle trim and difficulty ramp

## Goal

There are too many puzzles and the difficulty ramps too slowly. Ship 19 puzzles (from 29) in four worlds (from six): two easy openers, then real puzzles from the third one on. Five weak puzzles are replaced by harder ones. No brand-new additional puzzles and no code changes.

Decided with the user: 19 puzzles; harden about five existing puzzles, each with a verified solution; only two easy puzzles at the start; Identity Check stays; world unlocking is unchanged.

Defaults chosen without asking (please review):

- A substantial redesign gets a **new id**. Minor changes keep the id.
- The fixed (`!`) tools mechanic is **kept**, through a redesigned fixed-tools puzzle.
- **Sharp Left is hardened, not cut.** Cutting it would give 18 puzzles and make Corridor Cross the third level: a first-time player would jump from "place one tile on a straight line" to a corridor puzzle without ever having used a second pusher or edited k. Hardening it keeps 19, and the third puzzle teaches turning, editing k and operation order.

## Affected files

| Area | Files |
|---|---|
| Puzzles | `data/puzzles/**` (10 cut, 5 replaced, folders moved and renumbered; see below) |
| Cutscene | `data/puzzles/02_combos/cutscene.lua` (one line of text) |
| Tests | 11 unit test files and 10 UI spec files fail against the new lineup (see Test impact) |
| Docs | `README.md` |
| Code | none in `lua/` |

## What changes

### Final lineup

Difficulty is a 1-10 judgement relative to this game. Nothing has been playtested.

| # | World | id | Name | Diff | Verdict |
|--|--|--|--|--|--|
| 1 | basics | `identity` | Identity Check | 1 | keep |
| 2 | basics | `flip` | Flip It | 1 | keep |
| 3 | basics | `scale_shift` | Scale and Shift | 3 | redesign of `negate` |
| 4 | combos | `rotate_gap` | Corridor Cross | 4 | keep |
| 5 | combos | `set_row` | Staircase | 4 | keep |
| 6 | combos | `corner_case` | Corner Case | 5 | redesign of `combo` |
| 7 | combos | `top_only` | Top Only | 5 | redesign of `double_flip` |
| 8 | combos | `fold_through` | Fold Through | 7 | redesign of `triple` (moves from advanced) |
| 9 | advanced | `flip_scale` | Flip Scale Arch | 3 | keep (introduces locked tiles) |
| 10 | advanced | `locked_scale` | Locked Scale, Full Maze | 5 | keep (moves from fixed_pieces) |
| 11 | advanced | `double_negative` | Double Negative | 6 | keep (moves from transforms) |
| 12 | advanced | `add_only` | Add Only | 7 | redesign of `fixed_player` |
| 13 | advanced | `rotato` | Rotato | 8 | keep (moves from fixed_pieces) |
| 14 | two_sources | `first_sum` | First Sum | 3 | keep (introduces two sources) |
| 15 | two_sources | `take_away` | Take Away | 4 | keep, earlier |
| 16 | two_sources | `turned_sum` | Turned Sum | 5 | keep |
| 17 | two_sources | `operand_order` | Operand Order | 5 | keep |
| 18 | two_sources | `two_preps` | Two Preps | 6 | keep |
| 19 | two_sources | `merge_maze` | Merge Maze | 8 | keep, now last |

Difficulty rises within every world. It dips twice, at the first puzzle of Advanced and of Two Sources, on purpose: each introduces a new mechanic.

Cut (10): `swap`, `scale`, `row_swap`, `uturn`, `negate_swap`, `elimination`, `col_ops`, `flips`, `fixed_puzzle`, `stand_to_add`. Each repeats the maths or the idea of a kept puzzle, or (Mirror Maze) is won by pushing straight right.

### Folder layout

The `transforms` and `fixed_pieces` folders go away. The `advanced` id and its cutscene stay as the locked-tiles world; `two_sources` becomes the fourth folder.

```
data/puzzles/
  01_basics/       01_identity  02_flip  03_scale_shift
  02_combos/       cutscene  01_rotate_gap  02_set_row  03_corner_case  04_top_only  05_fold_through
  03_advanced/     cutscene  01_flip_scale  02_locked_scale  03_double_negative  04_add_only  05_rotato
  04_two_sources/  01_first_sum  02_take_away  03_turned_sum  04_operand_order  05_two_preps  06_merge_maze
```

Kept puzzle files are moved and renumbered only; their contents do not change. Comments inside them that mention old puzzle numbers may be left alone.

### The five redesigns

In the timelines, a command persists until the next one for that pusher. Commands sharing a tick go in separate lanes. "Applications" counts op firings, including one tile firing twice.

#### 3. Scale and Shift (`01_basics/03_scale_shift.lua`, replaces `negate`)

The player must find that tripling then adding 4 works, that the reverse order cannot, and steer a U-shaped route with three pushers. First puzzle to require `+k`.

```lua
-- Every value is tripled and then shifted by 4; the other order cannot reach the target.
-- Reference solution (place xk (k = 3) at (2,5), +k (k = 4) at (5,7)):
--   Pushers: A(2,1), B(1,7), C(9,9).
--   Timeline: t1 A down; t6 A stop, B right; t12 B stop, C up. WIN at t15.
return {
    name   = "Scale and Shift",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=3 },
    ops    = { "scalar_mul", "scalar_add" },
    input  = { rows=2, cols=2, values={ {0,1}, {2,3} } },
    target = { rows=2, cols=2, values={ {4,7}, {10,13} } },
    gaps   = {
        {x=5,y=1},
        {x=5,y=2},
        {x=5,y=3},
        {x=5,y=4},
        {x=5,y=5},
        {x=5,y=6},
    },
}
```

| | |
|--|--|
| Pushers | A (2,1), B (1,7), C (9,9) |
| Tiles | `xk` k=3 at (2,5); `+k` k=4 at (5,7) |
| Timeline | t1 A down; t6 A stop, B right; t12 B stop, C up |
| Result | WIN at tick **15** |

#### 6. Corner Case (`02_combos/03_corner_case.lua`, replaces `combo`)

Three edge operations that overlap at corners. The player must read the corner values to work out which edges changed and in what order.

```lua
-- Three edge ops that share corners, so their order shows in the corner values.
-- Reference solution (place +k^ (3, top) at (5,2), xk^ (2, left) at (6,3),
-- +k^ (1, bottom) at (8,6)):
--   Pushers: A(1,3), B(8,1), C(10,7).
--   Timeline: t1 A right; t6 A stop, B down; t10 B stop, C left. WIN at t13.
return {
    name   = "Corner Case",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=3, y=8 },
    ops    = { "edge_scale", "edge_add" },
    input  = { rows=3, cols=3, values={ {1,2,3}, {4,5,6}, {7,8,9} } },
    target = { rows=3, cols=3, values={ {8,5,6}, {8,5,6}, {15,9,10} } },
    gaps   = {
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},{x=6,y=5},{x=10,y=5},
    },
}
```

| | |
|--|--|
| Pushers | A (1,3), B (8,1), C (10,7) |
| Tiles | `+k^` 3 top at (5,2); `xk^` 2 left at (6,3); `+k^` 1 bottom at (8,6) |
| Timeline | t1 A right; t6 A stop, B down; t10 B stop, C left |
| Result | WIN at tick **13** |

#### 7. Top Only (`02_combos/04_top_only.lua`, replaces `double_flip`)

Both arithmetic tools are preset to the top row. The player must add before doubling, flip, then double again, so the order is enforced. First appearance of fixed tools.

```lua
-- Both preset tools only reach the top row: flip to bring the other row up.
-- Reference solution (place +3^! at (5,2), x2^! at (4,2), FLv at (2,5), x2^! at (5,7)):
--   Pushers: A(9,2), B(2,1), C(1,6).
--   Timeline: t1 A left; t6 A stop, B down; t10 B stop, C right. WIN at t15.
return {
    name   = "Top Only",
    grid_w = 10, grid_h = 10,
    source = { x=7, y=2 },
    sink   = { x=9, y=7 },
    ops    = { "flip_v" },
    fixed_ops = {
        { op = "edge_scale", params = { edge = "top", scalar = 2 } },
        { op = "edge_add", params = { edge = "top", scalar = 3 } },
    },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {6,8}, {8,10} } },
    gaps   = {
        {x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},{x=8,y=4},{x=9,y=4},{x=10,y=4},
        {x=4,y=5},{x=5,y=5},{x=6,y=5},{x=7,y=5},{x=8,y=5},{x=9,y=5},{x=10,y=5},
    },
}
```

| | |
|--|--|
| Pushers | A (9,2), B (2,1), C (1,6) |
| Tiles | `+3^!` at (5,2); `x2^!` at (4,2); `FLv` at (2,5); `x2^!` at (5,7) |
| Timeline | t1 A left; t6 A stop, B down; t10 B stop, C right |
| Result | WIN at tick **15** |

#### 8. Fold Through (`02_combos/05_fold_through.lua`, replaces `triple`)

The first gate is two rows tall and the second two columns wide, so the 2x3 matrix must be transposed between them. Three arithmetic steps must be ordered around that, and the edge to pick depends on whether the matrix is already transposed.

```lua
-- The first gate is two rows tall and the second two columns wide, so the matrix
-- must be transposed between them, and the arithmetic has to fit around that.
-- Reference solution (place -k (3) at (5,2), xk^ (-2, left) at (6,3), -k (1) at (7,2),
-- T at (10,3)):
--   Pushers: A(1,2), B(8,1), C(10,8).
--   Timeline: t1 A right; t7 A stop, B down; t12 B stop, C left. WIN at t16.
return {
    name   = "Fold Through",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=3, y=8 },
    ops    = { "transpose", "edge_scale", "scalar_sub" },
    input  = { rows=2, cols=3, values={ {1,2,3}, {4,5,6} } },
    target = { rows=3, cols=2, values={ {3,-3}, {-2,1}, {-1,2} } },
    gaps   = {
        {x=6,y=1},
        {x=6,y=4},
        {x=6,y=5},
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=10,y=6},
    },
}
```

| | |
|--|--|
| Pushers | A (1,2), B (8,1), C (10,8) |
| Tiles | `-k` 3 at (5,2); `xk^` -2 left at (6,3); `-k` 1 at (7,2); `T` at (10,3) |
| Timeline | t1 A right; t7 A stop, B down; t12 B stop, C left |
| Result | WIN at tick **16** |

#### 12. Add Only (`03_advanced/04_add_only.lua`, replaces `fixed_player`)

The goal is to take 3 off the left column using only rotate, "add 3 to the top row" and negate, all fixed. The player must discover "turn the column to the top, negate, add, negate, turn back": seven applications.

```lua
-- The only adder reaches the top row and only adds. Taking 3 off the left column means
-- turning it to the top, negating, adding, negating back and turning home.
-- Reference solution (place R90! at (4,2), x-1! at (5,2), +3^! at (6,2), x-1! at (7,2),
-- R90! at (8,2), (9,2) and (8,4)):
--   Pushers: A(1,2), B(8,1), C(10,9).
--   Timeline: t1 A right; t7 A stop, B down; t13 B stop, C left. WIN at t17.
return {
    name   = "Add Only",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=3, y=8 },
    ops       = {},
    fixed_ops = {
        "rotate_90",
        { op = "edge_add", params = { edge = "top", scalar = 3 } },
        { op = "scalar_mul", params = { scalar = -1 } },
    },
    input  = { rows=2, cols=2, values={ {5,1}, {2,7} } },
    target = { rows=2, cols=2, values={ {2,1}, {-1,7} } },
    gaps   = {
        {x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},
        {x=4,y=5},{x=5,y=5},{x=6,y=5},{x=7,y=5},{x=1,y=5},{x=2,y=5},{x=3,y=5},
        {x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},
        {x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},
    },
}
```

| | |
|--|--|
| Pushers | A (1,2), B (8,1), C (10,9) |
| Tiles | `R90!` at (4,2); `x-1!` at (5,2); `+3^!` at (6,2); `x-1!` at (7,2); `R90!` at (8,2), (9,2), (8,4) |
| Timeline | t1 A right; t7 A stop, B down; t13 B stop, C left |
| Result | WIN at tick **17** |

### Verification

All five files and solutions above were run in a scratch copy of the repo holding the full new lineup, through a temporary UI spec that opens each puzzle from level select, places pushers, drags the timeline chips, places and edits the tiles, presses Run, waits for `WIN!`, presses Continue and checks the tick count on the recap. All five passed with the ticks listed.

#### Shortcut search

Players have unlimited tiles, so the limit that geometry cannot get round is the shortest operation chain. For each redesign every chain was searched over the whole palette (every k and edge, plus fixed tools), ignoring the board. A lower bound found this way holds for any placement or route.

| Puzzle | Old minimum | New minimum | Minimal chains |
|--|--|--|--|
| Scale and Shift | 1 | 2 | one: x3, +4 |
| Corner Case | 1 | 3 | one: +3 top, x2 left, +1 bottom |
| Top Only | 2 (either order) | 4 | one: +3, x2, FLv, x2 |
| Fold Through | 3 | 4 | four, differing only in when T happens (the edge changes with it) |
| Add Only | 2 | 7 | several orderings of the same pieces: 4 rotates, 2 negates, 1 add |

"No shorter chain" was confirmed twice: with a separate C++ re-implementation and with the game's own Lua ops. The list of minimal chains comes from the C++ search (Add Only: first eight seen). The C++ search drops intermediate values beyond 100000; the Lua check has no such limit.

Routes: a search over single-cell matrix moves, requiring room for a pusher behind, gives a minimum of three straight runs for all five. For Fold Through no route exists while the shape stays 2x3, and a 3x2 matrix cannot cross the first gate, so T cannot be skipped or done only beforehand.

**Not searched:**

- Fewer pushers than the reference, by walking one pusher round to a new side.
- Fewer ticks, or fewer tiles by bouncing the matrix over one tile twice. Both are legitimate play, not bypasses of the idea.
- Diagonal pushes (two pushers at once). They still need the corner cells clear, so they should not cross a wall, but this was not searched.
- Longer alternative chains. They exist (the player may always take a longer way); only shorter ones matter.
- Every possible geometry-assisted trick in the real simulator. There is no exhaustive pusher-program search.

Geometry therefore adds routing work but never forces a tile to be reused.

### Cutscene text

World numbers and names do not change, so both title beats stay. The Combos opener says single operations are no longer enough, but Corridor Cross, now first in Combos, needs only one. In `data/puzzles/02_combos/cutscene.lua`, first beat:

- Old: `Single operations are no longer sufficient. The patterns here demand more.`
- New: `Warm-up complete. The patterns here will not yield to a straight push.`

The Advanced text ("Gaps. Locks. Constraints...") now matches its world well and is unchanged. Players who have already seen a cutscene will not see it again.

### Save data and unlocking

No code or migration change. Saves are keyed by id.

- Moved and renumbered puzzles stay solved.
- Ids of cut and replaced puzzles stay in the save and are ignored. The old-format conversion tables in `progress.lua` must not be edited.
- The five new ids start unsolved, even for players who solved the puzzle each one replaces.
- A world is open if it is first, if everything earlier is solved, or if anything in it or later is solved. So an existing player with nothing solved in a world or after it can find it locked again until the new puzzles are done. Examples: only the old Basics solved, Combos locks until Scale and Shift is solved; everything up to Fixed Pieces solved but nothing in Two Sources, Two Sources locks until the new puzzles before it are solved. A player with a solve in a world or beyond keeps it open. Accepted, since unlocking stays as is.
- Removing the `transforms` and `fixed_pieces` worlds loses no cutscene: neither had one.

### Test impact

Measured by running each test file on its own against the new lineup in the scratch copy (before any test edits). A full-suite run there also reports extra failures in otherwise passing files, apparently state left behind by failed unit tests; those pass when run alone. Coverage was not measured.

Each edit below changes an expectation because the lineup changed on purpose; CLAUDE.md rule 2 requires saying so in the PR. A file stops at its first failure, so the "also affected" notes come from reading the code.

| File | Why it breaks / what it needs |
|--|--|
| `tests/test_editor_fixed_ops.lua` | looks up `fixed_player` and `fixed_puzzle`; both expected to ship `ops = {}` (`add_only` does) |
| `tests/test_level_select.lua` | needs four rows in Basics, which now has three; use a larger world |
| `tests/test_multi_op_puzzles.lua` | chains and pinned names for cut and replaced puzzles |
| `tests/test_palette_layout.lua` | `fixed_player` palette; also `negate` |
| `tests/test_progress.lua` | `negate`, `swap`, `scale`, `row_swap`, `double_flip` positions |
| `tests/test_progress_ids.lua` | `negate`, `swap`, `negate_swap`, `row_swap`; worlds `transforms`, `fixed_pieces` |
| `tests/test_progress_migration.lua` | reads loaded saves back through live puzzle ids, so removed ids vanish; needs a synthetic puzzle listing that keeps the old ids |
| `tests/test_pusher_scene.lua` | `swap` (the `locked_scale` checks are unaffected) |
| `tests/test_two_source_data.lua` | pins the first four Two Sources puzzles in the old order |
| `tests/test_two_source_prep_data.lua` | `stand_to_add` cut |
| `tests/test_worlds.lua` | `fixed_player`; at least five worlds; `transforms` and `fixed_pieces` |
| `tests/ui/02_level_select_keyboard.lua` | `negate` and its neighbouring rows (the new third puzzle is last in its world) |
| `tests/ui/03_world_locking.lua` | `row_swap`, "Z-Bend" |
| `tests/ui/06_cutscene.lua` | expects "Ordered Ops" on the Combos screen |
| `tests/ui/06_solve_routed_puzzle.lua` | solves "Sharp Left" |
| `tests/ui/08_matrix_scene_ops.lua` | `fixed_pieces` world, `fixed_player` |
| `tests/ui/11_transpose_refire.lua` | `negate`, `swap`, `scale` ("Squeeze Bend"): needs another transpose setup |
| `tests/ui/13_solve_converted.lua` | solutions for cut puzzles go; moved ones change world; add the five new solutions (CLAUDE.md rule 1) |
| `tests/ui/18_folder_worlds.lua` | world table, cut puzzle ids |
| `tests/ui/25_rotato.lua` | world is now `advanced` |
| `tests/ui/27_two_source_prep.lua` | `stand_to_add` cut |

Cut puzzles that carried unique test behaviour (the transpose re-arm regression in particular) must keep that coverage on another puzzle or a test-local definition.

### README

`README.md`:

- Introduction: 19 puzzles in four worlds.
- Level select section: world names are Basics, Combos, Advanced, Two Sources.
- The "29 puzzles ship with the game" paragraph: rewrite for the new lineup; drop "puzzle 19"; fixed tools now appear in Top Only and Add Only, Rotato is the last Advanced puzzle.
- Adding levels: the example tree uses `06_row_swap.lua` and the folder-name example uses `05_fixed_pieces`; use files that exist.

## What stays the same

- All game code, ops, palette behaviour, sim rules, save format and world unlock rule.
- The contents of the 14 kept puzzles, including Identity Check and Flip It.
- The intro cutscene and the Advanced cutscene.
- Existing constraints: every source is off the grid edge, at most 10 puzzles per world, every puzzle has a name and a world folder, two-source layouts are unchanged. All new sinks are above row 10, which the status banner covers.

## Open questions

None block implementation. Worth a look at review:

1. Sharp Left becomes Scale and Shift (19 puzzles) rather than being cut (18).
2. Flip Scale Arch (3) and First Sum (3) are easy openers to their worlds, right after harder puzzles. They are kept as mechanic introductions.
3. Fixed tools now first appear in Combos (Top Only), before locked tiles in Advanced.
4. The new Combos cutscene line.
5. The five redesigns are verified solvable but not playtested; difficulty numbers are estimates.
