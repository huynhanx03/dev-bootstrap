#!/bin/bash

zsh_managed_block() {
  printf '%s\n' '# >>> dev-bootstrap managed zsh config >>>'
  printf 'if [ -r "$HOME/.config/dev-bootstrap/zshrc" ]; then\n'
  printf '  source "$HOME/.config/dev-bootstrap/zshrc"\n'
  printf 'fi\n'
  printf '%s\n' '# <<< dev-bootstrap managed zsh config <<<'
}

# Return 0 for the exact managed block, 1 when absent, or 2 when malformed.
zsh_block_state() {
  local file start_marker end_marker starts ends actual expected
  file="$1"
  [ -e "$file" ] || return 1
  [ -f "$file" ] && [ -r "$file" ] || return 2
  start_marker='# >>> dev-bootstrap managed zsh config >>>'
  end_marker='# <<< dev-bootstrap managed zsh config <<<'
  starts="$(grep -Fxc "$start_marker" "$file")"
  ends="$(grep -Fxc "$end_marker" "$file")"
  if [ "$starts" -eq 0 ] && [ "$ends" -eq 0 ]; then return 1; fi
  if [ "$starts" -ne 1 ] || [ "$ends" -ne 1 ]; then return 2; fi
  actual="$(awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { in_block = 1 }
    in_block { print }
    $0 == end && in_block { exit }
  ' "$file")"
  expected="$(zsh_managed_block)"
  [ "$actual" = "$expected" ]
}

zsh_status() {
  local zshrc config_dir managed prompt block_state
  zshrc="$HOME/.zshrc"
  config_dir="$HOME/.config/dev-bootstrap"
  managed="$config_dir/zshrc"
  prompt="$config_dir/p10k.zsh"

  if [ -L "$zshrc" ] || [ -L "$HOME/.config" ] || [ -L "$config_dir" ] || [ -L "$managed" ] || [ -L "$prompt" ]; then
    printf 'needs attention\n'
    return
  fi
  zsh_block_state "$zshrc"
  block_state=$?
  if [ "$block_state" -eq 2 ]; then printf 'needs attention\n'; return; fi
  if [ -e "$managed" ]; then
    if [ ! -f "$managed" ] || ! cmp -s "$DEV_BOOTSTRAP_ROOT/config/zshrc" "$managed"; then
      printf 'needs attention\n'
      return
    fi
  fi
  if [ -e "$prompt" ] && { [ ! -f "$prompt" ] || ! cmp -s "$DEV_BOOTSTRAP_ROOT/config/p10k.zsh" "$prompt"; }; then
    printf 'needs attention\n'
    return
  fi
  if [ "$block_state" -eq 0 ] && [ -f "$managed" ] && [ -f "$prompt" ]; then
    printf 'configured\n'
  else
    printf 'missing\n'
  fi
}

zsh_preview() {
  local zshrc config_dir managed prompt block_state
  zshrc="$HOME/.zshrc"
  config_dir="$HOME/.config/dev-bootstrap"
  managed="$config_dir/zshrc"
  prompt="$config_dir/p10k.zsh"

  printf '  - zsh: install Powerlevel10k, Meslo font, autosuggestions if missing.\n'
  printf '    Copy zsh settings and current prompt design to %s\n' "$config_dir"
  if [ -L "$zshrc" ] || [ -L "$HOME/.config" ] || [ -L "$config_dir" ] || [ -L "$managed" ] || [ -L "$prompt" ]; then
    printf '    A zsh config path is a symlink; this group will stop safely without changing it.\n'
  fi
  if [ -e "$managed" ]; then
    if [ -f "$managed" ] && cmp -s "$DEV_BOOTSTRAP_ROOT/config/zshrc" "$managed"; then
      printf '    The installed file matches the repository version and will be kept.\n'
    else
      printf '    Existing file differs from the repository version; this group will stop safely rather than replace it.\n'
    fi
  else
    printf '    The destination does not exist and will be created.\n'
  fi
  if [ -e "$prompt" ] && { [ ! -f "$prompt" ] || ! cmp -s "$DEV_BOOTSTRAP_ROOT/config/p10k.zsh" "$prompt"; }; then
    printf '    Existing p10k.zsh differs; this group will stop without replacing it.\n'
  fi
  zsh_block_state "$zshrc"
  block_state=$?
  case "$block_state" in
    0) printf '  - Existing managed source block in %s will be kept.\n' "$zshrc" ;;
    1)
      if [ -e "$zshrc" ]; then
        printf '  - Append one managed source block to %s; back it up first.\n' "$zshrc"
      else
        printf '  - Create %s with one managed source block.\n' "$zshrc"
      fi
      ;;
    2) printf '  - The managed block in %s is malformed; zsh setup will stop safely.\n' "$zshrc" ;;
  esac
}

