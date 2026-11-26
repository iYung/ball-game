# Test mode: skip the solution replay

## Goal

When a puzzle is solved after pressing **Test** in the editor, the player goes straight back to the editor. Today they go to the solution replay and then to level select, and lose their way back to the draft.

Decisions (confirmed with the user):

- After a win in Test mode, `WIN!` stays on screen. **Continue** (or Enter) returns to the editor.
- In Test mode, Esc → Settings → **Exit to Menu** also returns to the editor.

## Affected files

- `lua/game/scenes/matrix_scene.lua`
- `tests/ui/` (new or extended editor spec)
- `README.md` (Puzzle editor section)

## What changes

- Test mode means the game scene was given a scene to go back to (`_back_scene`). Only the editor's **Test** button does this.
- In Test mode, **Continue**, the **Menu** button and Settings **Exit to Menu** all switch back to that same editor scene, so the draft is kept.
- The solution replay is never opened in Test mode. As a result, a test win no longer records anything in saved progress (today the replay marks puzzle number 0 as solved).

## What stays the same

- Normal play: Continue opens the solution replay, and Menu and Exit to Menu go to level select.
- The `WIN!` banner, the Continue button's label and position, and the Enter key.
- Saving volume settings and stopping the background music on Exit to Menu.
- The editor scene itself.

## Open questions

None.
