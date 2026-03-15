#!/usr/bin/env bash

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/x11-titlebar-toggle"
mkdir -p "$STATE_DIR"

state_file_for_window() {
  local target_id="$1"
  printf '%s/%s.state\n' "$STATE_DIR" "$target_id"
}

window_state_exists() {
  local target_id="$1"
  [[ -f "$(state_file_for_window "$target_id")" ]]
}

save_window_state() {
  local target_id="$1"
  local state_file="$2"
  local motif wm_state saved_x saved_y saved_width saved_height

  motif="$(xprop -id "$target_id" _MOTIF_WM_HINTS 2>/dev/null | sed -n 's/^.*= //p')"
  wm_state="$(xprop -id "$target_id" _NET_WM_STATE 2>/dev/null | sed -n 's/^.*= //p')"
  read -r saved_x saved_y saved_width saved_height < <(
    xwininfo -id "$target_id" | awk '
      /Absolute upper-left X:/ { x = $4 }
      /Absolute upper-left Y:/ { y = $4 }
      /^  Width:/ { w = $2 }
      /^  Height:/ { h = $2 }
      END { print x, y, w, h }
    '
  )

  {
    printf 'X=%q\n' "$saved_x"
    printf 'Y=%q\n' "$saved_y"
    printf 'WIDTH=%q\n' "$saved_width"
    printf 'HEIGHT=%q\n' "$saved_height"
    printf 'WM_STATE=%q\n' "$wm_state"
    printf 'MOTIF=%q\n' "${motif:-__NONE__}"
  } >"$state_file"
}

ensure_window_state_saved() {
  local target_id="$1"
  local state_file

  state_file="$(state_file_for_window "$target_id")"
  if [[ ! -f "$state_file" ]]; then
    save_window_state "$target_id" "$state_file"
  fi
}
