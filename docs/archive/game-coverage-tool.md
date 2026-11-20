## Game Coverage Tool Checklist

- [x] Task A — `lua/headless/coverage.lua` — narrow scope to lua/game/ only: change the hook's `path:match` guard from `("^lua/core/") or path:match("^lua/game/")` to `path:match("^lua/game/")` only; change the `M.report` directory scan from `{ "lua/core", "lua/game" }` to `{ "lua/game" }` only; update the module-level comment
- [x] Task B — `main.lua` — `--coverage` flag already wired up; no further changes needed
