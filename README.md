# Omarchy Overview

A live workspace overview for Omarchy's Quickshell shell, inspired by end-4's workspace overview. Open a grid of ten workspaces, drag windows between them, or select a window to focus it.

Plugin ID: `alertxsto.overview` · Version: `1.1.0` · License: MIT

This is a third-party plugin, not an official Omarchy component. It provides the workspace grid; it does **not** include end-4's application search bar or bind the Super key by itself.

## Compatibility

Requires Omarchy's Quickshell plugin system and a Lua-configured Hyprland supporting `hl.dsp` dispatchers. It imports the shell's `qs.Commons` and `qs.Ui` modules, so it is not a standalone Quickshell configuration.

The current implementation was exercised on:

| Component | Tested version |
| --- | --- |
| Omarchy | `4.0.5-1` |
| Hyprland | `0.56.2` |
| Quickshell | `0.3.2.r7.g2b4501a-1` |
| Qt Declarative | `6.12.0-1` |

These are tested versions, not a claim that every newer or older release is compatible. Older Waybar-based Omarchy installations and Hyprland configurations without Lua dispatch support are not supported. Multi-monitor offsets, scaling, and rotation have geometry regression coverage; the live desktop checks used one display.

## Install

Review the source before enabling it: Omarchy shell plugins run as unsandboxed code in your desktop shell process.

```sh
omarchy plugin add https://github.com/alertxsto/omarchy-overview.git --enable
```

For a non-interactive install, append `--yes` to accept Omarchy's trust confirmation. No separate install script, compilation, or Node.js runtime is needed to use the plugin.

If `alertxsto.overview` already exists as a hand-copied local plugin, Omarchy will refuse the duplicate ID. **Move the original directory** `~/.config/omarchy/plugins/alertxsto.overview` to a backup location **outside** `~/.config/omarchy/plugins/`, preserving its contents, before installing the repository version. Copying a backup while leaving the original in place does not resolve the conflict. Do not overwrite local edits. Git-installed copies use the update command below instead.

## Open the overview

```sh
omarchy-shell shell toggle alertxsto.overview
```

To use **Super+D**, add this line to your existing `~/.config/hypr/bindings.lua`, where Omarchy's `o` binding helper is available:

```lua
o.bind("SUPER + D", "Workspace overview", "omarchy-shell shell toggle alertxsto.overview")
```

Check for an existing Super+D binding first; use a different shortcut if needed. The plugin does not modify keybindings automatically. After editing Hyprland configuration, validate it with:

```sh
hyprctl reload
hyprctl configerrors
```

## Controls

| Input | Action |
| --- | --- |
| Click a window preview | Focus that window and close the overview |
| Click an empty part of a workspace cell | Switch to that workspace and close the overview |
| Drag a window to another cell and release | Move the window without following it |
| Middle-click a preview | Close that window |
| Arrow keys, then Enter | Select and switch workspace |
| `1`–`9`, `0` | Select the corresponding cell; `0` is the tenth cell |
| Escape | Dismiss the overview, including during a drag |

The grid shows the group containing the active workspace: 1–10, 11–20, and so on. Number keys select positions within that group. Drops into a gap, outside the grid, or back into the same workspace do not move the window. Floating windows retain compositor-managed placement; dropping within the same cell does not reposition them.

## Resource behavior and limitations

- Previews update live while the overview is open.
- Native Hyprland window objects keep preview delegates stable across workspace moves. Layout events trigger a coalesced IPC refresh rather than a recurring snapshot-rebuild loop.
- Closing the overview unloads its window and preview subtree. The small controller stays loaded for shell IPC.
- Tiled previews covered by a true-fullscreen window are not captured. Floating windows allowed above fullscreen remain available.
- Capture uses the source window's native resolution. Rendering a small thumbnail does **not** shrink its capture buffers; this Quickshell API does not expose capture-resolution downscaling. More windows and larger sources can increase graphics/shared-memory use while open.
- GPU/driver resources may return asynchronously after close. Process RSS includes the entire Omarchy shell, not just this plugin; graphics-memory counters can overlap system-memory accounting.

If plugin edits are not reflected after a rescan, run `omarchy restart shell` to load the changed QML. This restarts the desktop shell, not your applications.

## Update, disable, or remove

```sh
omarchy plugin update alertxsto.overview
omarchy plugin disable alertxsto.overview
omarchy plugin remove alertxsto.overview
```

Remove the shortcut from your own Hyprland configuration if you uninstall the plugin.

## Development

The repository is directly installable: `manifest.json` and the QML entry point are at its root. Runtime code is in `Overview.qml`; deterministic geometry and ordering functions are in `OverviewLogic.js`.

Run the dependency-free regression suite with Node.js 18 or later:

```sh
node --test tests/logic.test.cjs
```

On a compatible Omarchy installation, validate the manifest with:

```sh
omarchy plugin validate .
```

The tests cover number-key selection, drop boundaries, monitor-relative geometry, rotation, proportional clipping, and floating-over-fullscreen ordering. They do not replace live layer-shell interaction checks.

## Credits

Interaction concept inspired by [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland). This repository packages the Omarchy-specific implementation; it does not bundle or install end-4's shell.
