#!/bin/bash

DEV_BOOTSTRAP_ROOT="$(cd "$(dirname "$0")" && pwd)"
export DEV_BOOTSTRAP_ROOT

usage() {
  printf 'Usage: ./bootstrap.sh [--help]\n\n'
  printf 'Checks Homebrew and Git, then lets you select apps and zsh settings.\n'
  printf 'Shows the ordered plan and asks before making changes.\n'
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
fi

if [ "$(uname -s)" != Darwin ]; then
  printf 'dev-bootstrap currently supports macOS only. No changes were made.\n' >&2
  exit 1
fi
if [ ! -t 0 ] || [ ! -t 1 ]; then
  printf 'Run ./bootstrap.sh from an interactive terminal. No changes were made.\n' >&2
  exit 1
fi

. "$DEV_BOOTSTRAP_ROOT/lib/common.sh"
. "$DEV_BOOTSTRAP_ROOT/groups/tools.sh"
. "$DEV_BOOTSTRAP_ROOT/groups/zsh.sh"

SELECT_ZSH=0
ITEM_SELECTED=()
for ((i=0; i<${#OPTIONAL_ITEMS[@]}; i++)); do ITEM_SELECTED[i]=0; done

show_menu() {
  local i check brew_status git_status zsh_check
  if tools_find_brew >/dev/null; then brew_status=installed; else brew_status=missing; fi
  if tools_git_available; then git_status=installed; else git_status=missing; fi
  printf '\nRequired foundation (checked and installed if missing):\n'
  printf '  • Homebrew [%s]\n' "$brew_status"
  printf '  • Git [%s]\n' "$git_status"
  printf '\nSelect optional items (type a number to toggle):\n'
  for ((i=0; i<${#OPTIONAL_ITEMS[@]}; i++)); do
    check=' '
    [ "${ITEM_SELECTED[i]}" -eq 1 ] && check=x
    printf '  %d) [%s] %s [%s]\n' "$((i + 1))" "$check" "${OPTIONAL_ITEMS[i]}" "$(tools_item_status "${OPTIONAL_ITEMS[i]}")"
  done
  zsh_check=' '
  [ "$SELECT_ZSH" -eq 1 ] && zsh_check=x
  printf '  %d) [%s] zsh settings [%s]\n' "$((${#OPTIONAL_ITEMS[@]} + 1))" "$zsh_check" "$(zsh_status)"
  printf '  0) Review plan\n'
  printf '  q) Quit\n'
}

while :; do
  show_menu
  printf 'Choose an option: '
  IFS= read -r choice || { printf '\nUnable to read selection. No changes were made.\n' >&2; exit 1; }
  case "$choice" in
    0) break ;;
    q|Q) printf 'Cancelled. No changes were made.\n'; exit 0 ;;
    *[!0-9]*|'') printf 'Choose a listed number or q.\n' ;;
    *)
      if [ "$choice" -ge 1 ] && [ "$choice" -le "${#OPTIONAL_ITEMS[@]}" ]; then
        index=$((choice - 1))
        ITEM_SELECTED[index]=$((1 - ITEM_SELECTED[index]))
      elif [ "$choice" -eq "$((${#OPTIONAL_ITEMS[@]} + 1))" ]; then
        SELECT_ZSH=$((1 - SELECT_ZSH))
      else
        printf 'Choose a listed number or q.\n'
      fi
      ;;
  esac
done

printf '\nPlan, in execution order:\n'
tools_brew_preview
tools_git_preview
for ((i=0; i<${#OPTIONAL_ITEMS[@]}; i++)); do
  [ "${ITEM_SELECTED[i]}" -eq 1 ] && tools_item_preview "${OPTIONAL_ITEMS[i]}"
done
if [ "$SELECT_ZSH" -eq 1 ]; then zsh_preview; fi

if ! confirm 'Apply this plan? [y/N]'; then
  printf 'Cancelled. No changes were made.\n'
  exit 0
fi

printf '\nChecking Homebrew...\n'
if ! tools_install_brew; then
  printf 'Homebrew is unavailable. Remaining items were not installed.\n' >&2
  exit 1
fi
printf '\nChecking Git...\n'
if ! tools_install_git; then
  printf 'Git is unavailable. Remaining items were not installed.\n' >&2
  exit 1
fi

failed=0
for ((i=0; i<${#OPTIONAL_ITEMS[@]}; i++)); do
  [ "${ITEM_SELECTED[i]}" -eq 1 ] || continue
  if ! tools_install_item "${OPTIONAL_ITEMS[i]}"; then
    printf '%s installation failed.\n' "${OPTIONAL_ITEMS[i]}" >&2
    failed=1
  fi
done

if [ "$SELECT_ZSH" -eq 1 ]; then
  printf '\nApplying zsh settings...\n'
  if ! zsh_install_dependencies || ! zsh_apply; then
    printf 'zsh settings could not be applied.\n' >&2
    failed=1
  fi
fi

if [ "$failed" -ne 0 ]; then
  printf 'Setup finished with errors.\n' >&2
  exit 1
fi
printf '\nSelected items are ready. Open a new terminal to load zsh settings.\n'
