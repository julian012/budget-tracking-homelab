# Pull Request — AI Budget Tracking

Thanks for contributing. Before merging, check that you complete the following checklist.

## What does this PR resolve?

<!-- Reference the issue it closes (it closes automatically):
  - Closes #12                (closes the issue on merge)
  - Fixes #NUM
  - Resolves #NUM
-->
> **Closes #** (write the issue number)

<!-- Omit this block for a minor refactor / chore without an issue -->

## Description

<!-- Brief description of the change and why. -->

## Modified layers

- [ ] **mobile** (Flutter)
- [ ] **backend** (Go)
- [ ] **mcp-server** (Python)
- [ ] **docs / scripts / infra**

## AGENTS.md checklist

- [ ] I ran the affected layer's tests (do not use `--no-verify`)
  - `make test-mobile` / `make test-backend` (requires `budget_test`)
- [ ] `flutter analyze` with no errors (mobile)
- [ ] `go test ./...` green (backend)
- [ ] I added/updated tests where applicable (`_test.go`, `test_*.py`, `*_test.dart`)
- [ ] I added a SQL migration if the schema changed (`backend/migrations/*.up.sql` + `.down.sql`)
- [ ] I updated the docs (`user-flows.md`, `docs/STYLE_GUIDE.md`) if applicable
- [ ] No secrets or keys are committed

## Expected behavior / screenshots

<!-- Screenshot or description of the result if applicable -->
