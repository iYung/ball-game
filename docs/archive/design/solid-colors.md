# Solid Colors — Remove All Transparency from Static UI

## Goal

Remove semi-transparent (`alpha < 1`) colors from every static UI element in the game. All drawn shapes and text use fully opaque colors. Animated alpha transitions between scenes (scene_manager fade-to-black, cutscene_scene intro) are **out of scope** and stay as-is.

## Affected files

| File | Transparency uses |
|---|---|
| `lua/game/param_popup.lua` | `C.bg = {…, 0.97}`, dim overlay `(0,0,0, 0.55)` |
| `lua/game/scenes/settings_menu.lua` | Dim overlay `(0,0,0, 0.6)` |
| `lua/game/scenes/start_scene.lua` | Pulsing "press to play" text (animated alpha), debug text `(…, 0.7)` |
| `lua/game/scenes/level_select_scene.lua` | Nav button border `(0.35,0.45,0.80, 0.6)` |
| `lua/game/scenes/solution_recap_scene.lua` | Op-type background fills (source, sink, op categories — alpha 0.5–0.92) |
| `lua/game/scenes/matrix_scene.lua` | Source/sink tile fills; drag ghost; expand handle strips; timeline ghosted-pusher; timeline step backgrounds; op category backgrounds |

## What changes

### Dim overlays (param_popup, settings_menu)
Remove the full-screen semi-transparent black dim rectangle. The panel already has a solid opaque background so it reads clearly without a dim layer behind it.

### `param_popup` `C.bg`
`{0.12, 0.12, 0.18, 0.97}` → `{0.12, 0.12, 0.18, 1}` (barely perceptible change).

### Start scene text
- "Press to play" pulse: change to static text at a fixed readable alpha `1`. Remove the `math.sin` alpha animation.
- Debug unlock text: `(0.35, 0.32, 0.42, 0.7)` → `(0.35, 0.32, 0.42, 1)`.

### Level select nav button
`(0.35, 0.45, 0.80, 0.6)` → `(0.35, 0.45, 0.80, 1)`.

### Solution recap op-type backgrounds
Blend each semi-transparent fill with the assumed dark background (`{0.08, 0.08, 0.13}`) and set alpha to 1. Each blended RGB = `alpha * fg + (1 - alpha) * bg`.

| Original | alpha | Blended solid |
|---|---|---|
| `(0.1, 0.5, 0.2, 0.5)` source | 0.5 | `(0.09, 0.29, 0.17, 1)` |
| `(0.1, 0.3, 0.7, 0.5)` sink | 0.5 | `(0.09, 0.19, 0.42, 1)` |
| `(0.30, 0.18, 0.45, 0.6)` pusher bg | 0.6 | `(0.21, 0.14, 0.32, 1)` |
| `(0.80, 0.60, 1.0, 0.8)` pusher border | 0.8 | `(0.66, 0.50, 0.83, 1)` |
| `(0.22, 0.14, 0.03, 0.92)` op bg | 0.92 | `(0.21, 0.14, 0.04, 1)` |
| `(0.08, 0.08, 0.16, 0.92)` op badge bg | 0.92 | `(0.08, 0.08, 0.15, 1)` |
| `(1, 0.80, 0.15, 0.9)` op badge text | 0.9 | `(0.91, 0.73, 0.15, 1)` |

### Matrix scene tile backgrounds and overlays
Same blend-with-background approach for all tile fill colors:

| Element | Original | alpha | Blended solid |
|---|---|---|---|
| Source tile fill | `(0.1, 0.5, 0.2, 0.5)` | 0.5 | `(0.09, 0.29, 0.17, 1)` |
| Sink tile fill | `(0.1, 0.3, 0.7, 0.5)` | 0.5 | `(0.09, 0.19, 0.42, 1)` |
| Expand +col/+row handle | `(0.3, 0.6, 0.3, 0.7)` | 0.7 | `(0.23, 0.44, 0.23, 1)` |
| Shrink -col/-row handle | `(0.6, 0.2, 0.2, 0.6)` | 0.6 | `(0.39, 0.15, 0.15, 1)` |
| Drag ghost fill (valid) | `(0.2, 0.7, 0.2, 0.45)` | 0.45 | `(0.13, 0.35, 0.13, 1)` |
| Drag ghost fill (invalid) | `(0.7, 0.2, 0.2, 0.45)` | 0.45 | `(0.35, 0.13, 0.13, 1)` |
| Drag ghost border (valid) | `(0.4, 0.9, 0.4, 0.8)` | 0.8 | `(0.34, 0.74, 0.34, 1)` |
| Drag ghost border (invalid) | `(0.9, 0.3, 0.3, 0.8)` | 0.8 | `(0.74, 0.26, 0.26, 1)` |
| Drag ghost label | `(1, 1, 1, 0.8)` | 0.8 | `(0.82, 0.82, 0.82, 1)` |
| Pusher ghost bg | `(0.30, 0.18, 0.45, 0.25)` | 0.25 | `(0.14, 0.11, 0.21, 1)` |
| Pusher ghost border | `(0.80, 0.60, 1.0, 0.4)` | 0.4 | `(0.37, 0.29, 0.47, 1)` |
| Op bg category | `(0.22, 0.14, 0.03, 0.92)` | 0.92 | `(0.21, 0.14, 0.04, 1)` |
| Timeline step bg | `(0.2, 0.2, 0.3, 0.35)` | 0.35 | `(0.12, 0.12, 0.19, 1)` |
| Ref cell source fill | `(0.1, 0.5, 0.2, 0.5)` | 0.5 | same as source tile |
| Op badge bg | `(0.08, 0.08, 0.16, 0.92)` | 0.92 | `(0.08, 0.08, 0.15, 1)` |
| Op badge label | `(1, 0.80, 0.15, 0.9)` | 0.9 | `(0.91, 0.73, 0.15, 1)` |
| col[1..3] colored bg | `col[1], col[2], col[3], 0.9` | 0.9 | multiply each channel by 0.9+0.1*bg ≈ set alpha to 1 |
| Tooltip/label bg | `(0.2, 0.25, 0.4, 0.75)` | 0.75 | `(0.17, 0.21, 0.33, 1)` |
| Tooltip/label text | `(1, 1, 1, 0.9)` | 0.9 | `(1, 1, 1, 1)` |
| `(0.9, 0.7, 0.3, 0.6)` op name sub | 0.6 | `(0.56, 0.44, 0.21, 1)` |
| `(0.7, 0.7, 0.7, 0.7)` | 0.7 | `(0.50, 0.50, 0.50, 1)` |
| `(0.5, 0.75, 1.0, 0.8)` | 0.8 | `(0.42, 0.62, 0.83, 1)` |
| `(0.55, 0.42, 0.15, 0.9)` op bg | 0.9 | `(0.50, 0.38, 0.14, 1)` |
| `(0.7, 0.55, 0.2, 0.9)` op border | 0.9 | `(0.63, 0.50, 0.19, 1)` |

### `draw_pusher` ghost mode
`a = ghost and 0.25 or 0.95` → `a = 1`. Ghost and non-ghost pushers both use full alpha (ghost pushers on the timeline appear visually distinct via other means — lighter foreground color).

## What stays the same

- `lua/core/scene_manager.lua` fade-to-black transition — unchanged
- `lua/game/scenes/cutscene_scene.lua` intro animation — unchanged
- All `alpha = 1` calls — unchanged
- Game logic, input handling, tests — unchanged

## Open questions

None — resolved by user: animated scene transitions are out of scope.
