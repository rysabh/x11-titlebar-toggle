#!/usr/bin/env bash

window_state_has() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]]
}

set_window_borderless() {
  local target_id="$1"
  xprop -id "$target_id" -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS '2, 0, 0, 0, 0' >/dev/null
}

restore_window_decorations() {
  local target_id="$1"
  local motif_value="$2"

  if [[ "$motif_value" == "__NONE__" ]]; then
    xprop -id "$target_id" -remove _MOTIF_WM_HINTS >/dev/null 2>&1 || true
  else
    xprop -id "$target_id" -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "$motif_value" >/dev/null
  fi

  # Mutter applies the decoration change reliably after the window is remapped.
  xdotool windowunmap "$target_id"
  sleep 0.1
  xdotool windowmap "$target_id"
  sleep 0.2
}

pick_monitor_for_point() {
  local center_x="$1"
  local center_y="$2"
  local best=""
  local fallback=""
  local line output width height x y primary

  while IFS= read -r line; do
    if [[ "$line" =~ ^([A-Za-z0-9-]+)[[:space:]]connected([[:space:]]primary)?[[:space:]]([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) ]]; then
      output="${BASH_REMATCH[1]}"
      primary="${BASH_REMATCH[2]}"
      width="${BASH_REMATCH[3]}"
      height="${BASH_REMATCH[4]}"
      x="${BASH_REMATCH[5]}"
      y="${BASH_REMATCH[6]}"

      if [[ -z "$fallback" || -n "$primary" ]]; then
        fallback="$output:$x:$y:$width:$height"
      fi

      if (( center_x >= x && center_x < x + width && center_y >= y && center_y < y + height )); then
        best="$output:$x:$y:$width:$height"
        break
      fi
    fi
  done < <(xrandr --current)

  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
    return 0
  fi

  [[ -n "$fallback" ]] || die "Could not determine monitor geometry."
  printf '%s\n' "$fallback"
}

apply_borderless_layout() {
  local target_id="$1"
  local top_margin="$2"
  local bottom_margin="$3"
  local left_margin="$4"
  local right_margin="$5"
  local center_x center_y x y width height

  eval "$(xdotool getwindowgeometry --shell "$target_id")"
  center_x=$((X + WIDTH / 2))
  center_y=$((Y + HEIGHT / 2))

  IFS=':' read -r _ monitor_x monitor_y monitor_width monitor_height < <(pick_monitor_for_point "$center_x" "$center_y")

  x=$((monitor_x + left_margin))
  y=$((monitor_y + top_margin))
  width=$((monitor_width - left_margin - right_margin))
  height=$((monitor_height - top_margin - bottom_margin))

  if (( width < 200 || height < 200 )); then
    die "Requested margins leave too little usable space."
  fi

  wmctrl -i -r "$(window_hex_id "$target_id")" -b remove,fullscreen,maximized_horz,maximized_vert >/dev/null 2>&1 || true
  sleep 0.1

  set_window_borderless "$target_id"
  sleep 0.1

  xdotool windowmove "$target_id" "$x" "$y"
  xdotool windowsize "$target_id" "$width" "$height"
  xdotool windowactivate "$target_id"
}

restore_window_layout() {
  local target_id="$1"
  local state_file
  local window_hex

  state_file="$(state_file_for_window "$target_id")"
  [[ -f "$state_file" ]] || die "No saved state was found for window $target_id."

  # shellcheck disable=SC1090
  source "$state_file"

  window_hex="$(window_hex_id "$target_id")"

  wmctrl -i -r "$window_hex" -b remove,fullscreen,maximized_horz,maximized_vert >/dev/null 2>&1 || true
  sleep 0.1

  restore_window_decorations "$target_id" "${MOTIF:-__NONE__}"
  wmctrl -i -r "$window_hex" -e "0,$X,$Y,$WIDTH,$HEIGHT" >/dev/null 2>&1 || true

  if window_state_has "${WM_STATE:-}" "_NET_WM_STATE_MAXIMIZED_HORZ"; then
    wmctrl -i -r "$window_hex" -b add,maximized_horz >/dev/null 2>&1 || true
  fi
  if window_state_has "${WM_STATE:-}" "_NET_WM_STATE_MAXIMIZED_VERT"; then
    wmctrl -i -r "$window_hex" -b add,maximized_vert >/dev/null 2>&1 || true
  fi
  if window_state_has "${WM_STATE:-}" "_NET_WM_STATE_FULLSCREEN"; then
    wmctrl -i -r "$window_hex" -b add,fullscreen >/dev/null 2>&1 || true
  fi

  rm -f "$state_file"
  xdotool windowactivate "$target_id"
}
