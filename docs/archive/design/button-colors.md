# Button Colors

## Goal

Give each action button a distinct color accent so players can tell at a glance what each button does. Currently all buttons share the same neutral blue-grey fill and border, which makes the UI feel flat and slow to scan.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — `CMD_BUTTONS` table and `_draw_cmd_buttons()`
- `lua/game/scenes/solution_recap_scene.lua` — `RECAP_BUTTONS` table and `_draw_buttons()`

## What changes

Each button definition gains two optional color fields:
- `color_fill`   — `{r, g, b}` base fill when enabled
- `color_border` — `{r, g, b}` border when enabled

The draw functions read these fields and fall back to the existing neutral colors when they are absent, so any button that isn't updated just keeps its look.

### Color assignments

**Matrix scene — CMD_BUTTONS**

| id      | role                   | fill (enabled)       | border (enabled)      |
|---------|------------------------|----------------------|-----------------------|
| `run`   | Execute / play         | `0.12, 0.28, 0.12`   | `0.30, 0.75, 0.30`    |
| `reset` | Undo / clear the run   | `0.28, 0.16, 0.06`   | `0.85, 0.55, 0.20`    |
| `menu`  | Navigate back          | `0.12, 0.15, 0.28`   | `0.35, 0.45, 0.72`    |

**Solution recap scene — RECAP_BUTTONS**

| id             | role              | fill (enabled)       | border (enabled)      |
|----------------|-------------------|----------------------|-----------------------|
| `recap:next`   | Primary CTA       | `0.12, 0.28, 0.12`   | `0.30, 0.75, 0.30`    |
| `recap:replay` | Try again         | `0.28, 0.20, 0.06`   | `0.85, 0.65, 0.20`    |
| `recap:menu`   | Navigate back     | `0.12, 0.15, 0.28`   | `0.35, 0.45, 0.72`    |

Disabled state uses the same dim-out that already exists (low-opacity fill, faded border) — the color itself is not changed when disabled so the shape reads clearly, just darker.

## What stays the same

- Button rects, labels, hint text, fonts — no layout changes
- Palette buttons — these are tool selectors, not actions; they keep their current look
- The UI registry / hit-testing — no structural changes
- Timeline controls — untouched

## Open questions

None — the user confirmed they want distinct button colors. No layout changes required.
