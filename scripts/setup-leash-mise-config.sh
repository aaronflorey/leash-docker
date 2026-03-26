#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/setup-leash-mise-config.sh [--minimal|--full] [config-path]

Options:
  --minimal   Add only MISE_DATA_DIR and its volume mount.
  --full      Add MISE_DATA_DIR, MISE_CONFIG_DIR, MISE_CACHE_DIR and all mounts.

Defaults:
  mode: --full
  config-path: $XDG_CONFIG_HOME/leash/config.toml or ~/.config/leash/config.toml
USAGE
}

MODE="full"
CONFIG_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --minimal)
      MODE="minimal"
      shift
      ;;
    --full)
      MODE="full"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -n "$CONFIG_PATH" ]; then
        printf 'Unexpected extra argument: %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      CONFIG_PATH="$1"
      shift
      ;;
  esac
done

if [ "$#" -gt 0 ]; then
  printf 'Unexpected extra argument: %s\n' "$1" >&2
  usage >&2
  exit 1
fi

if ! command -v dasel >/dev/null 2>&1; then
  printf 'dasel is required. Install it first, for example: brew install dasel\n' >&2
  exit 1
fi

CONFIG_PATH="${CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/leash/config.toml}"
CONFIG_DIR="$(dirname "$CONFIG_PATH")"

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_PATH"

array_contains() {
  local selector="$1"
  local wanted="$2"
  local count

  count="$(dasel -i toml "len(${selector}.filter(\$this == \"${wanted}\"))" < "$CONFIG_PATH" 2>/dev/null)" || return 1
  [ "$count" -gt 0 ] 2>/dev/null
}

set_value() {
  local selector="$1"
  local value="$2"
  local parent="${selector%.*}"
  local leaf="${selector##*.}"
  local current

  current="$(dasel -i toml "${selector}" < "$CONFIG_PATH" 2>/dev/null)" || true
  if [ "$current" = "'${value}'" ] || [ "$current" = "\"${value}\"" ] || [ "$current" = "$value" ]; then
    printf 'Value already set: %s = %s\n' "$selector" "$value"
    return 0
  fi

  printf 'Setting: %s = %s\n' "$selector" "$value"
  local query="\$root = {\$root..., \"${parent}\": {(\$root.${parent} ?? {})..., \"${leaf}\": \"${value}\"}}"
  dasel -i toml -o toml --root "$query" \
    < "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" \
    && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
}

append_if_missing() {
  local selector="$1"
  local value="$2"

  if array_contains "${selector}" "$value"; then
    printf 'Value already exists: %s\n' "$value"
    return 0
  fi

  printf 'Appending value: %s\n' "$value"
  local parent="${selector%.*}"
  local leaf="${selector##*.}"
  local query="\$root = {\$root..., \"${parent}\": {(\$root.${parent} ?? {})..., \"${leaf}\": [(\$root.${selector} ?? [])..., \"${value}\"]}}"
  dasel -i toml -o toml --root "$query" \
    < "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" \
    && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
}

ENV_VALUES=(
  'MISE_DATA_DIR=/opt/leash/mise/data'
)
VOLUME_VALUES=(
  '$HOME/.cache/leash/mise/data:/opt/leash/mise/data'
  '$HOME/.config/gh:/root/.config/gh:ro'
)

if [ "$MODE" = "full" ]; then
  ENV_VALUES+=(
    'MISE_CONFIG_DIR=/opt/leash/mise/config'
    'MISE_CACHE_DIR=/opt/leash/mise/cache'
  )
  VOLUME_VALUES+=(
    '$HOME/.cache/leash/mise/config:/opt/leash/mise/config'
    '$HOME/.cache/leash/mise/cache:/opt/leash/mise/cache'
  )
fi

set_value 'leash.target_image' 'ghcr.io/aaronflorey/leash-docker:latest'

for value in "${ENV_VALUES[@]}"; do
  append_if_missing 'global.env' "$value"
done

for value in "${VOLUME_VALUES[@]}"; do
  append_if_missing 'global.volumes' "$value"
done

printf 'Updated %s\n' "$CONFIG_PATH"
