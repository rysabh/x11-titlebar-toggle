# x11-titlebar-toggle

This tool is an X11-only window chrome controller. It removes the title bar and frame from a chosen window, resizes that window to the current monitor with optional margins, and can later restore the previous state.

The code is split into small modules so each concern stays readable:

- `x11-titlebar-toggle`: entry point and command dispatch.
- `lib/cli.sh`: argument parsing and validation.
- `lib/profiles.sh`: profile loading and defaults.
- `lib/windows.sh`: window discovery and selector matching.
- `lib/state.sh`: saved geometry and window state.
- `lib/layout.sh`: borderless layout and restoration logic.
- `profiles/*.conf`: human-readable matching rules and default margins.

## Why the name starts with X11

The key trick is `_MOTIF_WM_HINTS`, which is an X11 window decoration hint. Wayland does not expose this same level of global window control to ordinary user processes, so this tool is intentionally named `x11-titlebar-toggle`.

## Common commands

Inspect the active window:

```bash
/home/cam/Applications/linux-tools/x11-titlebar-toggle/x11-titlebar-toggle inspect --active
```

Toggle the active window:

```bash
/home/cam/Applications/linux-tools/x11-titlebar-toggle/x11-titlebar-toggle toggle --active
```

Toggle VMware using the built-in profile:

```bash
/home/cam/Applications/linux-tools/x11-titlebar-toggle/x11-titlebar-toggle toggle --profile vmware
```

Toggle OmniAI using its executable path as the selector:

```bash
/home/cam/Applications/linux-tools/x11-titlebar-toggle/x11-titlebar-toggle toggle --exe '/home/cam/.webcatalog/OmniAI/OmniAI'
```

List available profiles:

```bash
/home/cam/Applications/linux-tools/x11-titlebar-toggle/x11-titlebar-toggle list-profiles
```

## Adding a new profile

Create a new file in `profiles/` with a `.conf` extension. These files are ordinary shell assignments, which keeps them compact and easy to edit.

Example:

```bash
PROFILE_DESCRIPTION='Firefox with room for the top panel.'
PROFILE_CLASS_REGEX='^firefox$'
PROFILE_WMCTRL_CLASS_REGEX='^Navigator\.firefox$'
DEFAULT_TOP=32
DEFAULT_BOTTOM=0
DEFAULT_LEFT=0
DEFAULT_RIGHT=0
```

Supported profile variables:

- `PROFILE_DESCRIPTION`
- `PROFILE_CLASS_REGEX`
- `PROFILE_INSTANCE_REGEX`
- `PROFILE_WMCTRL_CLASS_REGEX`
- `PROFILE_TITLE_REGEX`
- `PROFILE_EXE_REGEX`
- `PROFILE_PID_SELECTOR`
- `DEFAULT_TOP`
- `DEFAULT_BOTTOM`
- `DEFAULT_LEFT`
- `DEFAULT_RIGHT`

CLI arguments always win over profile defaults. For example, `--bottom 96` overrides a profile's `DEFAULT_BOTTOM`.
