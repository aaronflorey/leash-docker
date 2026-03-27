# iTerm title integration for Leash containers.
# Updates tab/window titles dynamically based on current path.

# Optional opt-out.
if [ "${LEASH_DISABLE_ITERM_TITLE:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# Default to iTerm only. Set LEASH_ITERM_TITLE_FORCE=1 to force in other terminals.
if [ "${LEASH_ITERM_TITLE_FORCE:-0}" != "1" ] && [ "${TERM_PROGRAM:-}" != "iTerm.app" ]; then
  return 0 2>/dev/null || exit 0
fi

# Run-once guard for this shell process.
if [ "${_LEASH_ITERM_TITLE_HOOKED:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi
_LEASH_ITERM_TITLE_HOOKED=1
export _LEASH_ITERM_TITLE_HOOKED

_leash_set_iterm_title() {
  local path tab_title window_title

  path="${PWD:-/}"
  tab_title="${path##*/}"
  if [ -z "$tab_title" ] || [ "$tab_title" = "/" ]; then
    tab_title="/"
  fi

  window_title="${USER:-user}@${HOSTNAME:-container}: ${path}"

  # OSC 1 = tab title, OSC 2 = window title
  printf '\033]1;%s\007' "$tab_title"
  printf '\033]2;%s\007' "$window_title"
}

if [ -n "${BASH_VERSION:-}" ]; then
  if [ -n "${PROMPT_COMMAND:-}" ]; then
    case ";$PROMPT_COMMAND;" in
      *";_leash_set_iterm_title;"*) ;;
      *) PROMPT_COMMAND="_leash_set_iterm_title;$PROMPT_COMMAND" ;;
    esac
  else
    PROMPT_COMMAND="_leash_set_iterm_title"
  fi
  export PROMPT_COMMAND
fi

if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null || true
  if command -v add-zsh-hook >/dev/null 2>&1; then
    add-zsh-hook precmd _leash_set_iterm_title 2>/dev/null || true
    add-zsh-hook chpwd _leash_set_iterm_title 2>/dev/null || true
  fi
fi

_leash_set_iterm_title
