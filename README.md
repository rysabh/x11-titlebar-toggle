# x11-titlebar-toggle

## Install on another similar PC

This tool is not a single standalone script. The main launcher loads files from `lib/` and `profiles/`, so on another machine you must clone or copy the entire `x11-titlebar-toggle/` folder, not just the `x11-titlebar-toggle` file.

If the other machine is a similar Ubuntu system and you want the shortest working install path, do this:

```bash
mkdir -p ~/Applications/linux-tools
git clone <your-repo-url> ~/Applications/linux-tools/x11-titlebar-toggle
cd ~/Applications/linux-tools/x11-titlebar-toggle
sudo apt update
sudo apt install wmctrl xdotool x11-utils x11-xserver-utils
chmod +x ./x11-titlebar-toggle
./x11-titlebar-toggle list-profiles
```

What each step does:

- `mkdir -p ~/Applications/linux-tools` creates the parent directory structure expected by the examples in this README.
- `git clone ... ~/Applications/linux-tools/x11-titlebar-toggle` copies the whole tool, including its modules and profile files.
- `sudo apt install ...` installs the runtime dependencies that the scripts call directly: `wmctrl`, `xdotool`, `xprop`, `xrandr`, and `xwininfo`.
- `chmod +x ./x11-titlebar-toggle` makes the entry script executable after cloning.
- `./x11-titlebar-toggle list-profiles` is the quickest smoke test. If it prints the bundled profiles, the install is basically correct.

Before you use it, confirm that the desktop session is X11:

```bash
echo "$XDG_SESSION_TYPE"
```

This should print `x11`. If it prints `wayland`, this tool is the wrong fit because it depends on X11 window decoration hints and X11 window management tools.

Optional convenience step:

```bash
ln -s ~/Applications/linux-tools/x11-titlebar-toggle/x11-titlebar-toggle ~/.local/bin/x11-titlebar-toggle
```

That symlink lets you run `x11-titlebar-toggle` from anywhere without typing the full path.

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
