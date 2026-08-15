#!/usr/bin/env bash
#
# install.sh -- installs the "Mount archive RW+" / "Unmount archive RW+"
# Nemo actions together with the mount-archive.sh helper script.
#
# What it does:
#   1. installs dependencies (archivemount, fuse, nemo)
#   2. copies mount-archive.sh to ~/.local/bin and makes it executable
#   3. renders the .nemo_action templates (placeholder __MOUNT_ARCHIVE_BIN__)
#      into ~/.local/share/nemo/actions (per-user, no root required, and no
#      hardcoded username anywhere)
#   4. disables the built-in system "Mount Archive" action
#      (/usr/share/nemo/actions/mount-archive.nemo_action -> .off)
#   5. restarts nemo so it picks up the changes immediately
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="$HOME/.local/bin"
ACTIONS_DIR="$HOME/.local/share/nemo/actions"
SYSTEM_ACTIONS_DIR="/usr/share/nemo/actions"

SRC_SCRIPT="$SCRIPT_DIR/mount-archive.sh"
SRC_MOUNT_ACTION="$SCRIPT_DIR/mount-archive.nemo_action"
SRC_UNMOUNT_ACTION="$SCRIPT_DIR/unmount-archive.nemo_action"

TARGET_SCRIPT="$BIN_DIR/mount-archive.sh"
PLACEHOLDER="__MOUNT_ARCHIVE_BIN__"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Verify input files
# ---------------------------------------------------------------------------
for f in "$SRC_SCRIPT" "$SRC_MOUNT_ACTION" "$SRC_UNMOUNT_ACTION"; do
	if [[ ! -f "$f" ]]; then
		err "Missing file: $f (run install.sh from the directory containing all the files)."
		exit 1
	fi
done

# ---------------------------------------------------------------------------
# 2. Install dependencies
# ---------------------------------------------------------------------------
log "Installing dependencies (archivemount, fuse, nemo)..."

if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get install -y archivemount fuse3 nemo
elif command -v dnf >/dev/null 2>&1; then
	sudo dnf install -y archivemount fuse nemo
elif command -v pacman >/dev/null 2>&1; then
	sudo pacman -S --needed --noconfirm archivemount fuse2 nemo
elif command -v zypper >/dev/null 2>&1; then
	sudo zypper install -y archivemount fuse nemo
else
	warn "Unknown package manager. Install manually: archivemount, fuse, nemo."
fi

for cmd in archivemount nemo fusermount; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		warn "'$cmd' was not found in PATH after installation -- check manually."
	fi
done

# ---------------------------------------------------------------------------
# 3. Install mount-archive.sh
# ---------------------------------------------------------------------------
log "Installing mount-archive.sh to $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 755 "$SRC_SCRIPT" "$TARGET_SCRIPT"

# ---------------------------------------------------------------------------
# 4. Render and install the .nemo_action files
# ---------------------------------------------------------------------------
log "Installing Nemo actions to $ACTIONS_DIR"
mkdir -p "$ACTIONS_DIR"

# Replace the placeholder with the current user's real script path. No
# username is ever hardcoded into the shipped files or the installed
# actions -- everything is derived from $HOME at install time.
sed "s#$PLACEHOLDER#$TARGET_SCRIPT#g" \
	"$SRC_MOUNT_ACTION" > "$ACTIONS_DIR/mount-archive.nemo_action"

sed "s#$PLACEHOLDER#$TARGET_SCRIPT#g" \
	"$SRC_UNMOUNT_ACTION" > "$ACTIONS_DIR/unmount-archive.nemo_action"

chmod 644 "$ACTIONS_DIR/mount-archive.nemo_action" "$ACTIONS_DIR/unmount-archive.nemo_action"

# ---------------------------------------------------------------------------
# 5. Disable the built-in system "Mount Archive" action
# ---------------------------------------------------------------------------
SYSTEM_ACTION="$SYSTEM_ACTIONS_DIR/mount-archive.nemo_action"
if [[ -f "$SYSTEM_ACTION" ]]; then
	log "Disabling built-in system action ($SYSTEM_ACTION -> .off)"
	sudo mv "$SYSTEM_ACTION" "$SYSTEM_ACTION.off"
elif [[ -f "$SYSTEM_ACTION.off" ]]; then
	log "System action is already disabled ($SYSTEM_ACTION.off exists)."
else
	warn "System action $SYSTEM_ACTION was not found -- it may already be named differently or not exist on this installation."
fi

# ---------------------------------------------------------------------------
# 6. Restart Nemo so it picks up the changes immediately
# ---------------------------------------------------------------------------
if command -v nemo >/dev/null 2>&1; then
	log "Restarting Nemo..."
	nemo -q >/dev/null 2>&1 || true
fi

log "Done."
echo
echo "  Script:                $TARGET_SCRIPT"
echo "  Actions:                $ACTIONS_DIR/{mount,unmount}-archive.nemo_action"
echo "  System action disabled: $SYSTEM_ACTION.off (if it existed)"
echo
echo "Open Nemo, right-click an archive -> 'Mount archive RW+'."
