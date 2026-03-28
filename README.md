# leash-docker

This image is a slim Leash target image built from `debian:bookworm-slim` with:

- `mise`
- `bun`
- `git`
- a custom entrypoint that scans the mounted repository at startup
- runtime/package manager installs based on detected lockfiles
- on-demand AI CLI install via `mise` registry based on invoked command (`codex`, `claude`, `gemini`, `qwen`, `opencode`)

## What it detects

- PHP via `composer.lock` or `composer.json`
  - installs `github:aaronflorey/php@8.4`
- Node.js for JS/TS repos via `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `bun.lock`, `bun.lockb`, `pnpm-lock.yaml`, `yarn.lock`, or `tsconfig.json`
  - prefers `.nvmrc` or `.node-version`, otherwise uses `node@lts`
- Bun via `bun.lock` or `bun.lockb`
  - prefers `packageManager: "bun@..."` from `package.json`
- pnpm via `pnpm-lock.yaml`
  - prefers `packageManager: "pnpm@..."` from `package.json`
- Yarn via `yarn.lock`
  - prefers `packageManager: "yarn@..."` from `package.json`
- Go via `go.mod` or `go.work`
  - prefers the `go` directive from `go.mod`
- Rust via `Cargo.lock`, `Cargo.toml`, `rust-toolchain`, or `rust-toolchain.toml`
  - prefers the Rust toolchain channel if present
- Python via `uv.lock`, `poetry.lock`, `Pipfile.lock`, `pyproject.toml`, or `requirements.txt`
  - prefers `.python-version` if present
- Zig via `build.zig`, `build.zig.zon`, or `.zig-version`
  - prefers `.zig-version` if present

## Build

```bash
docker build -t leash-mise .
```

## Use with Leash

Point Leash at the custom image for your project:

```toml
[projects."/absolute/path/to/project"]
target_image = "leash-mise:latest"
```

Or run it directly:

```bash
LEASH_TARGET_IMAGE=leash-mise:latest leash codex
```

## Persisting mise cache

The image uses `/opt/leash/mise` instead of `/root/...` so the mounted `mise` state still works when the container runs as a non-root user. The image creates that directory tree and makes it writable for arbitrary users.

Minimal example:

```toml
[global]
env = [
  "MISE_DATA_DIR=/opt/leash/mise/data",
  "MISE_CONFIG_DIR=/opt/leash/mise/config",
  "MISE_CACHE_DIR=/opt/leash/mise/cache",
  "BUN_INSTALL=/opt/leash/bun",
  "BUN_INSTALL_CACHE_DIR=/opt/leash/bun/cache",
]
volumes = [
  "$HOME/.cache/leash/mise/data:/opt/leash/mise/data",
  "$HOME/.cache/leash/mise/config:/opt/leash/mise/config",
  "$HOME/.cache/leash/mise/cache:/opt/leash/mise/cache",
  "$HOME/.cache/leash/bun:/opt/leash/bun",
]
```

Full example:

```toml
[global]
env = [
  "MISE_DATA_DIR=/opt/leash/mise/data",
  "MISE_CONFIG_DIR=/opt/leash/mise/config",
  "MISE_CACHE_DIR=/opt/leash/mise/cache",
  "BUN_INSTALL=/opt/leash/bun",
  "BUN_INSTALL_CACHE_DIR=/opt/leash/bun/cache",
]
volumes = [
  "$HOME/.cache/leash/mise/data:/opt/leash/mise/data",
  "$HOME/.cache/leash/mise/config:/opt/leash/mise/config",
  "$HOME/.cache/leash/mise/cache:/opt/leash/mise/cache",
  "$HOME/.cache/leash/bun:/opt/leash/bun",
]
```

This gives you:

- persistent installed runtimes and shims in `/opt/leash/mise/data`
- persistent `mise` config in `/opt/leash/mise/config`
- persistent download/build cache in `/opt/leash/mise/cache`

## Automatic config setup

The setup script now uses [dasel](https://daseldocs.tomwright.me/) to edit the TOML config.

Install `dasel` first:

```bash
brew install dasel
```

Run the setup script directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/aaronflorey/leash-docker/main/scripts/setup-leash-mise-config.sh | bash
```

Minimal mode:

```bash
curl -fsSL https://raw.githubusercontent.com/aaronflorey/leash-docker/main/scripts/setup-leash-mise-config.sh | bash -s -- --minimal
```

Or run the local script after cloning:

```bash
./scripts/setup-leash-mise-config.sh
```

```bash
./scripts/setup-leash-mise-config.sh --minimal
```

By default it updates:

```bash
~/.config/leash/config.toml
```

Or pass a custom config path:

```bash
./scripts/setup-leash-mise-config.sh --full /path/to/config.toml
```

The script:

- creates the config file if it does not exist
- adds the required `global.env` and `global.volumes` entries only when missing
- leaves unrelated config values untouched
- accepts `--minimal` and `--full` for compatibility (both now persist all mise/bun dirs)

## Notes

- The entrypoint installs tools on container startup, then `exec`s the original command.
- Set `LEASH_MISE_AUTO_INSTALL=0` to skip detection for a session.
