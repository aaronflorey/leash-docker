#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/leash/mise/data/shims:/opt/leash/bun/bin:/usr/local/bin:${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

_leash_runtime_log() {
  printf '[leash-runtime] %s\n' "$*" >&2
}

_leash_runtime_install_mise_tool() {
  local executable="$1"
  local mise_spec="$2"
  local fallback_package_name="${3:-}"

  if command -v "$executable" >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p /tmp/leash-cli-bootstrap
  if [ -f "/tmp/leash-cli-bootstrap/${executable}.done" ]; then
    return 0
  fi

  if command -v mise >/dev/null 2>&1; then
    _leash_runtime_log "installing ${mise_spec} for '${executable}' via mise"
    if mise install "$mise_spec" >/dev/null 2>&1 && mise use -g "$mise_spec" >/dev/null 2>&1; then
      touch "/tmp/leash-cli-bootstrap/${executable}.done"
      return 0
    fi
  fi

  if [ -n "$fallback_package_name" ] && command -v bun >/dev/null 2>&1; then
    _leash_runtime_log "mise install failed, falling back to bun for ${fallback_package_name}"
    if bun add -g "$fallback_package_name" >/dev/null 2>&1; then
      touch "/tmp/leash-cli-bootstrap/${executable}.done"
      return 0
    fi
  fi

  _leash_runtime_log "warning: failed to install ${executable}"
  return 1
}

_leash_runtime_install_base_tools() {
  local marker="/tmp/leash-cli-bootstrap/base-tools.done"
  local tool_spec
  local executable
  local spec

  mkdir -p /tmp/leash-cli-bootstrap
  if [ -f "$marker" ]; then
    return 0
  fi

  # Keep defaults lean in the image and hydrate this toolchain via persisted mise dirs.
  for tool_spec in \
    "ast-grep|ast-grep@latest" \
    "fd|fd@latest" \
    "jq|jq@latest" \
    "yq|yq@latest" \
    "fzf|fzf@latest" \
    "rg|ripgrep@latest" \
    "difft|difftastic@latest" \
    "shellcheck|shellcheck@latest" \
    "sd|sd@latest" \
    "scc|github:boyter/scc@latest" \
    "comby|github:comby-tools/comby@latest"
  do
    executable="${tool_spec%%|*}"
    spec="${tool_spec##*|}"
    _leash_runtime_install_mise_tool "$executable" "$spec" || true
  done

  touch "$marker"
}

_leash_runtime_detect_and_install() {
  local arg

  for arg in "$@"; do
    case "$arg" in
      ''|-*)
        continue
        ;;
      codex|*/codex)
        _leash_runtime_install_mise_tool codex "codex@latest" "@openai/codex" || true
        return 0
        ;;
      claude|*/claude)
        _leash_runtime_install_mise_tool claude "claude@latest" "@anthropic-ai/claude-code" || true
        return 0
        ;;
      gemini|*/gemini)
        _leash_runtime_install_mise_tool gemini "gemini@latest" "@google/gemini-cli" || true
        return 0
        ;;
      qwen|*/qwen|qwen-code|*/qwen-code)
        _leash_runtime_install_mise_tool qwen "qwen@latest" "@qwen-code/qwen-code" || true
        return 0
        ;;
      opencode|*/opencode)
        _leash_runtime_install_mise_tool opencode "opencode@latest" "opencode-ai" || true
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  done

  return 0
}

_leash_runtime_install_base_tools
_leash_runtime_detect_and_install "$@"

exec "$@"
