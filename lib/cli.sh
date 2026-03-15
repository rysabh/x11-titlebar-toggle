#!/usr/bin/env bash

COMMAND="toggle"
PROFILE_NAME=""
WINDOW_ID_SELECTOR=""
ACTIVE_ONLY=0
CLASS_REGEX=""
INSTANCE_REGEX=""
WMCTRL_CLASS_REGEX=""
TITLE_REGEX=""
EXE_REGEX=""
PID_SELECTOR=""
TOP_MARGIN=""
BOTTOM_MARGIN=""
LEFT_MARGIN=""
RIGHT_MARGIN=""

EFFECTIVE_TOP=0
EFFECTIVE_BOTTOM=0
EFFECTIVE_LEFT=0
EFFECTIVE_RIGHT=0

usage() {
  cat <<'EOF'
Usage:
  x11-titlebar-toggle [toggle|enter|exit|inspect|list-profiles|list-windows] [options]

Core idea:
  Replace a true fullscreen window with a borderless X11 window whose size you control.
  The same engine can target different applications through selectors or profiles.

Selection options:
  --active               Target the currently focused window
  --window ID            Target a specific window id, decimal or hexadecimal
  --profile NAME         Load a named profile from profiles/NAME.conf
  --class REGEX          Match the second WM_CLASS string, such as Vmware or OmniAI
  --instance REGEX       Match the first WM_CLASS string, such as vmware or omniai
  --wmctrl-class REGEX   Match the combined wmctrl class, such as vmware.Vmware
  --title REGEX          Match the window title
  --exe REGEX            Match the executable path resolved from /proc/<pid>/exe
  --pid PID              Match a specific process id

Layout options:
  --top PIXELS           Leave this many pixels free at the top
  --bottom PIXELS        Leave this many pixels free at the bottom
  --left PIXELS          Leave this many pixels free at the left
  --right PIXELS         Leave this many pixels free at the right

Examples:
  x11-titlebar-toggle toggle --active
  x11-titlebar-toggle toggle --class '^Vmware$' --bottom 72
  x11-titlebar-toggle toggle --exe '/home/cam/.webcatalog/OmniAI/OmniAI'
  x11-titlebar-toggle inspect --profile vmware
  x11-titlebar-toggle list-profiles

Notes:
  This tool is X11-only. It uses standard X11 window hints and window manager actions.
  CLI selection flags override the matching rules loaded from a profile.
EOF
}

parse_cli() {
  local maybe_command_seen=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      toggle|enter|exit|inspect|list-profiles|list-windows)
        if (( maybe_command_seen == 1 )); then
          die "Only one command may be provided."
        fi
        COMMAND="$1"
        maybe_command_seen=1
        shift
        ;;
      --profile)
        PROFILE_NAME="$2"
        shift 2
        ;;
      --window)
        WINDOW_ID_SELECTOR="$(canonical_window_id "$2")"
        shift 2
        ;;
      --active)
        ACTIVE_ONLY=1
        shift
        ;;
      --class)
        CLASS_REGEX="$2"
        shift 2
        ;;
      --instance)
        INSTANCE_REGEX="$2"
        shift 2
        ;;
      --wmctrl-class)
        WMCTRL_CLASS_REGEX="$2"
        shift 2
        ;;
      --title)
        TITLE_REGEX="$2"
        shift 2
        ;;
      --exe)
        EXE_REGEX="$2"
        shift 2
        ;;
      --pid)
        PID_SELECTOR="$2"
        shift 2
        ;;
      --top)
        TOP_MARGIN="$2"
        shift 2
        ;;
      --bottom)
        BOTTOM_MARGIN="$2"
        shift 2
        ;;
      --left)
        LEFT_MARGIN="$2"
        shift 2
        ;;
      --right)
        RIGHT_MARGIN="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

apply_profile_defaults() {
  EFFECTIVE_TOP="${TOP_MARGIN:-${DEFAULT_TOP:-0}}"
  EFFECTIVE_BOTTOM="${BOTTOM_MARGIN:-${DEFAULT_BOTTOM:-0}}"
  EFFECTIVE_LEFT="${LEFT_MARGIN:-${DEFAULT_LEFT:-0}}"
  EFFECTIVE_RIGHT="${RIGHT_MARGIN:-${DEFAULT_RIGHT:-0}}"

  if [[ -z "$CLASS_REGEX" ]]; then
    CLASS_REGEX="${PROFILE_CLASS_REGEX:-}"
  fi
  if [[ -z "$INSTANCE_REGEX" ]]; then
    INSTANCE_REGEX="${PROFILE_INSTANCE_REGEX:-}"
  fi
  if [[ -z "$WMCTRL_CLASS_REGEX" ]]; then
    WMCTRL_CLASS_REGEX="${PROFILE_WMCTRL_CLASS_REGEX:-}"
  fi
  if [[ -z "$TITLE_REGEX" ]]; then
    TITLE_REGEX="${PROFILE_TITLE_REGEX:-}"
  fi
  if [[ -z "$EXE_REGEX" ]]; then
    EXE_REGEX="${PROFILE_EXE_REGEX:-}"
  fi
  if [[ -z "$PID_SELECTOR" ]]; then
    PID_SELECTOR="${PROFILE_PID_SELECTOR:-}"
  fi
}

validate_non_negative_integer() {
  local value="$1"
  local label="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$label must be a non-negative integer."
}

validate_cli_selection() {
  validate_non_negative_integer "$EFFECTIVE_TOP" "Top margin"
  validate_non_negative_integer "$EFFECTIVE_BOTTOM" "Bottom margin"
  validate_non_negative_integer "$EFFECTIVE_LEFT" "Left margin"
  validate_non_negative_integer "$EFFECTIVE_RIGHT" "Right margin"

  if [[ -n "$PID_SELECTOR" && ! "$PID_SELECTOR" =~ ^[0-9]+$ ]]; then
    die "--pid must be a decimal process id."
  fi

  if [[ "$COMMAND" == "list-profiles" ]]; then
    return 0
  fi

  if [[ -n "$WINDOW_ID_SELECTOR" && $ACTIVE_ONLY -eq 1 ]]; then
    die "Use either --window or --active, not both."
  fi
}
