#!/usr/bin/env bash
# Sourced by login shells via /etc/profile.d/.
# Detects project tooling and installs runtimes via mise on first login.

# Run-once guard: skip if already ran in this container.
if [ -f /tmp/.leash-mise-installed ]; then
  return 0 2>/dev/null || exit 0
fi

_leash_mise_log() {
  printf '[leash-mise] %s\n' "$*" >&2
}

_leash_mise_trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

_leash_mise_resolve_repo_dir() {
  local dir="${LEASH_REPO_DIR:-$PWD}"
  local current

  if command -v git >/dev/null 2>&1; then
    local toplevel
    if toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s\n' "$toplevel"
      return 0
    fi
  fi

  current="$dir"
  while [ "$current" != "/" ]; do
    if [ -e "$current/.git" ]; then
      printf '%s\n' "$current"
      return 0
    fi
    current="$(dirname "$current")"
  done

  printf '%s\n' "$dir"
}

_leash_mise_scan_repo_files() {
  _REPO_FILES="$(find "$_LEASH_REPO_DIR" \
    \( -path '*/.git' -o -path '*/node_modules' -o -path '*/vendor' -o -path '*/target' -o -path '*/dist' -o -path '*/build' \) -prune \
    -o -type f -print 2>/dev/null | sed 's|.*/||' | sort -u)"
}

_leash_mise_repo_has() {
  local name
  for name in "$@"; do
    if printf '%s\n' "$_REPO_FILES" | grep -qxF "$name"; then
      return 0
    fi
  done
  return 1
}

_leash_mise_read_root_file() {
  local path="$1"
  if [ -f "$path" ]; then
    head -n 1 "$path"
  fi
}

_leash_mise_parse_go_version() {
  local version
  version="$(awk '/^go / { print $2; exit }' "$_LEASH_REPO_DIR/go.mod" 2>/dev/null || true)"
  _leash_mise_trim "$version"
}

_leash_mise_parse_rust_version() {
  local version=""

  if [ -f "$_LEASH_REPO_DIR/rust-toolchain.toml" ]; then
    version="$(sed -n 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$_LEASH_REPO_DIR/rust-toolchain.toml" | head -n 1)"
  elif [ -f "$_LEASH_REPO_DIR/rust-toolchain" ]; then
    version="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "$_LEASH_REPO_DIR/rust-toolchain")"
  fi

  _leash_mise_trim "$version"
}

_leash_mise_parse_package_manager_version() {
  local manager="$1"
  local version=""

  if [ -f "$_LEASH_REPO_DIR/package.json" ]; then
    version="$(sed -n "s/.*\"packageManager\"[[:space:]]*:[[:space:]]*\"${manager}@\([^\"]*\)\".*/\1/p" "$_LEASH_REPO_DIR/package.json" | head -n 1)"
  fi

  _leash_mise_trim "$version"
}

_leash_mise_ensure_tool() {
  local spec="$1"

  if [ -z "$spec" ]; then
    return 0
  fi

  if mise install "$spec" >/dev/null 2>&1 && mise use -g "$spec" >/dev/null 2>&1; then
    _leash_mise_log "installed $spec"
    return 0
  fi

  _leash_mise_log "warning: failed to install $spec"
  return 1
}

_leash_mise_install() {
  local node_version bun_version pnpm_version yarn_version
  local go_version rust_version python_version zig_version

  _leash_mise_scan_repo_files

  if _leash_mise_repo_has composer.lock composer.json; then
    _leash_mise_ensure_tool "github:aaronflorey/php@8.4" || true
  fi

  if _leash_mise_repo_has package.json package-lock.json npm-shrinkwrap.json bun.lock bun.lockb pnpm-lock.yaml yarn.lock tsconfig.json; then
    node_version="$(_leash_mise_trim "$(_leash_mise_read_root_file "$_LEASH_REPO_DIR/.nvmrc")")"
    if [ -z "$node_version" ]; then
      node_version="$(_leash_mise_trim "$(_leash_mise_read_root_file "$_LEASH_REPO_DIR/.node-version")")"
    fi
    if [ -z "$node_version" ]; then
      node_version="lts"
    fi
    _leash_mise_ensure_tool "node@${node_version}" || true
  fi

  if _leash_mise_repo_has bun.lock bun.lockb; then
    bun_version="$(_leash_mise_parse_package_manager_version bun)"
    if [ -z "$bun_version" ]; then
      bun_version="latest"
    fi
    _leash_mise_ensure_tool "bun@${bun_version}" || true
  fi

  if _leash_mise_repo_has pnpm-lock.yaml; then
    pnpm_version="$(_leash_mise_parse_package_manager_version pnpm)"
    if [ -z "$pnpm_version" ]; then
      pnpm_version="latest"
    fi
    _leash_mise_ensure_tool "pnpm@${pnpm_version}" || true
  fi

  if _leash_mise_repo_has yarn.lock; then
    yarn_version="$(_leash_mise_parse_package_manager_version yarn)"
    if [ -z "$yarn_version" ]; then
      yarn_version="latest"
    fi
    _leash_mise_ensure_tool "yarn@${yarn_version}" || true
  fi

  if _leash_mise_repo_has go.mod go.work; then
    go_version="$(_leash_mise_parse_go_version)"
    if [ -z "$go_version" ]; then
      go_version="latest"
    fi
    _leash_mise_ensure_tool "go@${go_version}" || true
  fi

  if _leash_mise_repo_has Cargo.lock Cargo.toml rust-toolchain rust-toolchain.toml; then
    rust_version="$(_leash_mise_parse_rust_version)"
    if [ -z "$rust_version" ]; then
      rust_version="stable"
    fi
    _leash_mise_ensure_tool "rust@${rust_version}" || true
  fi

  if _leash_mise_repo_has uv.lock poetry.lock Pipfile.lock pyproject.toml requirements.txt; then
    python_version="$(_leash_mise_trim "$(_leash_mise_read_root_file "$_LEASH_REPO_DIR/.python-version")")"
    if [ -z "$python_version" ]; then
      python_version="latest"
    fi
    _leash_mise_ensure_tool "python@${python_version}" || true
  fi

  if _leash_mise_repo_has build.zig build.zig.zon .zig-version; then
    zig_version="$(_leash_mise_trim "$(_leash_mise_read_root_file "$_LEASH_REPO_DIR/.zig-version")")"
    if [ -z "$zig_version" ]; then
      zig_version="latest"
    fi
    _leash_mise_ensure_tool "zig@${zig_version}" || true
  fi
}

# --- Main ---

if [ "${LEASH_MISE_AUTO_INSTALL:-1}" = "0" ]; then
  _leash_mise_log "auto-install disabled"
elif ! command -v mise >/dev/null 2>&1; then
  _leash_mise_log "warning: mise is not available, skipping runtime detection"
else
  _LEASH_REPO_DIR="$(_leash_mise_resolve_repo_dir)"
  if [ -d "$_LEASH_REPO_DIR" ]; then
    _leash_mise_log "scanning $_LEASH_REPO_DIR"
    _leash_mise_install
  fi
  unset _LEASH_REPO_DIR _REPO_FILES
fi

touch /tmp/.leash-mise-installed

# Clean up function names from the shell namespace.
unset -f _leash_mise_log _leash_mise_trim _leash_mise_resolve_repo_dir \
  _leash_mise_scan_repo_files _leash_mise_repo_has _leash_mise_read_root_file \
  _leash_mise_parse_go_version _leash_mise_parse_rust_version \
  _leash_mise_parse_package_manager_version _leash_mise_ensure_tool \
  _leash_mise_install
