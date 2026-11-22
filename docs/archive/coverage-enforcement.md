## Coverage enforcement checklist

- [x] Rewrite `count_executable` in `lua/headless/coverage.lua` to use
  `debug.getinfo(fn,"L").activelines` on all reachable function prototypes
  (outer chunk, returned table, upvalue chain, call-hook during pcall) instead
  of static text analysis — `lua/headless/coverage.lua`

- [x] Add `os.exit(1)` in `M.report()` when overall coverage is below 100 %
  — `lua/headless/coverage.lua`

- [x] Update `.github/workflows/ci.yml` to run `love . --headless --coverage`
  so coverage is enforced on every push/PR — `.github/workflows/ci.yml`
