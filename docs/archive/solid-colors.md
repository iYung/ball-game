# Solid Colors Checklist

- [x] Task A — `lua/game/param_popup.lua` — Remove the full-screen dim overlay at line 120 (`setColor(0,0,0,0.55)` + rectangle). Change `C.bg` alpha from `0.97` to `1`.

- [x] Task B — `lua/game/scenes/settings_menu.lua` — Remove the full-screen dim overlay at line 161 (`setColor(0,0,0,0.6)` + rectangle).

- [x] Task C — `lua/game/scenes/start_scene.lua` — Remove the pulsing alpha animation (lines 96–99): replace `alpha = 0.5 + 0.5 * math.sin(...)` with static `setColor(0.60, 0.60, 0.70, 1)`. Change debug text at line 103 from alpha `0.7` to `1`.

- [x] Task D — `lua/game/scenes/level_select_scene.lua` — Change line 276 nav button border from `(0.35, 0.45, 0.80, 0.6)` to `(0.35, 0.45, 0.80, 1)`.

- [x] Task E — `lua/game/scenes/solution_recap_scene.lua` — Replace all semi-transparent colors (alpha < 1) in the draw methods with blended solid equivalents:
  - Line 164: source fill `(0.1,0.5,0.2, 0.5)` → `(0.09, 0.29, 0.17, 1)`
  - Line 171: sink fill `(0.1,0.3,0.7, 0.5)` → `(0.09, 0.19, 0.42, 1)`
  - Line 178: pusher bg `(0.30,0.18,0.45, 0.6)` → `(0.21, 0.14, 0.32, 1)`
  - Lines 180,185,262,267: pusher border/label `(0.80,0.60,1.0, 0.8)` → `(0.66, 0.50, 0.83, 1)`
  - Line 191: op bg `(0.22,0.14,0.03, 0.92)` → `(0.21, 0.14, 0.04, 1)`
  - Lines 225,260: op badge bg `(0.08,0.08,0.16, 0.92)` → `(0.08, 0.08, 0.15, 1)`
  - Lines 228,262 (recap matrix): badge border `(1,0.80,0.15, 0.9)` → `(0.91, 0.73, 0.15, 1)`
  - Lines 260,267: pusher fill/border (duplicates of lines 178/180 in `_draw_pushers`)

- [x] Task F — `lua/game/scenes/matrix_scene.lua` tile draws — Replace semi-transparent tile fill/border colors with blended solid equivalents (background assumed `0.07,0.07,0.11`):
  - Lines 978,1012: source tile fill `(0.1,0.5,0.2, 0.5)` → `(0.09, 0.29, 0.17, 1)`
  - Lines 1019: sink tile fill `(0.1,0.3,0.7, 0.5)` → `(0.09, 0.19, 0.42, 1)`
  - Lines 1041: op bg `(0.22,0.14,0.03, 0.92)` → `(0.21, 0.14, 0.04, 1)`
  - Line 1051: op sub-label `(0.9,0.7,0.3, 0.6)` → `(0.56, 0.44, 0.21, 1)`
  - Lines 1095: locked dot `(0.7,0.7,0.7, 0.7)` → `(0.50, 0.50, 0.50, 1)`
  - Line 1100: fixed marker `(0.5,0.75,1.0, 0.8)` → `(0.42, 0.62, 0.83, 1)`
  - Lines 1130,1157,1181 (draw_param_cell etc.): `(0.55,0.42,0.15, 0.9)` → `(0.50, 0.38, 0.14, 1)` and `(0.7,0.55,0.2, 0.9)` → `(0.63, 0.50, 0.19, 1)`

- [x] Task G — `lua/game/scenes/matrix_scene.lua` drag/ghost/overlay draws — Replace semi-transparent overlays:
  - Lines 852,880: expand +handle `(0.3,0.6,0.3, 0.7)` → `(0.23, 0.44, 0.23, 1)`
  - Lines 866,892: shrink -handle `(0.6,0.2,0.2, 0.6)` → `(0.44, 0.15, 0.15, 1)`
  - Line 923: drag ghost valid `(0.2,0.7,0.2, 0.45)` → `(0.14, 0.35, 0.14, 1)`
  - Line 925: drag ghost invalid `(0.7,0.2,0.2, 0.45)` → `(0.35, 0.14, 0.14, 1)`
  - Line 928: drag border `(valid and 0.4 or 0.9, valid and 0.9 or 0.3, valid and 0.4 or 0.3, 0.8)` → `(valid and 0.34 or 0.74, valid and 0.74 or 0.26, valid and 0.34 or 0.26, 1)`
  - Line 938: drag label `(1,1,1, 0.8)` → `(0.82, 0.82, 0.82, 1)`
  - `draw_pusher` line 947: `a = ghost and 0.25 or 0.95` → `a = ghost and 0.20 or 1` (use 0.20 to give a noticeably dimmer ghost on timeline)
  - `draw_pusher` line 950: `ghost and 0.4 or 1` → `ghost and 0.35 or 1`
  - Lines 1333–1342: travelling matrix "preview" (input not yet running): `(0.08,0.08,0.16, 0.45)` → `(0.11, 0.11, 0.17, 1)`, `(1,0.80,0.15, 0.45)` → `(0.47, 0.37, 0.07, 1)`, `(0.95,0.95,1.0, 0.45)` → `(0.50, 0.50, 0.53, 1)`
  - Lines 1367–1370: travelling matrix active: `(0.08,0.08,0.16, 0.92)` → `(0.08,0.08,0.15, 1)`, `(1,0.80,0.15, 0.9)` → `(0.91, 0.73, 0.15, 1)`
  - Lines 1454,1512: disabled button border `(0.2,0.2,0.3, 0.35)` → `(0.14, 0.14, 0.21, 1)`
  - Line 1742: status banner `col[1],col[2],col[3], 0.9` → `col[1], col[2], col[3], 1`
  - Lines 2005,2007: DnD ghost tooltip bg `(0.2,0.25,0.4, 0.75)` → `(0.17, 0.21, 0.33, 1)`, text `(1,1,1, 0.9)` → `(1, 1, 1, 1)`
  - Line 1095: `(0.7,0.7,0.7, 0.7)` locked dot (see Task F)
  - Palette disabled buttons line 1509: `0.12, 0.12, 0.20, 0.5` → split to separate disabled color
