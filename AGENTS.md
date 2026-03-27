# Repository Guidelines

## Project Structure & Module Organization
This repository builds a custom Leash target image and vendors the upstream Leash source as a git submodule.

- Root: image customization and onboarding.
- [`Dockerfile`](/Users/aaronflorey/Code/leash-docker-image/Dockerfile): target image definition.
- [`entrypoint.sh`](/Users/aaronflorey/Code/leash-docker-image/entrypoint.sh): runtime/tool auto-detection script loaded via `/etc/profile.d`.
- [`scripts/setup-leash-mise-config.sh`](/Users/aaronflorey/Code/leash-docker-image/scripts/setup-leash-mise-config.sh): host config bootstrap helper.
- `leash/`: upstream CLI/runtime source.
  - `leash/cmd`, `leash/internal`: Go application code.
  - `leash/controlui/web`: web UI code (pnpm/Next.js).
  - `leash/e2e`: end-to-end tests.
  - `leash/docs`: design and developer docs.

## Build, Test, and Development Commands
- `docker build -t leash-mise .`: build this custom image.
- `./scripts/setup-leash-mise-config.sh --minimal`: patch local `~/.config/leash/config.toml`.
- `cd leash && make build`: build Leash binaries into `leash/bin/`.
- `cd leash && make test`: run Go, UI, and e2e test suites.
- `cd leash && make test-unit`: run Go unit tests only (`go test ./...`).
- `cd leash && make test-e2e`: run integration tests via `test_e2e.sh`.
- `cd leash && make dev`: build and run a local dev command (defaults to `codex shell`).

## Coding Style & Naming Conventions
- Shell scripts: `bash`, `set -euo pipefail` for non-trivial scripts, snake_case function names with project prefixes (for example `_leash_mise_*`).
- Go code (in `leash/`): keep `goimports` clean; run `cd leash && make fmt`.
- Prefer small, focused changes; avoid unrelated refactors in the same commit.
- Keep file names descriptive and consistent with existing patterns (`*-test`, `*_test.go`, `build-*`).

## Testing Guidelines
- Primary framework is Go’s standard test runner (`go test`), with web tests under `leash/controlui/web`.
- Add or update tests when behavior changes, especially in `leash/internal/*` and `leash/e2e/*`.
- Name Go tests with `Test...` and colocate them as `*_test.go`.
- Run the narrowest target first (`make test-unit`), then full `make test` before opening a PR.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style seen in history: `feat: ...`, `fix: ...`, `chore(...): ...`.
- Use imperative, scoped subjects when helpful (example: `fix(docker): add profile.d title hook`).
- PRs should include:
  - What changed and why.
  - Test evidence (commands run and outcomes).
  - Config/runtime impact (env vars, mounts, image tags).
  - Screenshots only when UI behavior changed.
