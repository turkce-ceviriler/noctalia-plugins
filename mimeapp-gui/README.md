# MimeApp GUI

A Noctalia plugin to manage MIME default applications from a panel UI.

## Requirements

- `python3` must be installed and available in `PATH`.

## What it does

- Scans installed `.desktop` files for their `MimeType=` entries.
- Lists MIME types and candidate handlers.
- Prioritizes MIME types that have multiple handlers (configurable in settings).
- Updates `~/.config/mimeapps.list` in the `[Default Applications]` section.

## Notes

- This plugin writes user overrides to `~/.config/mimeapps.list`.
- Effective defaults may still be influenced by desktop-specific `*-mimeapps.list` files and system-level files.
- For troubleshooting, run: `XDG_UTILS_DEBUG_LEVEL=2 xdg-mime query default <mime-type>`
