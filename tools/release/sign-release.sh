#!/bin/bash
# Signs a Release LingvoBuddy.app with the release certificate, then wraps it into the disk image
# with build-dmg.sh. The designated requirement pins the bundle identifier and this certificate,
# so macOS keeps the Focus permission and the login item from one version to the next.
# Usage: sign-release.sh <app> <identity common name> <version> <out.dmg>
# KEYCHAIN=<path> limits the identity search to one keychain (the sign job's temporary keychain).
set -euo pipefail

if [ $# -ne 4 ]; then
	echo "usage: $0 <app> <identity> <version> <out.dmg>" >&2
	exit 2
fi
app=$1
identity=$2
version=$3
out=$4
keychain=${KEYCHAIN:-}

fail() {
	echo "sign-release: $*" >&2
	exit 1
}

[ -d "$app" ] || fail "no app at $app"
info="$app/Contents/Info.plist"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info")
main_executable="$app/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info")"

# Sign by SHA-1, not by name: a common name can match several certificates, and the requirement
# below needs the hash. The certificate is self-signed, so it is never in the "valid" list.
hashes=$(security find-identity -p codesigning ${keychain:+"$keychain"} \
	| grep -F "\"$identity\"" | awk '{print $2}' | sort -u || true)
count=$(printf '%s' "$hashes" | grep -c . || true)
[ "$count" -eq 1 ] || fail "expected one code signing identity \"$identity\"${keychain:+ in $keychain}, found $count"
cert=$(printf '%s' "$hashes" | tr 'A-F' 'a-f')

# The ad-hoc signature from Xcode holds the entitlements (the sandbox among them): keep them.
# A secure timestamp needs an Apple-issued certificate.
sign() {
	codesign --force --sign "$cert" ${keychain:+--keychain "$keychain"} --options runtime \
		--timestamp=none --preserve-metadata=entitlements "$@"
}

# Resource bundles of Swift packages (GRDB_GRDB.bundle) hold no code. Xcode leaves them unsigned
# and seals them as resources of the app: do the same.
holds_code() {
	case $1 in
		*.bundle) [ -d "$1/Contents/MacOS" ] ;;
		*) true ;;
	esac
}

# Inside out: `find -depth` lists what a bundle holds before the bundle itself. Bare Mach-O
# helpers (such as Sparkle's Autoupdate) are no bundles, so each executable is signed on its own.
while IFS= read -r -d '' path; do
	if [ -d "$path" ]; then
		if holds_code "$path"; then
			sign "$path"
		fi
	elif [ "$path" != "$main_executable" ] && file -b "$path" | grep -q Mach-O; then
		sign "$path"
	fi
done < <(find "$app/Contents" -depth \( -type d \( -name '*.app' -o -name '*.appex' -o -name '*.xpc' \
	-o -name '*.framework' -o -name '*.bundle' -o -name '*.plugin' \) \
	-o -type f \( -perm -u+x -o -name '*.dylib' \) \) -print0)

# The default requirement of an ad-hoc build is its cdhash, which changes with every build.
requirement="identifier \"$bundle_id\" and certificate leaf = H\"$cert\""
sign --requirements "=designated => $requirement" "$app"

# Each check reads the codesign output into a variable first: with pipefail, `grep -q` that
# stops early makes the pipeline fail.
codesign --verify --deep --strict "$app"
codesign --verify --test-requirement="=$requirement" "$app"
designated=$(codesign --display --requirements - "$app" 2>&1 | grep '^designated' || true)
[ "$designated" = "designated => $requirement" ] || fail "unexpected designated requirement: $designated"
details=$(codesign --display --verbose "$app" 2>&1)
grep -q 'flags=0x[0-9a-f]*(.*runtime' <<< "$details" || fail "no hardened runtime"
# A signature without the sandbox entitlement starts the app outside its container: no data.
entitlements=$(codesign --display --entitlements - --xml "$app" 2> /dev/null)
grep -q com.apple.security.app-sandbox <<< "$entitlements" || fail "the signature lost the sandbox entitlement"
echo "sign-release: $designated"

"$(dirname "$0")/build-dmg.sh" "$app" "$version" "$out"
