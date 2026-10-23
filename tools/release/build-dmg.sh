#!/bin/bash
# Wraps a built LingvoBuddy.app into a disk image with an Applications alias, so the user
# drags the app into /Applications. The script mounts the result and checks it before it exits.
# Usage: build-dmg.sh <path/to/LingvoBuddy.app> <version> <out.dmg>
set -euo pipefail

if [ $# -ne 3 ]; then
	echo "usage: $0 <app> <version> <out.dmg>" >&2
	exit 2
fi
app=$1
version=$2
out=$3
app_name=$(basename "$app")

if [ ! -d "$app" ]; then
	echo "build-dmg: no app at $app" >&2
	exit 1
fi
# An app that fails this check copies fine, but macOS refuses to launch it.
codesign --verify --deep --strict "$app"

work=$(mktemp -d)
mount_point="$work/mount"
mounted=false
cleanup() {
	if $mounted; then
		hdiutil detach -quiet "$mount_point" || hdiutil detach -quiet -force "$mount_point"
	fi
	rm -rf "$work"
}
trap cleanup EXIT

mkdir "$work/stage"
ditto "$app" "$work/stage/$app_name"
ln -s /Applications "$work/stage/Applications"

mkdir -p "$(dirname "$out")"
hdiutil create -quiet -ov -format UDZO -fs HFS+ \
	-volname "LingvoBuddy $version" -srcfolder "$work/stage" "$out"

# Check the image as the user gets it: a broken signature or a missing alias must stop the release.
mkdir "$mount_point"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mount_point" "$out"
mounted=true
codesign --verify --deep --strict "$mount_point/$app_name"
if [ "$(readlink "$mount_point/Applications")" != /Applications ]; then
	echo "build-dmg: the image has no Applications alias" >&2
	exit 1
fi
echo "build-dmg: $out"
