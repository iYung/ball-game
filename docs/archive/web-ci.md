## Web CI Checklist

- [x] Task A — `package.json` — Create at the project root with `love.js` and `wrangler` as dev dependencies:
  ```json
  {
    "name": "love-exemplar",
    "version": "1.0.0",
    "scripts": { "build": "bash scripts/build_web.sh" },
    "devDependencies": {
      "love.js": "11.4.1",
      "wrangler": "^3"
    }
  }
  ```

- [x] Task B — `scripts/build_web.sh` — Create the directory and file. Adapt from wip's `scripts/build_web.sh` with these changes:
  1. Read app title from env: `APP_TITLE="${APP_TITLE:-Love Exemplar}"` and use `$APP_TITLE` in the `npx love.js` call instead of the hardcoded wip game title.
  2. Zip command includes `main.lua conf.lua assets/ core/ game/` (no `lua/` — that's test infrastructure only).
  3. The full IndexedDB save patch block from wip is included but commented out. Wrap the entire python block in a clearly-marked comment like:
     ```bash
     # --- SAVES: uncomment the block below if your game uses lua/core/save.lua ---
     # echo "Patching love.js to sync saves to IndexedDB immediately on write..."
     # python3 - <<'PYEOF'
     # ...full patch script...
     # PYEOF
     # --- end SAVES ---
     ```

- [x] Task C — `.github/workflows/ci.yml` — Create the directory and file. Runs headless tests on push and pull_request targeting `master`:
  ```yaml
  name: CI
  on:
    push:
      branches: [master]
    pull_request:
      branches: [master]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Install LÖVE 11.5
          run: |
            sudo add-apt-repository -y ppa:bartbes/love-stable
            sudo apt-get update -q
            sudo apt-get install -y love
        - name: Run tests
          run: love . --headless
  ```

- [x] Task D — `.github/workflows/web.yml` — Create the file. Adapt from wip's `web.yml` with these changes:
  1. Target `master` branch (not `main`) everywhere it appears.
  2. Project name: use `${{ vars.CLOUDFLARE_PROJECT_NAME }}` instead of the hardcoded `wip`.
  3. App title: pass `APP_TITLE: ${{ vars.APP_TITLE || 'Love Exemplar' }}` as an env var to the build step.
  4. The cleanup-pr job's API calls use `${{ vars.CLOUDFLARE_PROJECT_NAME }}` in the URL instead of `wip`.
  5. Everything else (artifact upload/download, comment posting, secret names) is identical to wip.
