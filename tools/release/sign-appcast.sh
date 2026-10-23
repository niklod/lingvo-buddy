#!/bin/bash
# Signs the disk image with EdDSA (Ed25519) and writes the Sparkle 2 appcast with one item.
# Only OpenSSL 3 touches the private key: Sparkle's own tools never run in CI. Sparkle signs the
# raw bytes of the file, and its signature is the base64 of the 64 raw signature bytes.
# Usage: OPENSSL=<OpenSSL 3 binary> GITHUB_REPOSITORY=<owner/name> MINIMUM_SYSTEM_VERSION=<15.0> \
#   sign-appcast.sh <private-key.pem> <LingvoBuddy-X.Y.Z.dmg> <version> <build-number> <appcast.xml>
set -euo pipefail

fail() {
	echo "sign-appcast: $*" >&2
	exit 1
}

if [ $# -ne 5 ]; then
	echo "usage: $0 <private-key.pem> <dmg> <version> <build-number> <appcast.xml>" >&2
	exit 2
fi
key=$1 dmg=$2 version=$3 build=$4 appcast=$5
openssl=${OPENSSL:-}
repository=${GITHUB_REPOSITORY:-}
minimum_system_version=${MINIMUM_SYSTEM_VERSION:-}

# These values go into XML and into the URL: allow nothing else than the expected shapes.
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-dev\.[0-9]+)?$ ]] || fail "version '$version' is not X.Y.Z"
[[ "$build" =~ ^[0-9]+$ ]] || fail "build number '$build' is not a number"
[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "set GITHUB_REPOSITORY to owner/name"
[[ "$minimum_system_version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || fail "set MINIMUM_SYSTEM_VERSION, such as 15.0"
if [ ! -s "$dmg" ] || [ ! -s "$key" ]; then
	fail "the disk image or the key is missing or empty"
fi

# macOS LibreSSL cannot sign Ed25519 with -rawin: OpenSSL 3 is required.
[ -n "$openssl" ] || fail "set OPENSSL to an OpenSSL 3 binary (\$(brew --prefix openssl@3)/bin/openssl)"
openssl_version=$("$openssl" version 2> /dev/null || true)
[[ "$openssl_version" == "OpenSSL 3"* ]] || fail "$openssl is not OpenSSL 3"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

key_text=$("$openssl" pkey -in "$key" -noout -text 2> /dev/null || true)
grep -q '^ED25519' <<< "$key_text" || fail "the key is not an Ed25519 private key in PEM"
"$openssl" pkeyutl -sign -rawin -inkey "$key" -in "$dmg" -out "$work/sig.bin"
[ "$(wc -c < "$work/sig.bin" | tr -d ' ')" -eq 64 ] || fail "the signature is not 64 bytes"
signature=$(base64 < "$work/sig.bin" | tr -d '\n')

# A broken signature must stop the release before the appcast exists. The script prints the
# public key; compare it with the app's SUPublicEDKey by hand when the key changes.
"$openssl" pkey -in "$key" -pubout -out "$work/pub.pem"
if ! "$openssl" pkeyutl -verify -rawin -pubin -inkey "$work/pub.pem" -in "$dmg" \
	-sigfile "$work/sig.bin" > /dev/null; then
	fail "the EdDSA signature does not verify"
fi
# An Ed25519 SubjectPublicKeyInfo ends with the 32 raw public key bytes.
public_key=$("$openssl" pkey -pubin -in "$work/pub.pem" -outform DER | tail -c 32 | base64 | tr -d '\n')

length=$(wc -c < "$dmg" | tr -d ' ')
url="https://github.com/$repository/releases/download/v$version/$(basename "$dmg")"
pub_date=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')

cat > "$appcast" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>LingvoBuddy</title>
    <item>
      <title>Version $version</title>
      <pubDate>$pub_date</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$minimum_system_version</sparkle:minimumSystemVersion>
      <enclosure url="$url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
    </item>
  </channel>
</rss>
XML
echo "sign-appcast: $appcast (SUPublicEDKey $public_key)"
