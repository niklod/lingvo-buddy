<img src="assets/icon.svg" width="64" height="64" alt="">

# lingvo buddy

## Install

Each Release has `LingvoBuddy-<version>.pkg` (Apple silicon, macOS 15+). It installs the app into `/Applications` and restarts a running copy.

```sh
gh release download --repo niklod/lingvo-buddy --pattern '*.pkg' --output /tmp/LingvoBuddy.pkg --clobber
sudo installer -pkg /tmp/LingvoBuddy.pkg -target /
```

The app is not notarized. `gh` does not mark the download as quarantined, so macOS does not block it. A pkg downloaded in a browser is blocked once: open System Settings → Privacy & Security and click "Open Anyway". After an update, macOS can ask for the Focus permission again.

## Release

Push a tag: `git tag v0.2.0 && git push origin v0.2.0`. The Release workflow runs `make check`, builds the pkg with that version and publishes the Release with notes from the changes since the previous tag. A manual run of the workflow builds the pkg as a workflow artifact and publishes nothing. `make pkg VERSION=0.2.0` builds the same pkg locally into `build/`.

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
