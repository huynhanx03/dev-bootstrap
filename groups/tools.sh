#!/bin/bash

OPTIONAL_ITEMS=(warp datagrip bruno raycast mise)

tools_find_brew() {
  if command -v brew >/dev/null 2>&1; then command -v brew
  elif [ -x /opt/homebrew/bin/brew ]; then printf '/opt/homebrew/bin/brew\n'
  elif [ -x /usr/local/bin/brew ]; then printf '/usr/local/bin/brew\n'
  else return 1
  fi
}

tools_git_available() {
  local found
  found="$(command -v git 2>/dev/null)" || return 1
  [ "$found" != /usr/bin/git ] || xcode-select -p >/dev/null 2>&1
}

tools_formula_installed() {
  local brew_bin versions
  brew_bin="$(tools_find_brew)" || return 1
  versions="$("$brew_bin" list --formula --versions "$1" 2>/dev/null)"
  [ -n "$versions" ]
}

tools_cask_installed() {
  local brew_bin versions
  brew_bin="$(tools_find_brew)" || return 1
  versions="$("$brew_bin" list --cask --versions "$1" 2>/dev/null)"
  [ -n "$versions" ]
}

tools_app_name() {
  case "$1" in
    warp) printf 'Warp.app\n' ;;
    datagrip) printf 'DataGrip.app\n' ;;
    bruno) printf 'Bruno.app\n' ;;
    raycast) printf 'Raycast.app\n' ;;
    *) return 1 ;;
  esac
}

tools_item_installed() {
  local app
  case "$1" in
    mise) command -v mise >/dev/null 2>&1 || tools_formula_installed mise ;;
    warp|datagrip|bruno|raycast)
      app="$(tools_app_name "$1")" || return 1
      [ -d "/Applications/$app" ] || [ -d "$HOME/Applications/$app" ] || tools_cask_installed "$1"
      ;;
    *) return 1 ;;
  esac
}

tools_item_status() {
  if tools_item_installed "$1"; then printf 'installed\n'; else printf 'missing\n'; fi
}

tools_brew_preview() {
  local brew_bin
  if brew_bin="$(tools_find_brew)"; then
    printf '  - Homebrew: installed at %s; skip.\n' "$brew_bin"
    if ! command -v brew >/dev/null 2>&1; then
      printf '    Add Homebrew to ~/.zprofile for future zsh sessions.\n'
    fi
  else
    printf '  - Homebrew: missing; install first.\n'
  fi
}

tools_git_preview() {
  if tools_git_available; then printf '  - Git: installed; skip.\n'
  elif tools_formula_installed git; then printf '  - Git: formula installed but command unavailable; resolve PATH.\n'
  else printf '  - Git: missing; brew install git.\n'
  fi
}

tools_item_preview() {
  if tools_item_installed "$1"; then
    printf '  - %s: installed; skip.\n' "$1"
  elif [ "$1" = mise ]; then
    printf '  - mise: missing; brew install mise.\n'
  else
    printf '  - %s: missing; brew install --cask %s.\n' "$1" "$1"
  fi
}

tools_ensure_brew_path() {
  local brew_bin shellenv zprofile start_marker end_marker has_start has_end
  brew_bin="$(tools_find_brew)" || return 1
  if command -v brew >/dev/null 2>&1; then return 0; fi
  shellenv="$("$brew_bin" shellenv)" || return 1
  [ -n "$shellenv" ] || return 1
  zprofile="$HOME/.zprofile"
  start_marker='# >>> dev-bootstrap Homebrew PATH >>>'
  end_marker='# <<< dev-bootstrap Homebrew PATH <<<'
  has_start=0
  has_end=0
  if [ -L "$zprofile" ] || { [ -e "$zprofile" ] && [ ! -f "$zprofile" ]; }; then
    printf 'Cannot update symlinked or non-file ~/.zprofile.\n' >&2
    return 1
  fi
  if [ -e "$zprofile" ]; then
    grep -Fq "$start_marker" "$zprofile" && has_start=1
    grep -Fq "$end_marker" "$zprofile" && has_end=1
    if [ "$has_start" -ne "$has_end" ]; then
      printf 'Incomplete Homebrew PATH block in ~/.zprofile; leaving it unchanged.\n' >&2
      return 1
    fi
  fi
  if [ "$has_start" -eq 0 ]; then
    backup_file "$zprofile" || return 1
    {
      printf '\n%s\n' "$start_marker"
      printf 'if [ -x /opt/homebrew/bin/brew ]; then\n'
      printf '  eval "$(/opt/homebrew/bin/brew shellenv)"\n'
      printf 'elif [ -x /usr/local/bin/brew ]; then\n'
      printf '  eval "$(/usr/local/bin/brew shellenv)"\n'
      printf 'fi\n%s\n' "$end_marker"
    } >> "$zprofile" || return 1
  fi
  eval "$shellenv"
}

tools_install_brew() {
  local installer_script
  if tools_find_brew >/dev/null; then
    printf 'Homebrew already installed; skipped.\n'
    tools_ensure_brew_path
    return $?
  fi
  if ! confirm 'Install Homebrew using its official install script? [y/N]'; then
    printf 'Homebrew installation declined.\n'
    return 2
  fi
  command -v curl >/dev/null 2>&1 || { printf 'curl is required.\n' >&2; return 1; }
  installer_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
  [ -n "$installer_script" ] || return 1
  /bin/bash -c "$installer_script" || return 1
  tools_find_brew >/dev/null || return 1
  tools_ensure_brew_path
}

tools_install_formula() {
  local brew_bin
  brew_bin="$(tools_find_brew)" || return 1
  if tools_formula_installed "$1"; then
    printf '%s already installed; skipped.\n' "$1"
    return 0
  fi
  "$brew_bin" install "$1" || return 1
  tools_formula_installed "$1"
}

tools_install_git() {
  if tools_git_available; then printf 'Git already installed; skipped.\n'; return 0; fi
  if tools_formula_installed git; then
    printf 'Git formula installed but command unavailable; check PATH.\n' >&2
    return 1
  fi
  tools_install_formula git || return 1
  hash -r
  tools_git_available
}

tools_install_item() {
  local brew_bin
  if tools_item_installed "$1"; then printf '%s already installed; skipped.\n' "$1"; return 0; fi
  if [ "$1" = mise ]; then
    tools_install_formula mise || return 1
  else
    brew_bin="$(tools_find_brew)" || return 1
    "$brew_bin" install --cask "$1" || return 1
  fi
  tools_item_installed "$1"
}
