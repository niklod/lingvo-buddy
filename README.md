<img src="assets/icon.svg" width="64" height="64" alt="">

# lingvo buddy

## Install

Each Release has `LingvoBuddy-<version>.dmg` (Apple silicon, macOS 15+).

1. Quit LingvoBuddy if it runs: Finder cannot replace an open app.
2. Open the dmg and drag `LingvoBuddy` onto the `Applications` alias. Confirm the replacement of the old version.
3. Eject the disk image and start LingvoBuddy from `/Applications`.

The app is not notarized. macOS blocks the first launch of each version that you download in a browser: open System Settings → Privacy & Security and click "Open Anyway". After an update, macOS can ask for the Focus permission again.

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

Push a tag: `git tag v0.3.0 && git push origin v0.3.0`. The Release workflow runs `make check`, builds the dmg with that version and publishes the Release with notes from the changes since the previous tag. A manual run of the workflow builds the dmg as a workflow artifact and publishes nothing. `make dmg VERSION=0.3.0` builds the same dmg locally into `build/` and checks the mounted image.

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
