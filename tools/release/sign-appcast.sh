#!/bin/bash
# Signs the disk image with EdDSA (Ed25519) and writes the Sparkle 2 appcast with one item.
# Only OpenSSL 3 touches the private key: Sparkle's own tools never run in CI. Sparkle signs the
# raw bytes of the file, and its signature is the base64 of the 64 raw signature bytes.
# Usage: sign-appcast.sh <private-key.pem> <LingvoBuddy-X.Y.Z.dmg> <version> <build-number> <appcast.xml>
# OPENSSL overrides the OpenSSL 3 binary (default: Homebrew's openssl@3).
set -euo pipefail

if [ $# -ne 5 ]; then
	echo "usage: $0 <private-key.pem> <dmg> <version> <build-number> <appcast.xml>" >&2
	exit 2
fi
key=$1 dmg=$2 version=$3 build=$4 appcast=$5

# The version goes into XML and into the URL: allow nothing else than X.Y.Z or a dev version.
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-dev\.[0-9]+)?$ ]]; then
	echo "sign-appcast: version '$version' is not X.Y.Z" >&2
	exit 1
fi
if ! [[ "$build" =~ ^[0-9]+$ ]]; then
	echo "sign-appcast: build number '$build' is not a number" >&2
	exit 1
fi
if [ ! -s "$dmg" ] || [ ! -s "$key" ]; then
	echo "sign-appcast: the disk image or the key is missing or empty" >&2
	exit 1
fi

# macOS LibreSSL cannot sign Ed25519 with -rawin: OpenSSL 3 is required.
openssl=${OPENSSL:-}
if [ -z "$openssl" ] && command -v brew > /dev/null; then
	openssl="$(brew --prefix openssl@3)/bin/openssl"
fi
if [ -z "$openssl" ] || ! "$openssl" version | grep -q '^OpenSSL 3'; then
	echo "sign-appcast: OpenSSL 3 is required (brew install openssl@3, or set OPENSSL)" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

key_text=$("$openssl" pkey -in "$key" -noout -text 2> /dev/null || true)
if ! grep -q '^ED25519' <<< "$key_text"; then
	echo "sign-appcast: the key is not an Ed25519 private key in PEM" >&2
	exit 1
fi
"$openssl" pkeyutl -sign -rawin -inkey "$key" -in "$dmg" -out "$work/sig.bin"
if [ "$(wc -c < "$work/sig.bin" | tr -d ' ')" -ne 64 ]; then
	echo "sign-appcast: the signature is not 64 bytes" >&2
	exit 1
fi
signature=$(base64 < "$work/sig.bin" | tr -d '\n')

# The signature must verify against the public half of the same key, which the app embeds.
"$openssl" pkey -in "$key" -pubout -out "$work/pub.pem"
if ! "$openssl" pkeyutl -verify -rawin -pubin -inkey "$work/pub.pem" -in "$dmg" \
	-sigfile "$work/sig.bin" > /dev/null; then
	echo "sign-appcast: the EdDSA signature does not verify" >&2
	exit 1
fi
# An Ed25519 SubjectPublicKeyInfo ends with the 32 raw public key bytes.
public_key=$("$openssl" pkey -pubin -in "$work/pub.pem" -outform DER | tail -c 32 | base64 | tr -d '\n')

length=$(wc -c < "$dmg" | tr -d ' ')
url="https://github.com/niklod/lingvo-buddy/releases/download/v$version/$(basename "$dmg")"
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
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure url="$url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
    </item>
  </channel>
</rss>
XML
echo "sign-appcast: $appcast (SUPublicEDKey $public_key)"
