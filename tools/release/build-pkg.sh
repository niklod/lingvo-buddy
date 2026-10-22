#!/bin/bash
# Wraps a built LingvoBuddy.app into an installer package for /Applications.
# Usage: build-pkg.sh <path/to/LingvoBuddy.app> <version> <out.pkg>
set -euo pipefail

if [ $# -ne 3 ]; then
	echo "usage: $0 <app> <version> <out.pkg>" >&2
	exit 2
fi
app=$1
version=$2
out=$3
scripts_dir="$(cd "$(dirname "$0")" && pwd)/scripts"

if [ ! -d "$app" ]; then
	echo "build-pkg: no app at $app" >&2
	exit 1
fi
# An app that fails this check installs, but macOS refuses to launch it.
codesign --verify --deep --strict "$app"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/root"
ditto "$app" "$work/root/$(basename "$app")"

# pkgbuild marks bundles relocatable by default: the installer then overwrites any app with
# the same bundle id, such as a dev build in build/DerivedData, instead of /Applications.
pkgbuild --analyze --root "$work/root" "$work/components.plist"
plutil -replace 0.BundleIsRelocatable -bool NO "$work/components.plist"

mkdir -p "$(dirname "$out")"
pkgbuild --root "$work/root" \
	--component-plist "$work/components.plist" \
	--install-location /Applications \
	--scripts "$scripts_dir" \
	--identifier com.niklod.LingvoBuddy.pkg \
	--version "$version" \
	"$out"
