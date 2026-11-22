# Coverage enforcement in CI

## Goal

Prevent coverage regressions from landing.  The 100 % milestone was reached
in #44 but nothing stopped it from slipping: CI only checked that tests
passed, not that every game line was exercised.  This feature wires the
existing `--coverage` flag into CI and makes the measurement accurate enough
to enforce.

## Affected files

| File | Change |
|---|---|
| `lua/headless/coverage.lua` | Rewrote executable-line counting; added `os.exit(1)` on failure |
| `.github/workflows/ci.yml` | Added `--coverage` to the test invocation |
| `main.lua` | Existing `love.event.quit` hook already wires coverage into the run; no structural change |

## What changes

**Accurate line counting.**  The old tool used static text analysis: it
scanned source lines and skipped a hard-coded set of bare structural keywords
(`end`, `}`, `then`, `do`, `else`).  This produced wrong numbers in both
directions:

* `end` closing a *function* body generates a RETURN opcode in LuaJIT — the
  debug hook fires on it, so it is executable.  Skipping it undercounted
  `exec`, making fully-covered files appear > 100 %.
* `end` closing a *control structure* (if / while / for) generates no opcode
  — the hook never fires on it.  After naively un-skipping all `end` lines,
  those lines became false negatives that inflated the missed count.

The replacement counts lines using `debug.getinfo(fn, "L").activelines` on
every reachable function prototype in the file: the outer chunk, the returned
module table, any upvalue-chain functions, and any function called at
module-load time (found via a temporary `call` hook during `pcall(chunk)`).
This is the exact set of lines the debug hook can fire on — no heuristics
required.

**CI enforcement.**  `report()` calls `os.exit(1)` when overall coverage is
below 100 %.  CI now runs `love . --headless --coverage` so a gap blocks the
build.

## What stays the same

* The debug hook (`hook`, "l" event on `lua/game/`) is unchanged.
* `_hits` accumulation is unchanged.
* The printed report format is unchanged.
* Tests without `--coverage` still work and are unaffected.

## Open questions

None — implementation complete.
