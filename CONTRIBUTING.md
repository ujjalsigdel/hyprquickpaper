# Contributing

Thank you for considering contributing to this project! Since the project is still small and evolving, contributions are very welcome.

## Pull Requests

When submitting a pull request, please include the following:

1. **Screenshots or a screen recording** demonstrating the change or feature.
2. A **clear description of what was changed**.
3. A **short explanation of how the change was implemented**, especially if the logic is not obvious.

This helps reviewers (basically just me haha) quickly understand the purpose and impact of your contribution.

## Configuration Changes

This project is intended to be **customizable**.

If your change introduces new configurable behavior:

- Add the option to `config.json`.
- Document the option clearly in the **README**.

Please avoid hard-coding user-configurable values directly in the code.

## Project Structure

The UI is split into `shell.qml` (the entry point, which loads exactly one layout via `activeLayout`) and a set of standalone `shell-*.qml` layout files (`shell-bottom-dock.qml`, `shell-coverflow.qml`, `shell-coverflow-widgets.qml`, `shell-classic.qml`, `shell-widgets-noblur.qml`).

This is deliberate: each layout is a **self-contained file** with its own `PanelWindow`, config `FileView`, and wallpaper-tracking logic, rather than one file with a mode switch. That makes it straightforward to add a new layout without touching or risking breakage in the existing ones — copy an existing `shell-*.qml`, rework its visual layer, and register the filename as a new `activeLayout` option in `shell.qml`. Expect more layouts to be added over time; new ones are welcome as long as they follow this same self-contained pattern.

Since the project is still small, there is **no separate documentation folder** beyond the README.

You are welcome to experiment with **refactoring**, but please note:

- The one-layout-per-file structure is intentional — don't merge layouts back into a single shared file or introduce a shared base class/component without discussing it first.
- Large structural changes may be rejected if they conflict with the project's design goals.

## Things You Can Contribute To

- [ ] **New layouts** — following the self-contained `shell-*.qml` pattern above.
- [ ] **New wallpaper backends** — add a `case` branch to `commands.sh`.
- [ ] **Customizable image transform** — the bottom-dock layout currently uses a hardcoded shear transform. Making this configurable would improve customization.
- [ ] **Distro packaging** — AUR, Nix, COPR, etc.

You can work on other issues that are open.

## General Guidelines

- Keep changes **focused and minimal**.
- If you're unsure about a change, feel free to open an **issue first** to discuss it.
