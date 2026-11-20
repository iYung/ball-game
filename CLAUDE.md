# Project notes for Claude

Love2D (LÖVE 11.5) puzzle game. Run it with `love .`. Run all tests with `love . --headless`. Exit code 0 means every test passed.

## Testing rules (mandatory). Full guide: [docs/testing.md](docs/testing.md)

1. Every feature the player can click or press needs a UI spec in `tests/ui/` that drives it through real input (`press`, `click_button`, ...). Calling private scene methods (`scene:_foo`) does not count as UI coverage.
2. Never edit an existing test or spec just to make it pass. If the game broke it, fix the game. If the old expectation really was wrong, say why in the PR or verification report.
3. Every interactive element must appear in its scene's `ui_elements()`, and clicks must hit-test through `UI.element_at`. An element that is not in the registry is a bug.
4. Headless tests cannot see real rendering, the save file or the web build. Check those by running the game or opening the PR's web preview.
