## Goal

Add the same web build and Cloudflare Pages CI pipeline that wip has, adapted for love-exemplar as a reusable starter template. All project-specific values (app title, Cloudflare project name) are driven by variables so anyone forking the repo just sets their own without touching the scripts.

## Affected files

- `scripts/build_web.sh` — new; builds a `.love` file and runs `love.js` to produce `web/`
- `package.json` — new; declares `love.js` and `wrangler` as dev dependencies
- `.github/workflows/ci.yml` — new; runs headless tests on every push/PR to `master`
- `.github/workflows/web.yml` — new; builds web output and deploys to Cloudflare Pages

## What changes

### scripts/build_web.sh

Adapted from wip's version with two differences:
- **IndexedDB patch included but commented out** — the full `save.dat` → IndexedDB sync hook from wip is present in the script, wrapped in a comment block explaining that it should be uncommented when the game uses `lua/core/save.lua`
- **Configurable title** — reads `APP_TITLE` env var with a bash default of `"Love Exemplar"` (matches `conf.lua`); CI passes it via a GitHub Actions repository variable

The zip includes only the files needed at runtime (no headless test infrastructure):
```
main.lua  conf.lua  assets/  core/  game/
```

### package.json

Minimal, matching wip:
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

### .github/workflows/ci.yml

Identical to wip's except targets `master` branch:
- Installs LÖVE 11.5 via PPA
- Runs `love . --headless`

### .github/workflows/web.yml

Adapted from wip with configurable project name:
- **Project name** — reads from GitHub Actions repository variable `vars.CLOUDFLARE_PROJECT_NAME`; anyone forking sets this variable once in their repo settings
- **App title** — passed to `build_web.sh` as `APP_TITLE` from `vars.APP_TITLE` (default `"Love Exemplar"` if unset)
- Targets `master` branch
- PR previews deploy to branch `pr-N`; posts a comment with the preview URL
- PR close cleans up the Cloudflare preview deployments
- Reads `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from secrets (same names as wip)

## What stays the same

- No game code, assets, or tests are touched
- `conf.lua`, `main.lua`, headless infrastructure — untouched
- The scripts are intentionally minimal since this is a starter template, not a production game

## Open questions

None — design is approved.
