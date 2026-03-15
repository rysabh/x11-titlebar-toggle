#!/usr/bin/env bash

reset_profile_settings() {
  PROFILE_DESCRIPTION=""
  PROFILE_CLASS_REGEX=""
  PROFILE_INSTANCE_REGEX=""
  PROFILE_WMCTRL_CLASS_REGEX=""
  PROFILE_TITLE_REGEX=""
  PROFILE_EXE_REGEX=""
  PROFILE_PID_SELECTOR=""
  DEFAULT_TOP=0
  DEFAULT_BOTTOM=0
  DEFAULT_LEFT=0
  DEFAULT_RIGHT=0
}

profile_file_for() {
  local profile_name="$1"
  printf '%s/profiles/%s.conf\n' "$TOOL_ROOT" "$profile_name"
}

load_profile() {
  local profile_name="$1"
  local profile_file

  profile_file="$(profile_file_for "$profile_name")"
  [[ -f "$profile_file" ]] || die "Profile not found: $profile_name"

  reset_profile_settings
  # shellcheck source=/dev/null
  source "$profile_file"
}

list_profiles() {
  local profile_file

  shopt -s nullglob
  for profile_file in "$TOOL_ROOT"/profiles/*.conf; do
    local profile_name description
    profile_name="$(basename "$profile_file" .conf)"
    description="$(sed -n 's/^PROFILE_DESCRIPTION=//p' "$profile_file" | head -n 1 | sed "s/^'//; s/'$//")"
    if [[ -n "$description" ]]; then
      printf '%s\t%s\n' "$profile_name" "$description"
    else
      printf '%s\n' "$profile_name"
    fi
  done
}
