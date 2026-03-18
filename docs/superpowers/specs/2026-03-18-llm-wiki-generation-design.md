# LLM-Powered Wiki Generation — Design Spec

## Overview

Add a GitHub Actions workflow that uses Claude (Anthropic API) to generate and update non-API wiki pages from source code. Changes are submitted as PRs against the main repo for human review. On merge, a sync step pushes approved content to the wiki repository.

## Goals

- Keep wiki guides, overviews, and conceptual docs in sync with source code automatically
- Reduce manual documentation burden while maintaining quality through human review
- Minimize API costs by only regenerating pages affected by code changes

## Non-Goals

- Replacing the existing `generate_api_docs.py` (API reference pages stay deterministic)
- Generating `_Sidebar.md` or `Installation.md` (manually maintained)
- Fully autonomous wiki updates without human review

## Architecture

### Components

1. **`scripts/generate_wiki.py`** — Main script that orchestrates wiki generation
2. **`.github/workflows/generate-wiki.yml`** — GitHub Actions workflow (generate + PR)
3. **`.github/workflows/sync-wiki.yml`** — Syncs `wiki/` to the wiki repo on merge
4. **Page mapping config** — Maps source directories to wiki pages (embedded in script)

### Wiki Storage Model

GitHub wiki repos (`HanSur94/FastSense.wiki.git`) do not support pull requests. To enable PR-based review:

- The `wiki/` directory is tracked in the main repo as the source of truth
- The LLM workflow modifies files in `wiki/` and opens a PR against the main repo
- A separate sync workflow pushes `wiki/` content to the wiki git repo after merge
- The existing `generate-docs.yml` is updated to also write to `wiki/` in the main repo (instead of pushing directly to the wiki repo)

**One-time migration:** Add the existing `wiki/` content to git tracking in the main repo.

### Page Mapping

| Source Path | Wiki Pages Affected |
|---|---|
| `libs/FastSense/` | Home.md, Architecture.md, Getting-Started.md, Performance.md, MEX-Acceleration.md |
| `libs/Dashboard/` | Dashboard-Engine-Guide.md, Home.md |
| `libs/EventDetection/` | Event-Detection-Guide.md (new), Home.md |
| `libs/SensorThreshold/` | Use-Case:-Multi-Sensor-Shared-Threshold.md, Home.md |
| `libs/WebBridge/` | WebBridge-Guide.md (new), Home.md |
| `libs/FastSense/*Theme*` | Skipped — `API-Reference:-Themes.md` is manually maintained and excluded by the `API-Reference:-*.md` blanket rule |
| `examples/` | Examples.md, Getting-Started.md |

"Aggregate" pages (Home.md, Architecture.md) regenerate when any lib changes.

### Change Detection

- On push triggers: `git diff ${{ github.event.before }} ${{ github.sha }} --name-only` to identify changed source files. Falls back to full regeneration if the before-SHA is unavailable (e.g., first push, force push).
- Changed files are mapped through the page mapping to determine which wiki pages to regenerate.
- On manual `workflow_dispatch`: all pages are regenerated (full refresh).

### Context Assembly

For each wiki page to regenerate, the script assembles:

1. **Source files** — Relevant `.m` files, trimmed to public API surface (class headers, public methods/properties signatures, help text). Reuses parser logic from `generate_api_docs.py`.
2. **Example scripts** — Full content of relevant example `.m` files.
3. **Current wiki page** — Existing content so Claude can update rather than rewrite.
4. **Sidebar** — `_Sidebar.md` for navigation context.

**Token budget:** ~50K tokens input per page, targeting Claude claude-sonnet-4-20250514 (200K context window). If context exceeds the budget, the least-relevant example files are dropped first. API calls are made sequentially to avoid rate limits on full-refresh runs.

### Prompt Strategy

Each page type has a tailored system prompt:

| Page Type | Key Instructions |
|---|---|
| Overview (Home) | Summarize all libraries, key metrics, quick start. Pull benchmark numbers from source. |
| Architecture | Explain render pipeline, class relationships, data flow. Use existing page structure as template. |
| Feature Guide | Tutorial-style: what it does, how to use it, code examples from `examples/`. |
| Use Case | Problem → solution walkthrough with complete code snippets. |
| Examples | Index of all example scripts with one-line descriptions. |

All prompts include shared instructions:
- "Do not invent features or parameters that don't exist in the source code"
- "Preserve the auto-generated header"
- "Use MATLAB syntax highlighting in code blocks"
- "Link to API reference pages using existing wiki link conventions"

### Workflow: `generate-wiki.yml`

**Triggers:**
- Push to `main` with changes in `libs/**` or `examples/**`
- `workflow_dispatch` (manual, full regeneration)

