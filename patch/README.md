# Nemo `--self` patch

This patch adds a new CLI option to the Nemo file manager:

```
nemo --self <path>
```

`--self` navigates an **existing, already-open** Nemo window directly to `<path>`  
Without opening a new window, without opening a new tab.

## Why this is needed

Nemo already has two options that sound similar, but don't actually do what we need:

| Option | What it actually does |
|---|---|
| `nemo <path>` | Opens a **brand new window** at `<path>`. |
| `nemo --tabs <path>` | Opens a **new window** with a tab at `<path>` (only useful if you pass multiple paths at once — each becomes its own tab in that new window). |
| `nemo --existing-window <path>` | If Nemo is already running, opens a **new tab** in that existing window. Key point: this **adds** a tab, it doesn't change the existing one. In practice it's almost the same as `--tabs`, just that the new tab gets inserted into the already-running instance instead of a new window. |
| **`nemo --self <path>`** (this patch) | Takes an existing window and **navigates its current tab** to `<path>`. Nothing new is opened — it just changes the location being displayed. |

None of the existing options do "in-place" navigation — they all either open a new window or pile up new tabs. For cases where you want a **single** Nemo window to simply "switch over" to a new location (without a stack of tabs accumulating from a script), a new option is needed.

## Concrete use case: integration with Mount Archive RW+

In the script that mounts an archive and opens it in the file manager, instead of:

```bash
nemo "$mountpoint" &
```

use:

```bash
nemo --self "$mountpoint" &
```

**Difference in behavior:**

- **Before the patch** (`nemo "$mountpoint" &`): every time the user mounts an archive, a **new Nemo window** opens. If the user mounts/opens several archives in a row (or remounts the same one), windows pile up in the taskbar.
- **After the patch** (`nemo --self "$mountpoint" &`): current Nemo window is simply navigated to the new `$mountpoint`. No windows or tabs pile up — the user stays in the same window, only the displayed path changes. If Nemo isn't running at all, it behaves like a normal launch (a single new window opens).

This gives a cleaner, "desktop-integrated" feel: the archive opens as if the folder simply changed in the file manager the user is already looking at, instead of a new window popping up.
`mount-archive.sh` included in this directory uses patched Nemo with --self option!

## How it works (technical, brief)

The patch is built against `linuxmint/nemo`, tag **6.4.5** (the version Fedora ships), file `src/nemo-main-application.c`.

- Adds `--self` to the existing `GOptionEntry` array of options (alongside `--tabs`, `--existing-window`, etc.).
- When the option is used, the local instance encodes it as the string `"SELF_WINDOW"` and sends it via `g_application_open()` to the primary (already running) Nemo instance, the same way `--existing-window` sends `"EXISTING_WINDOW"`.
- The primary instance, in `nemo_main_application_open()`, recognizes `"SELF_WINDOW"` and calls a new function, `navigate_existing_window()`.
- `navigate_existing_window()` finds the first existing `NemoWindow` and calls `nemo_window_go_to(window, location)` on it — the same call normally used for in-window navigation (rather than `nemo_window_go_to_tab()`, which would open a new tab). It then brings the window into focus (`gtk_window_present`).
- If Nemo isn't running at all, it falls back to opening a normal new window (`open_window()`), so `--self` is safe to use "cold", without assuming Nemo is already running.

Patch file: [`nemo-self-window.patch`](./nemo-self-window.patch)

## Applying the patch (Fedora, nemo 6.4.5)

```bash
sudo dnf install nemo rpm-build rpmdevtools gcc meson ninja-build \
    gtk3-devel gvfs-devel libnotify-devel cinnamon-desktop-devel \
    libexif-devel exempi-devel gobject-introspection-devel

dnf download --source nemo
rpmdev-setuptree
rpm -ivh nemo-6.4.5-*.src.rpm

cd ~/rpmbuild/SPECS
rpmbuild -bp nemo.spec
cd ~/rpmbuild/BUILD/nemo-6.4.5

patch -p1 < /path/to/nemo-self-window.patch

meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

Or add the patch directly to the `.spec` file (`Patch0: nemo-self-window.patch`, `%patch0 -p1` in `%prep`) and build a proper `.rpm` with `rpmbuild -ba nemo.spec`.

## Testing

```bash
nemo "$HOME" &          # open the first window
nemo --self /tmp        # the existing window navigates to /tmp
nemo --self /tmp2       # the same window navigates to /tmp2 — no new window/tab
```

## Notes / limitations

- If multiple Nemo windows are open, `--self` navigates the **first** one found in the internal window list (same approach as the existing `--existing-window`), not necessarily the currently focused one.
- If Nemo is using split-pane view, the active pane of the focused window is navigated.
- The patch has been tested (`patch -p1 --dry-run`) against the clean `linuxmint/nemo` tag `6.4.5` and `Fedora 43, Nemo 6.4.5` source and applies without conflicts.
