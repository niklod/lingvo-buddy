# Running the app as an agent

The Makefile targets and the QA launch options are in `Makefile` and `App/Sources/Launch/LaunchOptions.swift`. This file holds what they do not tell you.

## Share the Mac safely

Other agents and the owner run LingvoBuddy on the same Mac at the same time. All builds share the bundle id `com.niklod.LingvoBuddy`, so they share one sandbox container.

- Give every run its own user database: `--user-db <your-name>`. Without it the app opens the owner's real database (`user`). `--seed-demo` refuses the default database, but every other option writes to it.
- The user databases live in `~/Library/Containers/com.niklod.LingvoBuddy/Data/Library/Application Support/LingvoBuddy/<name>.sqlite`. Open one with `sqlite3` to check what the app wrote.
- Start with `make run ARGS="--user-db <name> ..."`. It stops only the binary of your own checkout, then starts a new instance with `open -n`. If you start the app another way, record its PID and stop only that PID (`pgrep -f "user-db <name>"`). Never `pkill -x LingvoBuddy` or `killall`: that stops the apps of other agents.
- UserDefaults are shared: hotkeys, the pause end. Restore every value you change.
- A fresh `--user-db` opens onboarding at launch. Add `--skip-onboarding` when onboarding is not what you test.

## QA launch options are Debug-only

`LaunchOptions.parse` reads the QA flags only in a Debug build, and the snapshot code compiles only in Debug. `make app` builds Debug by default (`CONFIG ?= Debug`). A Release build (`CONFIG=Release`) ignores every flag, so `make snapshots` and the QA recipes need Debug.

- `--interval-seconds` changes only this run. Settings and the Dictionary "Rules" still show the stored interval.
- `--seed-demo` writes the design sample state (`DesignDemoSeed`). Extend that seed when a new view needs sample data.

## Snapshots

`make snapshots [FILTER=<text>]` renders every state in `App/Sources/QA/SnapshotRegistry.swift` to `build/snapshots/*.png`. Compare each one with `design/screenshots/<same name>.png` where the design has one.

- `ImageRenderer` draws AppKit-backed views (`List`, `ScrollView`, `TextField`, toggles, steppers, pickers, hotkey recorders) as yellow placeholders. For a state with any of these, set `usesWindow: true`: it renders through an offscreen `NSWindow`.
- Window snapshots show small artifacts that the real app does not have: a faint ghost glyph in hotkey recorders, faint vertical lines at the ends of capsule pills. Do not try to fix them.
- The sandbox lets the app write only inside its container. A relative `--snapshot` directory lands in `~/Library/Containers/com.niklod.LingvoBuddy/Data/tmp/`. The app prints each file path, and `make snapshots` copies them.
- A snapshot is a check of layout, not of behaviour. Drive the real app for focus, timers and windows.

## Drive the real app

Agent shells on this Mac have Accessibility and Screen Recording permission. Use CGEvent mouse and key events, the AX API or System Events, and capture with `screencapture -l <windowID>` or `screencapture -R x,y,w,h`.

- Two instances put two "Aa" icons side by side. Find your own icon by PID before you click: `osascript -e 'tell application "System Events" to tell (first process whose unix id is <pid>) to get {position, size} of every UI element of every menu bar'`.
- Move the pointer away from the status icon before a synthetic click on it. The click registers only when the pointer enters the icon from outside.
- Send keys as CGEvent key codes. System Events `keystroke` and Unicode-string CGEvents (`keyboardSetUnicodeString`) do not reach our non-activating panels (card, quick add) reliably.
- The save and open panels run out of process. Fill them with AX (`set value of text field "Save As:"`), or the keys may land in Finder.
- Test the Services item without a UI: call `NSPerformService("Add to LingvoBuddy", pasteboard)`. If the item does not show in the Services menu, run `/System/Library/CoreServices/pbs -flush`.

## Logs

`/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "com.niklod.LingvoBuddy"'`. The categories are `schedule`, `settings`, `focus` and `csv`. Write the full path: in zsh, `log` is a shell builtin.
