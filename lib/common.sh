#!/bin/bash

confirm() {
  local prompt answer
  prompt="$1"
  printf '%s ' "$prompt" >&2
  IFS= read -r answer || return 1
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

backup_file() {
  local file backup extra_backup
  file="$1"
  backup="${file}.dev-bootstrap.bak"

  [ -e "$file" ] || return 0
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    if [ ! -f "$backup" ] || [ -L "$backup" ]; then
      printf 'Backup path %s is not a regular file; leaving %s unchanged.\n' "$backup" "$file" >&2
      return 1
    fi
    if cmp -s "$file" "$backup"; then return 0; fi
    extra_backup="$(mktemp "${backup}.XXXXXX")" || return 1
    if ! cp -p "$file" "$extra_backup"; then
      rm -f "$extra_backup"
      return 1
    fi
    printf 'Saved current %s to %s.\n' "$file" "$extra_backup"
    return 0
  fi
  cp -p "$file" "$backup"
}