**Permissions:** `contents: write`, `pull-requests: write`

**Actor guard:** The job must skip when the push actor is `github-actions[bot]`, to prevent a workflow loop when `generate-docs.yml` commits API docs to `main` (which touches `wiki/**` and would otherwise re-trigger this workflow):
```yaml
jobs:
  generate:
    if: github.actor != 'github-actions[bot]'
```

**Steps:**
1. Checkout main repo with full history (`fetch-depth: 0`)
2. Setup Python 3.12, install `anthropic` pip package
3. Detect changed files:
   - Push event: `git diff ${{ github.event.before }} ${{ github.sha }} --name-only`
   - If diff fails or is empty: treat as full regeneration
   - Manual dispatch: all pages
4. Run `python3 scripts/generate_wiki.py --changed-files <list>`
   - Maps changes → pages to regenerate
   - Calls Claude API (claude-sonnet-4-20250514) sequentially for each affected page
   - Writes updated pages to `wiki/`
5. Check if `wiki/` has any diffs
6. If at least one page was successfully generated and has changes:
   - Create branch `wiki-update/<short-sha>`
   - Commit changes to the branch
   - Open PR titled "docs: update wiki pages [auto-generated]"
   - PR body lists pages regenerated, trigger reason, and any warnings/failures
7. If no changes or all pages failed: exit cleanly (no PR)

**Secrets required:** `ANTHROPIC_API_KEY` in repository secrets.

### Workflow: `sync-wiki.yml`

**Triggers:** Push to `main` with changes in `wiki/**`

**Permissions:** `contents: write`

**Steps:**
1. Checkout main repo
2. Clone wiki repo: `git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/HanSur94/FastSense.wiki.git" wiki-remote`
3. Copy `wiki/*.md` → `wiki-remote/`
4. Commit and push to wiki repo if changes exist

This replaces the push step in the current `generate-docs.yml`, which should be updated to write to `wiki/` in the main repo and commit directly (API docs don't need LLM review).

### PR Format

```markdown
## Wiki Auto-Update

Pages regenerated:
- Dashboard-Engine-Guide.md (libs/Dashboard/ changed)
- Home.md (aggregate page)

Triggered by: commit <sha>

⚠️ Review carefully — LLM-generated content may contain inaccuracies.
```

## Quality Controls

### Auto-Generated Header

Every LLM-generated page includes (matching existing convention from `generate_api_docs.py`):
```markdown
<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->
```

### Guardrails

- **Large diff warning:** If `difflib.SequenceMatcher` ratio between old and new page is <0.2 (>80% different), log a warning in PR body.
- **Link validation:** After generation, verify all `[[wiki-links]]` reference pages that exist in `wiki/`.
- **No-op detection:** Skip pages where `difflib.SequenceMatcher` ratio is >0.95 (<5% different) — avoids noisy PRs.
- **Failure isolation:** If Claude API fails for one page, keep existing content and note failure in PR body; don't block other pages.
- **PR gate:** Only create a PR if at least one page was successfully regenerated with meaningful changes. Do not open PRs that contain only failure notes.
- **First-run expectation:** The initial full-refresh will produce large-diff warnings for all non-API pages since none currently carry the auto-generated header. This is expected and should not block PR creation on the first run.

### Excluded Pages (Not Regenerated)

- `_Sidebar.md` — Navigation structure, manually controlled
- `API-Reference:-*.md` — Owned by `generate_api_docs.py`
- `Installation.md` — Rarely changes, not source-derived

## Dependencies

- Python 3.12+
- `anthropic` Python package
- GitHub Actions with `ANTHROPIC_API_KEY` secret
- GitHub CLI (`gh`) for PR creation (pre-installed on GitHub runners)

## File Changes

| File | Action |
|---|---|
| `scripts/generate_wiki.py` | Create — main generation script |
| `.github/workflows/generate-wiki.yml` | Create — LLM wiki generation + PR workflow |
| `.github/workflows/sync-wiki.yml` | Create — sync wiki/ to wiki repo on merge |
| `.github/workflows/generate-docs.yml` | Update — write to main repo wiki/ instead of pushing directly to wiki repo |
| `wiki/*.md` | Track in git — one-time migration from untracked to tracked |

## Migration Steps

1. `git add wiki/` — start tracking wiki content in the main repo
2. Update `.github/workflows/generate-docs.yml` to write API docs to `wiki/` and commit to main (instead of cloning+pushing to wiki repo directly)
3. Add `sync-wiki.yml` to handle the wiki repo push
4. Add `generate-wiki.yml` and `scripts/generate_wiki.py`
5. Add `ANTHROPIC_API_KEY` to repository secrets
