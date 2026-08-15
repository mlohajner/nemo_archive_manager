#!/usr/bin/env bash
set -euo pipefail

mount_root="/run/user/$UID/archivemount"
bookmarks_dir="$HOME/.config/gtk-3.0"
bookmarks_file="$bookmarks_dir/bookmarks"

usage() {
	printf 'Usage: %s <archive>       # mount archive read-write\n' "$(basename "$0")" >&2
	printf '       %s -u <mountpoint> # unmount\n' "$(basename "$0")" >&2
	exit 1
}

add_bookmark() {
	local path="$1"
	local label="$2"
	local uri
 
	# Safe without percent-encoding: $path is always built from $mount_root
	# ("/run/user/$UID/archivemount") plus a name already sanitized to
	# [[:alnum:]_.-], so it never contains spaces or other special chars.
	uri="file://$path"
 
	touch "$bookmarks_file"
 
	if ! grep -Fq "$uri " "$bookmarks_file" 2>/dev/null; then
		printf '%s %s\n' "$uri" "📦 $label" >> "$bookmarks_file"
	fi
}
 
remove_bookmark() {
	local path="$1"
	local uri tmp
 
	[[ -f "$bookmarks_file" ]] || return 0
 
	uri="file://$path"
 
	tmp="$(mktemp)"
	grep -Fv "$uri " "$bookmarks_file" > "$tmp" || true
	mv "$tmp" "$bookmarks_file"
}

do_mount() {
	local archive="${1:-}"

	if [[ -z "$archive" || ! -f "$archive" ]]; then
		usage
	fi

	archive="$(realpath "$archive")"

	local base name mountpoint
	base="$(basename "$archive")"
	name="${base%.*}"

	# Sanitize mount-point name.
	name="$(printf '%s' "$name" | sed 's/[^[:alnum:]_.-]/_/g')"

	mountpoint="$mount_root/$name"

	mkdir -p "$mount_root"
	mkdir -p "$bookmarks_dir"

	# Already mounted: add bookmark and open it.
	if mountpoint -q "$mountpoint" 2>/dev/null; then
		add_bookmark "$mountpoint" "$name"
		nemo --self "$mountpoint"
		exit 0
	fi

	# Existing non-mount directory.
	if [[ -e "$mountpoint" ]]; then
		mountpoint="${mountpoint}-$$"
	fi

	mkdir -p "$mountpoint"

	# Mount read-write.
	if ! archivemount -o rw "$archive" "$mountpoint"; then
		rmdir "$mountpoint" 2>/dev/null || true
		exit 1
	fi

	# Add bookmark after successful mount.
	add_bookmark "$mountpoint" "$name"

	# Open mounted archive in Nemo.
	nemo --self "$mountpoint"
}

do_unmount() {
	local mountpoint_path="${1:-}"

	if [[ -z "$mountpoint_path" || ! -d "$mountpoint_path" ]]; then
		usage
	fi

	# Only allow unmounting our own archivemount mount points.
	case "$mountpoint_path" in
		"$mount_root"/*)
			;;
		*)
			exit 1
			;;
	esac

	# Must actually be a mount point.
	if ! mountpoint -q "$mountpoint_path" 2>/dev/null; then
		exit 1
	fi

	remove_bookmark "$mountpoint_path"

	# Unmount using FUSE 2.
	fusermount -u "$mountpoint_path"

	# Remove the mount point if it is empty.
	rmdir "$mountpoint_path" 2>/dev/null || true
}

case "${1:-}" in
	-u|--unmount)
		shift
		do_unmount "${1:-}"
		;;
	-h|--help)
		usage
		;;
	*)
		do_mount "${1:-}"
		;;
esac
