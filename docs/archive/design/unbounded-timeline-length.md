# Unbounded pusher timeline length with horizontal scroll

## Goal

Remove the hard cap of 16 slots on the pusher timeline. The player can grow the
loop as long as they like, up to the existing 500-tick simulation ceiling
(`MAX_TICKS`). Because 16+ slots no longer fit in the fixed panel width, the
timeline gains a horizontal scroll so the player can reach any slot.

## Affected files

- `game/scenes/matrix_scene.lua` — all timeline layout, draw, click, and scroll logic

## What changes

### 1. Remove `MAX_N = 16`

`TL.MAX_N` is replaced by `MAX_TICKS` (already defined as `500`). The `+`
length button increments without bound up to `MAX_TICKS`.

```lua
-- before
local TL = { ..., MAX_N=16, ... }
-- after
local TL = { ..., MAX_N=MAX_TICKS, ... }   -- or just reference MAX_TICKS directly
```

### 2. Add `timeline_scroll` state

A new integer field `self.timeline_scroll = 0` on `MatrixScene` tracks how many
slots are scrolled off the left. It is reset to 0 when a run starts or the
timeline length is decreased below the current scroll position.

### 3. Compute visible slot count from available width

`_timeline_layout` currently computes all `timeline_n` slot rects. After this
change it computes only the rects for the visible window:

```
slot_area_x     = x0 + TL.LABEL_W            -- 866
slot_area_width = len_x - slot_area_x         -- ~316 px
visible_count   = floor(slot_area_width / (TL.SLOT_W + TL.SLOT_GAP))  -- ~13
first_slot      = self.timeline_scroll + 1
last_slot       = min(first_slot + visible_count - 1, self.timeline_n)
```

Each rect carries the actual slot index `s` (not a local 1-based index) so
click handling needs no offset arithmetic.

### 4. Scroll buttons `<` / `>`

Two small buttons are added to the timeline header row, flanking the slot area:

- `<` at `(slot_area_x - 20, top)` — scrolls left by 1 (clamped to 0)
- `>` at `(len_x - 20, top)` — scrolls right by 1 (clamped so the last slot
  stays visible)

They are greyed-out when scrolling in that direction is not possible.

### 5. Auto-scroll during a run

When the simulation is running and `cur_slot` falls outside the visible window,
`timeline_scroll` is nudged so `cur_slot` stays visible (scroll right) or the
window rewinds when the loop wraps (scroll to 0).

### 6. Clipping

`draw_timeline` sets a scissor rect over the slot area
(`love.graphics.setScissor`) before drawing slot boxes, so any partially-visible
slot at the edge is clipped cleanly. The scissor is cleared after.

## What stays the same

- `MIN_N = 1` — minimum loop length
- `DEFAULT_N = 8` — starting loop length
- `MAX_TICKS = 500` — simulation ceiling (now doubles as the timeline cap)
- Slot click cycling (left/right click to cycle direction)
- Length `-`/`+` buttons and display (now go up to 500)
- All pusher sim logic (`pusher_sim.lua`) — untouched
- Puzzle data format — no changes needed
- Tests in `tests/test_pushers.lua` — existing tests unaffected; new scroll tests added

## Open questions

None — all resolved before writing this doc.
