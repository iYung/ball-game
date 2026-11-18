## Goal

Change the direction cycling order when programming pusher slots from linear (up → down → left → right) to clockwise (up → right → down → left), so the cycle feels spatially intuitive.

## Affected files

- `game/scenes/matrix_scene.lua` — line 65, `CMD_ORDER` constant

## What changes

`CMD_ORDER` on line 65 currently reads:

```lua
local CMD_ORDER = { "idle", "up", "down", "left", "right" }
```

It becomes:

```lua
local CMD_ORDER = { "idle", "up", "right", "down", "left" }
```

`CMD_ORDER` drives `cycle_cmd()` (line 852), which is called when the player left- or right-clicks a timeline slot to step through available commands. Reordering it makes the click cycle follow compass-clockwise order: idle → up → right → down → left → idle → …

## What stays the same

- The glyphs (`CMD_GLYPH`), arrow labels (`DIR_ARROWS`), and all simulation logic are unaffected.
- Existing saved puzzles with already-programmed pushers are unaffected — the commands stored are strings like `"up"`, `"right"`, etc., not positional indices.
- All tests remain valid; they test movement outcomes, not slot-cycling order.

## Open questions

None — change is self-contained.
