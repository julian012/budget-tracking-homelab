# Issues Guide — AI Budget Tracking

How Issues, branches, and Pull Requests are handled in this repo.

> Repo: `github.com/<your-user>/<your-repo>`
> **GitHub issues** are the single source of truth for pending work.

---

## 1. Labels

Defined in `.github/labels.yml` and synced automatically by `.github/workflows/labels.yml` (push to `.github/labels.yml`).

| Category | Labels |
|-----------|--------|
| Layer | `layer:backend`, `layer:mobile`, `layer:mcp`, `layer:docs` |
| Priority | `priority:high`, `priority:medium`, `priority:low` |
| Type | `type:feature`, `type:bug`, `type:chore`, `type:test` |
| Process | `help wanted`, `good first issue` |

To manage labels manually: `gh label list`, `gh label create`.

---

## 2. Issue lifecycle

1. **Create** the issue in the GitHub UI or with `gh issue create --web`.
   - Bugs: `bug_report.yml` template. Features: `feature_request.yml` template (with **acceptance criteria**).
   - Label it with `layer:*` + `type:*` + `priority:*`.
2. **Assign** a milestone if applicable (v1.7.0, etc.) — they're created in the *Milestones* tab.
3. **Work on it** in a branch named after the issue:
   ```
   git switch -c feat/short-name   # or fix/…
   ```
4. **PR** when it's ready (see `PULL_REQUEST_TEMPLATE.md`) that closes the issue with `Closes #NUM`.
5. **Close** the issue when the PR is merged (the `Closes #N` reference does it automatically).

---

## 3. Branch conventions

| Prefix | Use |
|---------|-----|
| `feature/...` | New functionality |
| `fix/...` | Bug fix |
| `chore/...` | Maintenance, refactor, CI |
| `docs/...` | Documentation |

The `main` branch is production (stable). Deploy/build runs from `main`.

---

## 4. Quick `gh` commands

Manage issues/PRs from the terminal:

```bash
# List open issues
gh issue list

# Create an issue (opens an editor)
gh issue create

# Open the issues page in the browser
gh issue list --web

# Create a label
gh label create layer:backend --description "Go/chi/pgx" --color 1f6feb

# Close an issue when closing the PR
gh pr close #N --comment "Closes #NN"
```

---

## 5. Pre-PR checklist (summary of AGENTS.md)

- [ ] Tests for the affected layer pass (`make test-mobile` / `make test-backend`). Don't use `--no-verify`.
- [ ] `flutter analyze` clean (mobile).
- [ ] SQL migration with `.up.sql` + `.down.sql` if the schema changed.
- [ ] Docs updated in the same PR if the change affects visible behavior (`user-flows.md`, `README.md`, `docs/STYLE_GUIDE.md`, `docs/db-schema.md`, as applicable) — see "Documentation up to date" in `AGENTS.md`. It's not optional, not even for small features.
- [ ] No secrets or keys committed.

---

## 6. Pending work

Pending work lives **only** in GitHub Issues. Before starting any task, create (or
pick) an issue for it:

```bash
gh issue create --title "feat: minimum" \
  --body "user story…" \
  --label "layer:mobile,type:feature,priority:medium"
```

Link the issue from the PR (`Closes #N`) so it closes automatically when merged.
