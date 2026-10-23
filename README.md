<img src="assets/icon.svg" width="64" height="64" alt="">

# lingvo buddy

## Install

Each Release has `LingvoBuddy-<version>.dmg` (Apple silicon, macOS 15+).

1. Quit LingvoBuddy if it runs: Finder cannot replace an open app.
2. Open the dmg and drag `LingvoBuddy` onto the `Applications` alias. Confirm the replacement of the old version.
3. Eject the disk image and start LingvoBuddy from `/Applications`.

The app is not notarized. macOS blocks the first launch of each version that you download in a browser: open System Settings → Privacy & Security and click "Open Anyway".

Releases are signed with the LingvoBuddy release certificate, so macOS keeps the Focus permission and launch at login from one version to the next. Version 0.3.0 and older are ad-hoc signed: the first move from one of them to a signed version asks for the Focus permission one last time.

`gh` does not mark the download as quarantined, so this install from the terminal skips the "Open Anyway" step:

```sh
gh release download --repo niklod/lingvo-buddy --pattern '*.dmg' --output /tmp/LingvoBuddy.dmg --clobber
osascript -e 'quit app "LingvoBuddy"'
hdiutil attach -nobrowse -mountpoint /tmp/LingvoBuddy-mount /tmp/LingvoBuddy.dmg
rm -rf /Applications/LingvoBuddy.app
ditto /tmp/LingvoBuddy-mount/LingvoBuddy.app /Applications/LingvoBuddy.app
hdiutil detach /tmp/LingvoBuddy-mount
open /Applications/LingvoBuddy.app
```

## Release

Push a tag on a commit of `main`: `git tag v0.4.0 && git push origin v0.4.0`. The version must be newer than every published Release. The Release workflow runs `make check` and builds the app with that version. A separate job signs it with the release certificate (secrets of the `release` Environment), builds the dmg and publishes the Release with notes from the changes since the previous tag. A manual run of the workflow builds the unsigned app as a workflow artifact; it signs and publishes nothing. `make dmg VERSION=0.3.0` builds an ad-hoc signed dmg locally into `build/` and checks the mounted image. `docs/agents/release-signing.md` tells how to make the certificate and test the signing locally.

## Build

Needs Xcode 16.3+ and XcodeGen (`brew install xcodegen`).

- `make test` runs the LingvoCore tests.
- `make app` builds the dictionary, generates the Xcode project and builds the app.
- `make run ARGS="--user-db demo --seed-demo --open card"` starts the menu-bar app.
- `make snapshots` renders the designed view states to `build/snapshots/*.png`.

QA launch arguments: `--user-db <name|path>`, `--seed-demo`, `--open card|tray|settings|about|quick-add`, `--prefill <text>` (word for `--open quick-add`), `--snapshot <dir>`, `--snapshot-filter <text>`, `--interval-seconds <n>` (card interval), `--quiet-hours <HH:MM-HH:MM|off>`.

The app's package versions are locked in `App/Package.resolved`. After a version change in `project.yml`, run `make packages` and commit the file.

## Before you push

Run `make hooks` once (needs `brew install swiftlint ruff`). Then `make check` runs on every push: tests, warning-free builds, SwiftLint, ruff and a clean tree.
