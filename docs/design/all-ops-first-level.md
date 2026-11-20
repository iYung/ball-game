# All Ops on First Level

## Goal
Make puzzle 01 (Identity Check) show every operation in the palette so developers and playtesters can quickly reach any op tile without navigating to a later puzzle.

## Affected files
- `data/puzzles/01_identity.lua`

## What changes
`01_identity.lua` currently sets `ops = {}` (empty table), which causes `_build_palette` to build an `allowed` set with nothing in it, hiding all op buttons.

Removing the `ops` field entirely (or setting it to `nil`) leaves `allowed = nil`, which the existing `_build_palette` logic already interprets as "show all ops".

No other files need to change — the palette-building logic in `lua/game/scenes/matrix_scene.lua` already handles the nil case correctly.

## What stays the same
- Puzzle name, grid size, source/sink positions, input matrix, target matrix — all unchanged.
- The puzzle remains trivially solvable (input = target = identity) so the matrix passes through to the sink with no ops placed, which is fine for a testing context.
- All other puzzles are unaffected.

## Open questions
None — the existing palette logic already supports this; the only change is removing one field from one puzzle file.
