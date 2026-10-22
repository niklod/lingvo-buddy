CORE_DIR     := LingvoCore
BUILD_DIR    := build
DERIVED_DIR  := $(BUILD_DIR)/DerivedData
PACKAGES_DIR := $(BUILD_DIR)/SourcePackages
CONFIG       ?= Debug
APP          := $(DERIVED_DIR)/Build/Products/$(CONFIG)/LingvoBuddy.app
APP_BINARY   := $(APP)/Contents/MacOS/LingvoBuddy
SHELL        := /bin/bash
PYTHON       ?= python3

DICT_TOOLS   := tools/dictionary
DICT_OUT     := App/Resources/dictionary.sqlite
EXTENDED_OUT := App/Resources/extended-dictionary.sqlite

# The app's package pins. When the generated project has no resolved file, Xcode writes the
# app's pins (KeyboardShortcuts too) into the tracked LingvoCore/Package.resolved instead.
APP_RESOLVED   := App/Package.resolved
XCODE_RESOLVED := LingvoBuddy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
XCODEBUILD     := xcodebuild -project LingvoBuddy.xcodeproj -scheme LingvoBuddy -configuration $(CONFIG) \
	-destination "platform=macOS,arch=$$(uname -m)" \
	-derivedDataPath $(DERIVED_DIR) -clonedSourcePackagesDirPath $(PACKAGES_DIR)
# Extra xcodebuild build settings for `make app`. `make app-strict` passes STRICT_WARNINGS=YES.
XCODE_SETTINGS ?=

# Extra launch arguments for `make run`, for example ARGS="--user-db demo --seed-demo --open card".
ARGS ?=

# `make pkg` stamps these into the app. The release workflow passes the tag and the run number.
VERSION      ?= 0.0.0-dev
BUILD_NUMBER ?= 1
PKG          := $(BUILD_DIR)/LingvoBuddy-$(VERSION).pkg

.PHONY: test test-core test-dictionary check lint lint-swift lint-python build-core-strict app-strict \
	hooks dictionary import-wiktionary project packages app run snapshots pkg clean

test: test-core test-dictionary

test-core:
	swift test --package-path $(CORE_DIR)

# Dictionary tooling tests, the data gate (every rank of the word list has a valid entry),
# and a read of the built file through LingvoCore, as the app reads it.
test-dictionary:
	$(PYTHON) -m unittest discover -s $(DICT_TOOLS)/tests -t $(DICT_TOOLS)
	$(PYTHON) $(DICT_TOOLS)/validate.py --full
	$(PYTHON) $(DICT_TOOLS)/build_dictionary.py --full --out $(BUILD_DIR)/dictionary/dictionary.sqlite
	$(PYTHON) $(DICT_TOOLS)/build_extended_dictionary.py --out $(BUILD_DIR)/dictionary/extended-dictionary.sqlite
	swift run --package-path $(CORE_DIR) lingvo-dict check $(BUILD_DIR)/dictionary/dictionary.sqlite \
		$(BUILD_DIR)/dictionary/extended-dictionary.sqlite

# The full gate before a push (the pre-push hook and CI run it). `make test` stays the fast loop.
# The last step fails when a build changed a tracked file, or when work is not committed.
check: lint test build-core-strict app-strict
	@git diff --exit-code --stat || { echo "make check: tracked files changed; commit them or find the step that writes them."; exit 1; }

lint: lint-swift lint-python

lint-swift:
	swiftlint lint --strict --quiet

lint-python:
	ruff check $(DICT_TOOLS)

# Own scratch path: the strict flag would otherwise make the next `make test` rebuild everything.
build-core-strict:
	swift build --package-path $(CORE_DIR) --scratch-path $(BUILD_DIR)/core-strict --build-tests -Xswiftc -warnings-as-errors

app-strict:
	$(MAKE) app XCODE_SETTINGS=STRICT_WARNINGS=YES

hooks:
	git config core.hooksPath .githooks

# Both files come from committed sources and need no network. `make import-wiktionary` is the manual refresh.
dictionary:
	$(PYTHON) $(DICT_TOOLS)/build_dictionary.py --full --out $(DICT_OUT)
	$(PYTHON) $(DICT_TOOLS)/build_extended_dictionary.py --out $(EXTENDED_OUT)

# Downloads about 700 MB of kaikki.org extracts into WIKT_DIR (keep it outside the repository) and rewrites
# data/extended/extended-dictionary.txt. Review the diff, then delete the downloads.
import-wiktionary:
	@test -n "$(WIKT_DIR)" || { echo "pass WIKT_DIR=<an empty folder outside the repository>"; exit 1; }
	$(PYTHON) $(DICT_TOOLS)/import_wiktionary.py --download-dir "$(WIKT_DIR)"

project:
	xcodegen generate --quiet
	mkdir -p $(dir $(XCODE_RESOLVED))
	cp $(APP_RESOLVED) $(XCODE_RESOLVED)

# After a package version change in project.yml: resolve again and keep the new pins.
packages: project
	$(XCODEBUILD) -resolvePackageDependencies
	cp $(XCODE_RESOLVED) $(APP_RESOLVED)

app: dictionary project
	$(XCODEBUILD) -onlyUsePackageVersionsFromResolvedFile -quiet build $(XCODE_SETTINGS)

run: app
	@# Stop only this checkout's build: other worktrees may run their own copy.
	-pkill -f "$(abspath $(APP_BINARY))"
	open -n $(APP) --args $(ARGS)

# Renders every registered view state to PNG inside the sandbox container (the app prints
# each file path), then copies them to build/snapshots. FILTER=q1 renders matching states only.
snapshots: app
	rm -rf $(BUILD_DIR)/snapshots && mkdir -p $(BUILD_DIR)/snapshots
	set -o pipefail; $(APP_BINARY) --snapshot snapshots $(if $(FILTER),--snapshot-filter $(FILTER)) \
		| while read -r file; do cp "$$file" $(BUILD_DIR)/snapshots/; done
	@ls $(BUILD_DIR)/snapshots

# Release build for Apple silicon only, wrapped into an installer for /Applications.
# Xcode adds get-task-allow (a debugger may attach) to every build that is not an archive.
pkg:
	$(MAKE) app CONFIG=Release XCODE_SETTINGS="ARCHS=arm64 CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
		MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(BUILD_NUMBER)"
	tools/release/build-pkg.sh $(DERIVED_DIR)/Build/Products/Release/LingvoBuddy.app $(VERSION) $(PKG)

clean:
	rm -rf $(BUILD_DIR) LingvoBuddy.xcodeproj $(DICT_OUT) $(EXTENDED_OUT) App/Info.plist App/LingvoBuddy.entitlements
	swift package --package-path $(CORE_DIR) clean