zsh_apply() {
  local zshrc config_dir managed prompt block_state
  zshrc="$HOME/.zshrc"
  config_dir="$HOME/.config/dev-bootstrap"
  managed="$config_dir/zshrc"
  prompt="$config_dir/p10k.zsh"

  if [ -L "$zshrc" ] || [ -L "$HOME/.config" ] || [ -L "$config_dir" ] || [ -L "$managed" ] || [ -L "$prompt" ]; then
    printf 'Refusing to modify a symlinked zsh config path; resolve it manually first.\n' >&2
    return 1
  fi
  if [ -e "$zshrc" ] && [ ! -f "$zshrc" ]; then
    printf '%s is not a regular file; leaving it unchanged.\n' "$zshrc" >&2
    return 1
  fi

  zsh_block_state "$zshrc"
  block_state=$?
  if [ "$block_state" -eq 2 ]; then
    printf 'Found a malformed dev-bootstrap block in %s; leaving it unchanged.\n' "$zshrc" >&2
    return 1
  fi

  if [ -e "$managed" ]; then
    if [ ! -f "$managed" ] || ! cmp -s "$DEV_BOOTSTRAP_ROOT/config/zshrc" "$managed"; then
      printf 'The managed zsh config already exists and differs from the repository version; leaving it unchanged. Merge or remove it manually before retrying.\n' >&2
      return 1
    fi
  fi
  if [ -e "$prompt" ]; then
    if [ ! -f "$prompt" ] || ! cmp -s "$DEV_BOOTSTRAP_ROOT/config/p10k.zsh" "$prompt"; then
      printf 'The managed p10k.zsh already exists and differs; leaving it unchanged.\n' >&2
      return 1
    fi
  fi

  mkdir -p "$config_dir" || return 1
  if [ ! -e "$managed" ]; then
    cp "$DEV_BOOTSTRAP_ROOT/config/zshrc" "$managed" || return 1
  fi
  if [ ! -e "$prompt" ]; then
    cp "$DEV_BOOTSTRAP_ROOT/config/p10k.zsh" "$prompt" || return 1
  fi

  if [ "$block_state" -eq 1 ]; then
    backup_file "$zshrc" || return 1
    {
      printf '\n'
      zsh_managed_block
    } >> "$zshrc" || return 1
  fi

  printf 'Managed zsh settings installed. Open a new terminal to load them.\n'
}

zsh_font_installed() {
  tools_cask_installed font-meslo-for-powerlevel10k ||
    [ -f "$HOME/Library/Fonts/MesloLGS NF Regular.ttf" ]
}

zsh_install_dependencies() {
  local brew_bin
  brew_bin="$(tools_find_brew)" || return 1
  tools_install_formula powerlevel10k || return 1
  tools_install_formula zsh-autosuggestions || return 1
  if zsh_font_installed; then
    printf 'Meslo font already installed; skipped.\n'
  else
    "$brew_bin" install --cask font-meslo-for-powerlevel10k || return 1
    zsh_font_installed || return 1
  fi
}
