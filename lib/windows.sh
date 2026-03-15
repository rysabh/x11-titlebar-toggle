#!/usr/bin/env bash

WINDOW_ID=""
WINDOW_HEX_ID=""
WINDOW_INSTANCE=""
WINDOW_CLASS=""
WINDOW_WMCTRL_CLASS=""
WINDOW_TITLE=""
WINDOW_PID=""
WINDOW_EXE=""

list_open_windows() {
  while read -r hex_id desktop wmctrl_class host title; do
    [[ -n "${hex_id:-}" ]] || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$((hex_id))" \
      "$hex_id" \
      "$desktop" \
      "$wmctrl_class" \
      "$host" \
      "${title:-}"
  done < <(wmctrl -lx)
}

populate_window_metadata() {
  local target_id="$1"
  local class_output pid_output

  WINDOW_ID="$target_id"
  WINDOW_HEX_ID="$(window_hex_id "$target_id")"
  WINDOW_INSTANCE=""
  WINDOW_CLASS=""
  WINDOW_WMCTRL_CLASS=""
  WINDOW_TITLE=""
  WINDOW_PID=""
  WINDOW_EXE=""

  while IFS=$'\t' read -r decimal_id hex_id desktop wmctrl_class host title; do
    if [[ "$decimal_id" == "$target_id" ]]; then
      WINDOW_WMCTRL_CLASS="$wmctrl_class"
      WINDOW_TITLE="$title"
      break
    fi
  done < <(list_open_windows)

  class_output="$(xprop -id "$target_id" WM_CLASS 2>/dev/null || true)"
  if [[ "$class_output" =~ \"([^\"]*)\",[[:space:]]\"([^\"]*)\" ]]; then
    WINDOW_INSTANCE="${BASH_REMATCH[1]}"
    WINDOW_CLASS="${BASH_REMATCH[2]}"
  fi

  if [[ -z "$WINDOW_TITLE" ]]; then
    WINDOW_TITLE="$(xdotool getwindowname "$target_id" 2>/dev/null || true)"
  fi

  pid_output="$(xprop -id "$target_id" _NET_WM_PID 2>/dev/null || true)"
  if [[ "$pid_output" =~ =\ ([0-9]+)$ ]]; then
    WINDOW_PID="${BASH_REMATCH[1]}"
    if [[ -e "/proc/$WINDOW_PID/exe" ]]; then
      WINDOW_EXE="$(readlink -f "/proc/$WINDOW_PID/exe" 2>/dev/null || true)"
    fi
  fi
}

window_matches_current_filters() {
  local target_id="$1"
  populate_window_metadata "$target_id"

  if [[ -n "$CLASS_REGEX" && ! "$WINDOW_CLASS" =~ $CLASS_REGEX ]]; then
    return 1
  fi
  if [[ -n "$INSTANCE_REGEX" && ! "$WINDOW_INSTANCE" =~ $INSTANCE_REGEX ]]; then
    return 1
  fi
  if [[ -n "$WMCTRL_CLASS_REGEX" && ! "$WINDOW_WMCTRL_CLASS" =~ $WMCTRL_CLASS_REGEX ]]; then
    return 1
  fi
  if [[ -n "$TITLE_REGEX" && ! "$WINDOW_TITLE" =~ $TITLE_REGEX ]]; then
    return 1
  fi
  if [[ -n "$EXE_REGEX" && ! "$WINDOW_EXE" =~ $EXE_REGEX ]]; then
    return 1
  fi
  if [[ -n "$PID_SELECTOR" && "$WINDOW_PID" != "$PID_SELECTOR" ]]; then
    return 1
  fi

  return 0
}

has_selector_filters() {
  [[ -n "$CLASS_REGEX" || -n "$INSTANCE_REGEX" || -n "$WMCTRL_CLASS_REGEX" || -n "$TITLE_REGEX" || -n "$EXE_REGEX" || -n "$PID_SELECTOR" ]]
}

get_active_window_id() {
  xdotool getactivewindow 2>/dev/null || true
}

describe_window() {
  local target_id="$1"
  populate_window_metadata "$target_id"
  printf '%s\t%s\t%s\t%s\n' \
    "$WINDOW_HEX_ID" \
    "${WINDOW_WMCTRL_CLASS:-unknown}" \
    "${WINDOW_EXE:-unknown-exe}" \
    "${WINDOW_TITLE:-untitled}"
}

print_window_list() {
  local active_id

  active_id="$(get_active_window_id)"
  while IFS=$'\t' read -r decimal_id hex_id desktop wmctrl_class host title; do
    local marker
    marker=" "
    if [[ "$decimal_id" == "$active_id" ]]; then
      marker="*"
    fi
    populate_window_metadata "$decimal_id"
    printf '%s %s\t%s\t%s\t%s\n' \
      "$marker" \
      "$hex_id" \
      "${WINDOW_WMCTRL_CLASS:-unknown}" \
      "${WINDOW_EXE:-unknown-exe}" \
      "${WINDOW_TITLE:-untitled}"
  done < <(list_open_windows)
}

print_window_metadata() {
  local target_id="$1"

  populate_window_metadata "$target_id"
  cat <<EOF
window_id=$WINDOW_ID
window_hex=$WINDOW_HEX_ID
wmctrl_class=$WINDOW_WMCTRL_CLASS
instance=$WINDOW_INSTANCE
class=$WINDOW_CLASS
title=$WINDOW_TITLE
pid=$WINDOW_PID
exe=$WINDOW_EXE
EOF
}

resolve_target_window() {
  local active_id
  local -a matches=()
  local target_id

  if [[ -n "$WINDOW_ID_SELECTOR" ]]; then
    xwininfo -id "$WINDOW_ID_SELECTOR" >/dev/null 2>&1 || die "Window id not found: $WINDOW_ID_SELECTOR"
    printf '%s\n' "$WINDOW_ID_SELECTOR"
    return 0
  fi

  active_id="$(get_active_window_id)"

  if (( ACTIVE_ONLY == 1 )); then
    [[ -n "$active_id" ]] || die "No active window was found."
    if has_selector_filters; then
      window_matches_current_filters "$active_id" || die "The active window does not match the requested selectors."
    fi
    printf '%s\n' "$active_id"
    return 0
  fi

  if ! has_selector_filters; then
    [[ -n "$active_id" ]] || die "No active window was found."
    printf '%s\n' "$active_id"
    return 0
  fi

  while IFS=$'\t' read -r decimal_id hex_id desktop wmctrl_class host title; do
    if window_matches_current_filters "$decimal_id"; then
      matches+=("$decimal_id")
    fi
  done < <(list_open_windows)

  if (( ${#matches[@]} == 0 )); then
    die "No window matched the requested selectors."
  fi

  if [[ -n "$active_id" ]]; then
    for target_id in "${matches[@]}"; do
      if [[ "$target_id" == "$active_id" ]]; then
        printf '%s\n' "$target_id"
        return 0
      fi
    done
  fi

  if (( ${#matches[@]} == 1 )); then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  {
    echo "Multiple windows matched. Refine the selectors or use --active / --window."
    for target_id in "${matches[@]}"; do
      printf '  %s\n' "$(describe_window "$target_id")"
    done
  } >&2
  exit 1
}
