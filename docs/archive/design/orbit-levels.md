## Goal

Replace the placeholder exemplar demo (WASD sprite, ground, blinking coins) with the real game: a level-based game where the player is a ball that moves by orbiting a point in space. Growing/shrinking the orbit radius while spinning is the *only* way to translate across the screen. Levels are fixed screens bounded by walls with one gap (the exit); passing through the gap loads the next level, entering through the mirrored opposite wall so the levels feel physically connected.

## Core mechanic

The ball's state is `{ x, y, center_x, center_y, radius, angle, direction }`. `x, y` (the ball's actual position, used for collision/drawing) and `center_x, center_y` (the pivot) are both stored explicitly — `radius`/`angle` are just the polar relationship between them, recomputed each step rather than treated as independent inputs. `direction` is `+1` (clockwise) or `-1` (counter-clockwise).

Each frame, in this order:

1. **Radius input.** `desired_radius = clamp(radius + radius_rate * dt * (space_held and 1 or -1), MIN_RADIUS, MAX_RADIUS)`.
2. **Re-pivot, ball fixed.** This is the key rule from the spec: changing the radius moves the *center*, not the ball. Take the unit vector from the ball to the current center, and place the new center along that same line at the new radius: `new_center = ball_pos + unit(center_pos - ball_pos) * desired_radius`. The ball's `x, y` do not change in this step.
3. **Orbit step.** Recompute `angle` from `ball_pos - new_center` (unchanged numerically from before the re-pivot — the algebra works out so this is a no-op except for floating point, but it keeps angle/position always in sync), then advance it: `angle += direction * ANGULAR_SPEED * dt`. The new ball position is `new_center + desired_radius * (cos(angle), sin(angle))`.
4. **Collision.** Test the new ball position against every wall rectangle in the level (circle-vs-AABB: clamp the ball center to the rect, compare distance to `BALL_RADIUS`). On the first collision found: push the ball back out to the wall surface, flip `direction` (cw ↔ ccw), and re-derive `angle` from the corrected position relative to the (unmoved) center.

Net effect: holding space while orbiting spirals the ball outward and drags its pivot along with it, translating the ball across the screen; releasing spirals it back in. Bouncing off a wall reverses the spin so the ball starts curving away from what it just hit. This is the entire movement model — there is no separate walk/run input.

Tuning constants (in `game/player.lua`):

| Constant | Value | Meaning |
|---|---|---|
| `BALL_RADIUS` | 10 px | visual/collision size of the ball |
| `MIN_RADIUS` | 50 px | orbit radius floor (never fully collapses to the pivot) |
| `MAX_RADIUS` | 300 px | orbit radius ceiling |
| `RADIUS_RATE` | 140 px/s | how fast radius grows/shrinks |
| `ANGULAR_SPEED` | 2.4 rad/s | orbit speed |

These are starting points for feel — expect to retune once the levels are playable.

## Levels

A level is fixed-screen (1280×720, matching the existing logical resolution) data, not a bespoke scene class:

```lua
-- game/levels/level_1.lua
return {
  id = 1,
  exit = { side = "top", pos = 640, gap = 160 },  -- pos/gap measured along the wall's axis (x for top/bottom, y for left/right)
  obstacles = {},                                  -- interior wall rects: { {x=, y=, w=, h=}, ... }
}
```

- `game/level.lua` is a small shared module (not a class instance) that, given a level def, produces:
  - the list of wall rectangles to collide against: each boundary side is a full-length rect, except the `exit` side which is split into two rects around the gap, plus `obstacles` appended as-is.
  - the mirrored entry `{ side, pos }` for the *next* level: opposite side, same `pos`. (`top`↔`bottom`, `left`↔`right`.)
  - a spawn transform from an entry `{ side, pos }`: a point just inside the wall at that `pos`, plus an initial orbit center offset `MIN_RADIUS` further inward along the wall's inward normal, `direction = clockwise`, i.e. every level (including the first) starts the ball at `MIN_RADIUS`, matching the spec.

- `game/scenes/level_scene.lua` (replaces `game/scenes/game_scene.lua`) is the one generic scene: takes `(level_id, entry, sm)`, builds the wall sprites + player from the level def via `game/level.lua`, runs collision each frame, and — when the ball's position goes outside the 1280×720 bounds (the only way out is through the gap, since every other edge is walled) — computes the next level's mirrored entry and calls `sm:switch(LevelScene.new(next_id, entry, sm))`.

- Exit **sides vary per level** so the mirroring is visible instead of trivial:
  - **Level 1** — empty room. Exit: `top`, `pos = 640`. (Level 1 has no predecessor; its own spawn is a fixed default — bottom wall, `pos = 640` — using the same spawn transform as every other level.)
  - **Level 2** — one obstacle wall roughly across the middle of the room, forcing a route around it. Entry (mirrored from level 1): `bottom, 640`. Exit: `right, 300`.
  - **Level 3** — a corridor formed by two jutting walls that narrow to a choke point the player must be at low radius to fit through. Entry (mirrored from level 2): `left, 300`. Exit: `top, 200`.
  - Reaching level 3's exit loops back to level 1's own fixed spawn (there's no level 4 to mirror into yet).

## Affected files

- `game/player.lua` — rewritten: orbit-ball entity and physics (was WASD sprite mover)
- `game/scenes/game_scene.lua` — **deleted**
- `game/scenes/level_scene.lua` — **new**: generic level scene (collision, exit detection, level transition)
- `game/level.lua` — **new**: wall-rect generation, mirrored-entry calculation, spawn transform
- `game/levels/level_1.lua`, `level_2.lua`, `level_3.lua` — **new**: level data
- `main.lua` — boots `LevelScene.new(1, nil, manager)` instead of `GameScene.new()`
- `tests/test_scene.lua` — update references from `GameScene` to `LevelScene`
- `tests/test_basics.lua` — update comment/require from `game_scene` to `level_scene`
- `tests/test_player.lua` — **new**: orbit math (re-pivot keeps ball fixed, angle progresses, radius clamps, direction flips)
- `tests/test_level.lua` — **new**: wall generation from a level def, mirrored-entry calculation

## What stays the same

- `lua/core/*` (Scene, SceneManager, Drawer, Sprite, Camera, Input, Timer, Fonts, Shader) — untouched
- `lua/headless/*` — untouched; `love.graphics.circle` (used to draw the ball) resolves through the existing no-op catch-all, no stub changes needed
- Fixed 1280×720 logical canvas and letterboxing in `main.lua` — untouched
- No camera movement — each level is a static, fully-visible screen, so `Scene`'s camera is left at its default (no `:follow()` call)
- No fail/death state — the ball just keeps bouncing until it finds the exit

## Open questions

None outstanding — demo-replacement and exit-side variation were confirmed with the user before writing this doc.
