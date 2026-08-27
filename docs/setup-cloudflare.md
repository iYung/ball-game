# Cloudflare Pages Setup

One-time steps to enable web builds and PR previews.

## 1. Create a Cloudflare Pages project

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com) and go to **Workers & Pages**
2. Click **Create** → **Pages** → **Create directly**
3. Give it a project name (e.g. `love-exemplar`) — this becomes your URL: `<project>.pages.dev`
4. Skip the initial deployment (the GitHub Action handles it)

## 2. Get your Cloudflare credentials

- **Account ID** — shown in the right sidebar of any Cloudflare dashboard page
- **API Token** — go to **My Profile** → **API Tokens** → **Create Token** → use the **Edit Cloudflare Workers** template, then scope it to your account

## 3. Add secrets to GitHub

In your repo: **Settings → Secrets and variables → Actions → Secrets**

| Name | Value |
|------|-------|
| `CLOUDFLARE_API_TOKEN` | the API token from step 2 |
| `CLOUDFLARE_ACCOUNT_ID` | the account ID from step 2 |

## 4. Add variables to GitHub

In your repo: **Settings → Secrets and variables → Actions → Variables**

| Name | Value |
|------|-------|
| `CLOUDFLARE_PROJECT_NAME` | the project name from step 1 |
| `APP_TITLE` | browser tab title — optional, defaults to `"Love Exemplar"` |

## 5. That's it

Open a PR. The Actions will:
- Run `love . --headless` (CI)
- Build the web output and deploy a preview to `https://pr-{N}.{CLOUDFLARE_PROJECT_NAME}.pages.dev`
- Post the preview URL as a PR comment

Merging to `master` deploys to `https://{CLOUDFLARE_PROJECT_NAME}.pages.dev`.

## Enabling saves on web

If your game uses `lua/core/save.lua`:

1. In `scripts/build_web.sh` — uncomment the `# --- SAVES ---` block
2. In `web-template/controls.js` — uncomment the `# --- SAVES ---` block to add a "Clear All Data" button
