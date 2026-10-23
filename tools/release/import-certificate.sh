#!/bin/bash
# Imports the release certificate into a new keychain that only codesign can use, so signing
# never touches the login keychain. The caller deletes the keychain when signing ends, also on
# failure: `security delete-keychain <keychain>`.
# Usage: RELEASE_CERT_P12_BASE64=<base64 .p12> RELEASE_CERT_PASSWORD=<.p12 password> \
#   import-certificate.sh <new.keychain-db>
set -euo pipefail

fail() {
	echo "import-certificate: $*" >&2
	exit 1
}

if [ $# -ne 1 ]; then
	echo "usage: $0 <new.keychain-db>" >&2
	exit 2
fi
keychain=$1

if [ -z "${RELEASE_CERT_P12_BASE64:-}" ] || [ -z "${RELEASE_CERT_PASSWORD:-}" ]; then
	fail "set RELEASE_CERT_P12_BASE64 and RELEASE_CERT_PASSWORD"
fi
[ ! -e "$keychain" ] || fail "$keychain exists; delete it first"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
p12="$work/release.p12"
if ! printf '%s' "$RELEASE_CERT_P12_BASE64" | base64 --decode > "$p12" || [ ! -s "$p12" ]; then
	fail "RELEASE_CERT_P12_BASE64 is not valid base64"
fi

# `security` takes the passwords only as arguments. They show in the process list, which is
# acceptable on a single-tenant CI runner that is thrown away after the job.
# Nobody types the keychain password: it only unlocks the keychain for the partition list below.
keychain_password=$(/usr/bin/openssl rand -base64 24)
security create-keychain -p "$keychain_password" "$keychain"
# Lock after an hour, not after the default 5 minutes of no use: a slow sign step must not stall.
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$p12" -k "$keychain" -f pkcs12 -P "$RELEASE_CERT_PASSWORD" -T /usr/bin/codesign
# Without the partition list, codesign waits for a "allow access to the key" dialog that a CI
# runner never answers.
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain" > /dev/null
echo "import-certificate: $keychain"
