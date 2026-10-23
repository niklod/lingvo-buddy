# Release signing

Release builds from the release workflow are signed with a self-signed code signing certificate, common name `LingvoBuddy Release`. Local and Debug builds stay ad-hoc (`CODE_SIGN_IDENTITY: "-"` in `project.yml`), and so does `make dmg`.

The designated requirement is `identifier "com.niklod.LingvoBuddy" and certificate leaf = H"<SHA-1 of the certificate>"`. Every build signed with the same certificate meets it, so macOS keeps the Focus permission (TCC) and the login item from one version to the next. An ad-hoc build has `cdhash H"..."` as its requirement, which changes with every build: that is why each ad-hoc update asked for the Focus permission again.

## Pipeline

`.github/workflows/release.yml` has four jobs:

- `version` (Ubuntu, no third-party code) makes the version: `X.Y.Z` from a tag, `0.0.0-dev.N` for a manual run. A tag must be `vX.Y.Z`, point at a commit in the history of `main` (GitHub compare API), and name a version newer than every published Release. Otherwise the run fails before the build.
- `build` runs the third-party actions, `make check` and `make release-app`, and uploads the ad-hoc app as a tar (an artifact loses the executable bit and symlinks). It holds no secret. A manual run stops here: its artifact is the unsigned app.
- `sign` runs only for `v*` tags, in the GitHub Environment `release`, which holds the secrets and allows only `v*` tags. It fetches the repository with plain `git` (no `actions/checkout`), downloads the app, runs `tools/release/import-certificate.sh` (a new keychain in `$RUNNER_TEMP`), then `tools/release/sign-release.sh` (signs inside out with the entitlements of its own checkout, checks the signature, builds the dmg with `build-dmg.sh`). An `if: always()` step deletes the keychain. Only then `actions/upload-artifact` uploads the dmg (kept 1 day); no secret is in its environment.
- `publish` uploads the dmg and `appcast.xml` to the Release.

After `sign-release.sh`, the `sign` job writes the EdDSA key to a file in `$RUNNER_TEMP` (umask 077) and runs `tools/release/sign-appcast.sh`. It signs the dmg with OpenSSL 3 (Homebrew `openssl@3`, found in an earlier step; macOS LibreSSL cannot sign Ed25519 with `-rawin`), verifies the signature with the public half of the same key, and writes `appcast.xml`. An `if: always()` step deletes the key file. No Sparkle binary runs in CI. The appcast has one item: `sparkle:version` = run number (`CFBundleVersion`), `sparkle:shortVersionString` = `X.Y.Z`, `sparkle:minimumSystemVersion` = the app's `LSMinimumSystemVersion`, the enclosure URL `https://github.com/<GITHUB_REPOSITORY>/releases/download/vX.Y.Z/LingvoBuddy-X.Y.Z.dmg`, `length` and `sparkle:edSignature`. The app reads it at `https://github.com/niklod/lingvo-buddy/releases/latest/download/appcast.xml`.

## Secrets

The secrets are Environment secrets of `release`, not repository secrets: only a `v*` tag run of the `sign` job can read them.

- `RELEASE_CERT_P12_BASE64`: base64 of a .p12 with the certificate and its private key.
- `RELEASE_CERT_PASSWORD`: the .p12 password.
- `SPARKLE_ED_PRIVATE_KEY`: the PEM text of an Ed25519 private key (see "Make the EdDSA key").

Back both up outside GitHub (password manager). A lost or new certificate changes the designated requirement: every learner then grants the Focus permission again, and Sparkle can refuse the update.

## Make the certificate (once)

Run the commands in `bash` or `zsh` (the heredoc does not work in fish), in a new folder outside the repository. They use `/usr/bin/openssl` (LibreSSL): `security import` reads its .p12. Homebrew OpenSSL 3 was not tested.

```sh
dir=$(mktemp -d) && cd "$dir" && umask 077
cat > release-cert.cnf <<'EOF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = LingvoBuddy Release
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF
/usr/bin/openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days 7300 \
  -config release-cert.cnf -keyout release-key.pem -out release-cert.pem
/usr/bin/openssl rand -base64 24 | tr -d '\n' > release-p12-password.txt
/usr/bin/openssl pkcs12 -export -name "LingvoBuddy Release" \
  -inkey release-key.pem -in release-cert.pem \
  -passout file:release-p12-password.txt -out release.p12
/usr/bin/openssl x509 -in release-cert.pem -noout -subject -enddate -fingerprint -sha1
```

The certificate is valid for 20 years: a new one would cost every learner the Focus permission.

1. Test the .p12 with "Test signing locally" below.
2. The maintainer stores `release.p12` and the text of `release-p12-password.txt` in a password manager and confirms it.
3. Only after the maintainer's explicit OK, set the secrets:

```sh
base64 -i release.p12 | gh secret set RELEASE_CERT_P12_BASE64 --env release --repo niklod/lingvo-buddy
gh secret set RELEASE_CERT_PASSWORD --env release --repo niklod/lingvo-buddy < release-p12-password.txt
```

4. Delete the folder: `rm -rf "$dir"`. The private key must not stay on disk.

## Test signing locally

Use a temporary keychain, never the login keychain. Run from the repository, with `$dir` from above:

```sh
make release-app VERSION=0.0.1 BUILD_NUMBER=101
ditto build/DerivedData/Build/Products/Release/LingvoBuddy.app "$dir/app/LingvoBuddy.app"
RELEASE_CERT_P12_BASE64=$(base64 -i "$dir/release.p12") RELEASE_CERT_PASSWORD=$(cat "$dir/release-p12-password.txt") \
  tools/release/import-certificate.sh "$dir/test.keychain-db"
KEYCHAIN="$dir/test.keychain-db" tools/release/sign-release.sh "$dir/app/LingvoBuddy.app" \
  "LingvoBuddy Release" 0.0.1 "$dir/LingvoBuddy-0.0.1.dmg"
security delete-keychain "$dir/test.keychain-db"
```

`sign-release.sh` prints the designated requirement. Sign a second build (`BUILD_NUMBER=102`): `codesign -d -r- <app>` must print the same line for both. Do not start a signed Release build to check it: a Release build ignores `--user-db` and opens the owner's database.

## Traps

- **The app's entitlements come from the checkout, not from the build.** `App/LingvoBuddy.entitlements` is a committed file (`CODE_SIGN_ENTITLEMENTS` in `project.yml`, not generated by XcodeGen). `sign-release.sh` signs the app with it, after it replaces `$(PRODUCT_BUNDLE_IDENTIFIER)` with the app's bundle id, because codesign does not expand build settings. It fails when the signed entitlements differ from the file, when the sandbox entitlement or hardened runtime is missing, or when a `com.apple.security.cs.*` entitlement other than `disable-library-validation` shows. Nested code keeps its own entitlements (`--preserve-metadata=entitlements`). Never preserve `requirements`: that keeps the ad-hoc `cdhash` requirement.
- **No secure timestamp.** `--timestamp` needs an Apple-issued certificate, so the script passes `--timestamp=none`.
- **The certificate is never "valid".** `security find-identity -p codesigning` lists it under "Matching identities" with `CSSMERR_TP_NOT_TRUSTED`, not under "valid identities". `codesign` signs with it anyway; no trust setting is needed. The script signs by SHA-1.
- **`codesign -R=` takes the `=` literally.** Write `-R "=<requirement>"` or `--test-requirement="=<requirement>"`.
- **`grep -q` after `codesign` under `pipefail`** fails the pipeline when grep stops early. Read the output into a variable first.
- **Resource bundles stay unsigned.** `GRDB_GRDB.bundle` and `KeyboardShortcuts_KeyboardShortcuts.bundle` hold no code; Xcode seals them as app resources, and the script does the same.
- **Nested code is signed inside out.** The script signs every code bundle (`.app`, `.xpc`, `.appex`, `.framework`, `.plugin`, `.bundle` with `Contents/MacOS`) and every bare Mach-O file under `Contents`, deepest first, with the same certificate, hardened runtime and their own entitlements. Sparkle's framework, XPC services, `Autoupdate` and `Updater.app` need nothing more.

## Make the EdDSA key (once)

The app's `SUPublicEDKey` is the base64 of the raw 32-byte public key. The secret is the PEM text of the private key. Run in `bash` or `zsh`, in a new folder outside the repository, with Homebrew OpenSSL 3 (`brew install openssl@3`):

```sh
dir=$(mktemp -d) && cd "$dir" && umask 077
ossl="$(brew --prefix openssl@3)/bin/openssl"
"$ossl" genpkey -algorithm ed25519 -out sparkle-ed.pem
"$ossl" pkey -in sparkle-ed.pem -pubout -outform DER | tail -c 32 | base64
```

The last command prints `SUPublicEDKey`. Give it to the app ticket. The maintainer stores `sparkle-ed.pem` in a password manager and confirms it. Only after the maintainer's explicit OK:

```sh
gh secret set SPARKLE_ED_PRIVATE_KEY --env release --repo niklod/lingvo-buddy < sparkle-ed.pem
rm -rf "$dir"
```

A lost key means no installed app can verify a new update: every learner must install by hand once.

## Test the appcast locally

```sh
OPENSSL="$(brew --prefix openssl@3)/bin/openssl" GITHUB_REPOSITORY=niklod/lingvo-buddy MINIMUM_SYSTEM_VERSION=15.0 \
  tools/release/sign-appcast.sh \
  "$dir/sparkle-ed.pem" LingvoBuddy-1.2.3.dmg 1.2.3 77 "$dir/appcast.xml" && xmllint --noout "$dir/appcast.xml"
```

To check the signature with Sparkle's `sign_update`, use a throwaway key, never the real one. `sign_update -f` reads the base64 of the 32-byte seed (`openssl pkey -in k.pem -outform DER | tail -c 32 | base64`). `sign_update -f <seed file> --verify <dmg> <signature>` must exit 0. Ed25519 is deterministic: `sign_update -f <seed file> <dmg>` prints the same signature as the script.

## EdDSA traps

- **Sign the raw bytes.** Sparkle verifies `edSignature` over the bytes of the dmg, base64 of the 64-byte signature. The script uses `pkeyutl -sign -rawin`; without `-rawin` OpenSSL 3 refuses Ed25519.
- **The version is part of the URL.** The enclosure URL uses the tag `vX.Y.Z` and the dmg name `LingvoBuddy-X.Y.Z.dmg`. A manual run (`0.0.0-dev.N`) does not sign, so it writes no appcast.
