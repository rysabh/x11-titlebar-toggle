#!/usr/bin/env bash

die() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

ensure_x11_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "x11" ]] || die "This tool currently supports X11 sessions only."
}

canonical_window_id() {
  local raw_id="$1"

  if [[ "$raw_id" =~ ^0x[0-9a-fA-F]+$ ]]; then
    printf '%d\n' "$((raw_id))"
    return 0
  fi

  if [[ "$raw_id" =~ ^[0-9]+$ ]]; then
    printf '%d\n' "$raw_id"
    return 0
  fi

  die "Window id must be decimal or hexadecimal, got: $raw_id"
}

window_hex_id() {
  local decimal_id="$1"
  printf '0x%x\n' "$decimal_id"
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}
