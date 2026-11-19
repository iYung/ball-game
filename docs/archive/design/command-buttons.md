# Command Buttons

## Goal

Replace the plain-text keyboard-shortcut hints in the palette bar (`[R] Run`, `[Spc] Step`, `[Bsp] Reset`) with four styled, clickable buttons: **Run**, **Step**, **Reset**, and **Menu**. Each button mirrors the existing keyboard shortcut in both behaviour and enabled/disabled state.

## Affected files

- `game/scenes/matrix_scene.lua` — all changes live here: layout constants, draw helpers, mouse input.

## What changes

### New button definitions

Add a `CMD_BUTTONS` table (similar to `PALETTE_BUTTONS`) in `matrix_scene.lua`:

```lua
local CMD_BUTTONS = {
    { id="run",   label="▶ Run"   },
    { id="step",  label="→ Step"  },
    { id="reset", label="↺ Reset" },
    { id="menu",  label="⬡ Menu"  },
}
```

### Layout

The four buttons sit in the palette bar (`y = PALETTE_Y + 6`) between the last op button and the right edge of the grid panel (`HUD_X = 820`).  Current text hints occupy roughly x = 620–820; the buttons occupy that same horizontal range.

Each button: `w = 80, h = 48`, evenly distributed across the available width, with 8 px gaps.

A new helper `_build_cmd_buttons()` computes and caches the rects into `self._cmd_btn_rects` (a list of `{id, label, x, y, w, h}`). It is called at the end of `on_enter()` and `load_puzzle()`, after `_build_palette()`.

### Enabled/disabled state

Mirrors the keyboard logic in `key_pressed`:

| Button | Enabled when |
|--------|-------------|
| Run    | `not self.running and status ~= "running" and status ~= "win"` |
| Step   | `not self.running and (status == nil or status == "running" or status == "no_pusher")` |
| Reset  | `self.sim ~= nil or self.status ~= nil` |
| Menu   | always |

Disabled buttons are drawn at reduced opacity (alpha ≈ 0.35) to signal they can't be clicked.

### Drawing

`draw_palette()` removes the three `love.graphics.print("[R] Run" …)` lines and instead calls `_draw_cmd_buttons()`, which iterates `self._cmd_btn_rects` and draws each button with the same rounded-rectangle style as the op palette buttons.  Active (enabled) colour: `{0.25, 0.25, 0.4, 1}` fill; disabled: `{0.12, 0.12, 0.20, 1}` fill. Text colour: enabled `{0.85, 0.85, 0.9, 1}`, disabled `{0.4, 0.4, 0.5, 1}`.

### Click handling

`mouse_pressed()` checks `_cmd_btn_rects` before the palette buttons check (but only in the `my >= PALETTE_Y` branch) and dispatches:

| id    | Action |
|-------|--------|
| run   | same as `key_pressed("r")` |
| step  | same as `key_pressed("space")` |
| reset | same as `key_pressed("backspace")` |
| menu  | same as `key_pressed("escape")` |

Clicks on disabled buttons are silently ignored.

## What stays the same

- All keyboard shortcuts continue to work unchanged.
- No other scenes are affected.
- The timeline panel, HUD, and op palette are untouched.

## Open questions

None — resolved in design conversation.
