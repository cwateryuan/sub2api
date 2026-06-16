# Sub2API Local Web Customization Handoff

Use this note when continuing cwateryuan's local Sub2API web customization work.

## Project Context

- Upstream project: `https://github.com/Wei-Shaw/sub2api`
- User fork: `https://github.com/cwateryuan/sub2api`
- Main customization branch: `local-web-custom`
- The user's work is focused on web/UI customization, not core gateway behavior.
- Do not commit local runtime files such as `config.yaml`, `.env`, database data, Redis data, or deployment data directories.

## Git Workflow

Expected remotes:

```bash
origin   https://github.com/cwateryuan/sub2api.git
upstream https://github.com/Wei-Shaw/sub2api.git
```

Normal local development flow:

```bash
git checkout local-web-custom
git status
# make changes
npm run all
git add <explicit files>
git commit -m "Short clear message"
git push origin local-web-custom
```

Do not use broad `git add .` if local runtime files are present. In this workspace, `config.yaml` is intentionally untracked and should remain uncommitted.

To sync upstream updates:

```bash
git fetch upstream
git merge upstream/main
```

If upstream default branch is `master`, use `upstream/master` instead. After merging, verify:

```bash
cat backend/cmd/server/VERSION
npm run all
```

Resolve conflicts locally, test, then push `local-web-custom`. Server-side source should pull only `origin/local-web-custom`; avoid doing upstream merges directly on the server.

## Local Build Command

The repo has a root helper command for local testing:

```bash
npm run all
```

This command is for local development only. It rebuilds frontend/backend using the helper script in `tools/local-build-all.ps1`. It is not part of the Docker deployment flow.

## Public Model Plaza

Public no-auth page:

- Route: `/models`
- View: `frontend/src/views/public/PublicModelPlazaView.vue`
- Data: `frontend/src/data/publicModelPlaza.json`
- Home header link: `frontend/src/views/HomeView.vue`
- Router entry: `frontend/src/router/index.ts`

The public page intentionally uses static JSON because existing backend model/group/rate APIs require JWT. Do not assume there is a no-auth API for group names or billing multipliers.

JSON shape for public cards:

```json
{
  "id": "gpt-5.5",
  "provider": "OpenAI",
  "category": "通用对话",
  "family": "GPT",
  "description": "展示文案",
  "priceFields": [
    { "label": "输入", "price": "¥5.00 / M token" },
    { "label": "输出", "price": "¥30.00 / M token" }
  ],
  "badges": [
    { "label": "codex分组", "multiplier": "0.3x", "description": "鼠标悬停说明" }
  ]
}
```

- `priceFields` controls the price rows.
- `badges` controls pill tags; `description` is displayed through the native hover title.
- Avoid reintroducing the deleted official-price block.

## Authenticated Model Plaza

Logged-in user page:

- Route: `/model-plaza`
- View: `frontend/src/views/user/ModelPlazaView.vue`
- Sidebar entry: `frontend/src/components/layout/AppSidebar.vue`
- Router entry: `frontend/src/router/index.ts`

This page uses authenticated APIs:

- `/channels/available`
- `/groups/rates`

The current display text should use:

```text
官网价格 x key的分组倍率
```

Avoid `font-semibold` in the customized model plaza pages unless the user explicitly asks to restore it.

## Docker Source Build Notes

The server uses Docker Compose with a source build context instead of the official pulled image. The app service should use a local image name to avoid confusing it with upstream:

```yaml
build:
  context: /path/to/sub2api-source
  dockerfile: Dockerfile
image: cwateryuan/sub2api:local
```

Do not use the web admin "online update" flow for this fork-based source deployment. Correct update path is Git pull on `local-web-custom`, then `docker compose up -d --build`.

Dockerfile has a build-time fix needed by upstream legal-doc imports:

```dockerfile
COPY frontend/ ./
COPY docs/legal/ /app/docs/legal/
RUN pnpm run build
```

The paired `.dockerignore` must allow `docs/legal/*.md` into the Docker build context. Without this, Docker frontend build can fail resolving imports like:

```text
../../../../docs/legal/admin-compliance.zh.md?raw
```

## Verification

Before handing changes back:

```bash
npm run all
```

If only frontend changed and the full helper is not appropriate, at minimum run:

```bash
cd frontend
npm run build
```

Expected recurring warnings may include Browserslist age, Vite chunk-size warnings, and dynamic/static import chunking warnings. These are not blockers unless new errors appear.
