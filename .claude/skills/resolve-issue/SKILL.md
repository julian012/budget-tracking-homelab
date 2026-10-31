---
name: resolve-issue
description: Standard workflow to pick up and resolve a GitHub issue in this repo, from branch creation to PR. Use when starting work on any gh issue.
---

## When to use

When starting work on any GitHub issue in this repo (`gh issue list`), whether `type:bug`, `type:feature`, `type:chore`, or `type:test`.

## Flow

1. **Read the full issue**: `gh issue view <N>`. The `layer:*`/`type:*`/`priority:*` labels indicate the affected layer and the type of change.
2. **Create the branch** from an updated `main`, with the prefix matching `type:*` (`docs/ISSUES_GUIDE.md` convention):
   - `type:feature` → `feature/<short-name>`
   - `type:bug` → `fix/<short-name>`
   - `type:chore` / `type:test` → `chore/<short-name>`
   - Documentation only → `docs/<short-name>`
   ```bash
   git switch main && git pull
   git switch -c fix/short-name
   ```
3. **Before touching code**, run the affected layer's test suite to get a green baseline (`run-tests` skill).
4. **Implement the change** following `AGENTS.md`. If the issue touches `backend/internal/{handler,service,middleware}`, also review the `backend-security-review` skill; if it touches `mobile/lib/`, review `flutter-consistency-check`.
5. **Update the documentation in the same change, not afterwards** (`AGENTS.md` §"Documentation up to date" rule — applies even to small features):
   - New/modified user flow → `user-flows.md`
   - New/modified endpoint or API contract → `README.md` ("API Endpoints" table)
   - New/modified UI pattern/component → `docs/STYLE_GUIDE.md`
   - DB schema (in addition to the migration) → `docs/db-schema.md`
   - New/renamed/moved mobile screen/widget → `user-flows.md`
   - If none of these apply (internal refactor, chore with no visible effect), no docs change is needed — but that is the exception, not the default rule.
6. **Before opening the PR**, use the checklist in `docs/ISSUES_GUIDE.md` §5:
   - [ ] Layer tests green (`make test-mobile` / `make test-backend`) — **do not use `--no-verify`**
   - [ ] `flutter analyze` with no errors (mobile) / clean `go vet ./...` + `gofmt -l .` (backend)
   - [ ] `.up.sql` + `.down.sql` migration if the schema changed
   - [ ] Documentation from step 5 applied (not left for later)
   - [ ] No committed secrets or keys
7. **Open the PR** referencing `Closes #N` in the description (`.github/PULL_REQUEST_TEMPLATE.md`) — the merge closes the issue automatically.

## Note

This skill exists as an identical duplicate in `.opencode/skills/resolve-issue/SKILL.md` and `.claude/skills/resolve-issue/SKILL.md`. It used to live in `skills/` with symlinks from both paths, but Portainer refuses to clone repos with symlinks (#64) — if you edit this skill, replicate the change in both copies.
