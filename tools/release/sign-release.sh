#!/bin/bash
# Signs a Release LingvoBuddy.app with the release certificate, then wraps it into the disk image
# with build-dmg.sh. The designated requirement pins the bundle identifier and this certificate,
# so macOS keeps the Focus permission and the login item from one version to the next.
# Usage: sign-release.sh <app> <identity common name> <version> <out.dmg>
# KEYCHAIN=<path> limits the identity search to one keychain (the sign job's temporary keychain).
# ENTITLEMENTS=<path> overrides the app's entitlements (default: App/LingvoBuddy.entitlements of
# this checkout).
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
entitlements_source=${ENTITLEMENTS:-$(dirname "$0")/../../App/LingvoBuddy.entitlements}
# The self-signed certificate has no Team ID, so library validation would refuse Sparkle.framework
# (docs/agents/release-signing.md). Any other hardened runtime exception fails the release.
allowed_runtime_exception=com.apple.security.cs.disable-library-validation

fail() {
	echo "sign-release: $*" >&2
	exit 1
}

[ -d "$app" ] || fail "no app at $app"
[ -s "$entitlements_source" ] || fail "no entitlements at $entitlements_source"
info="$app/Contents/Info.plist"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info")
[[ "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]] || fail "unexpected bundle identifier: $bundle_id"
main_executable="$app/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info")"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Xcode expands build settings in the entitlements file; codesign does not.
entitlements="$work/entitlements.plist"
# shellcheck disable=SC2016 # $(PRODUCT_BUNDLE_IDENTIFIER) is literal text of the file.
sed 's/$(PRODUCT_BUNDLE_IDENTIFIER)/'"$bundle_id"'/g' "$entitlements_source" > "$entitlements"
expanded=$(cat "$entitlements")
[[ "$expanded" != *"\$("* ]] || fail "an unexpanded build setting is left in $entitlements_source"

# Sign by SHA-1, not by name: a common name can match several certificates, and the requirement
# below needs the hash. The certificate is self-signed, so it is never in the "valid" list.
hashes=$(security find-identity -p codesigning ${keychain:+"$keychain"} \
	| grep -F "\"$identity\"" | awk '{print $2}' | sort -u || true)
count=$(printf '%s' "$hashes" | grep -c . || true)
[ "$count" -eq 1 ] || fail "expected one code signing identity \"$identity\"${keychain:+ in $keychain}, found $count"
cert=$(printf '%s' "$hashes" | tr 'A-F' 'a-f')

# A secure timestamp needs an Apple-issued certificate.
sign() {
	codesign --force --sign "$cert" ${keychain:+--keychain "$keychain"} --options runtime \
		--timestamp=none "$@"
}

# Resource bundles of Swift packages (GRDB_GRDB.bundle) hold no code. Xcode leaves them unsigned
# and seals them as resources of the app: do the same. Bare Mach-O helpers (such as Sparkle's
# Autoupdate) are no bundles, so each one is signed on its own. The main executable is signed
# with the app.
needs_sign() {
	local kind
	if [ -d "$1" ]; then
		case $1 in
			*.bundle) [ -d "$1/Contents/MacOS" ] ;;
			*) true ;;
		esac
	elif [ "$1" = "$main_executable" ]; then
		false
	else
		kind=$(file -b "$1")
		[[ "$kind" == *Mach-O* ]]
	fi
}

# Inside out: `find -depth` lists what a bundle holds before the bundle itself. Nested code
# (Sparkle's helpers) keeps the entitlements of its own ad-hoc signature.
while IFS= read -r -d '' path; do
	if needs_sign "$path"; then
		sign --preserve-metadata=entitlements "$path"
	fi
done < <(find "$app/Contents" -depth \( -type d \( -name '*.app' -o -name '*.appex' -o -name '*.xpc' \
	-o -name '*.framework' -o -name '*.bundle' -o -name '*.plugin' \) \
	-o -type f \( -perm -u+x -o -name '*.dylib' \) \) -print0)

# The default requirement of an ad-hoc build is its cdhash, which changes with every build.
# The app gets the entitlements of this checkout, never those of the build job's app.
requirement="identifier \"$bundle_id\" and certificate leaf = H\"$cert\""
sign --entitlements "$entitlements" --requirements "=designated => $requirement" "$app"

# Each check reads the codesign output into a variable first: with pipefail, `grep -q` that
# stops early makes the pipeline fail. build-dmg.sh runs `codesign --verify --deep --strict`.
codesign --verify --test-requirement="=$requirement" "$app"
designated=$(codesign --display --requirements - "$app" 2>&1 | grep '^designated' || true)
[ "$designated" = "designated => $requirement" ] || fail "unexpected designated requirement: $designated"
details=$(codesign --display --verbose "$app" 2>&1)
grep -q 'flags=0x[0-9a-f]*(.*runtime' <<< "$details" || fail "no hardened runtime"
codesign --display --entitlements - --xml "$app" 2> /dev/null > "$work/signed.plist"
[ "$(plutil -convert json -o - "$work/signed.plist")" = "$(plutil -convert json -o - "$entitlements")" ] \
	|| fail "the signed entitlements differ from $entitlements_source"
signed=$(cat "$work/signed.plist")
# A signature without the sandbox entitlement starts the app outside its container: no data.
grep -q com.apple.security.app-sandbox <<< "$signed" || fail "the signature has no sandbox entitlement"
runtime_exceptions=$(grep -o 'com\.apple\.security\.cs\.[A-Za-z0-9.-]*' <<< "$signed" || true)
for exception in $runtime_exceptions; do
	[ "$exception" = "$allowed_runtime_exception" ] || fail "hardened runtime exception $exception is not allowed"
done
echo "sign-release: $designated"

"$(dirname "$0")/build-dmg.sh" "$app" "$version" "$out"
