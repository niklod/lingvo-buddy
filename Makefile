CORE_DIR     := LingvoCore
BUILD_DIR    := build
DERIVED_DIR  := $(BUILD_DIR)/DerivedData
PACKAGES_DIR := $(BUILD_DIR)/SourcePackages
CONFIG       ?= Debug
APP          := $(DERIVED_DIR)/Build/Products/$(CONFIG)/LingvoBuddy.app
APP_BINARY   := $(APP)/Contents/MacOS/LingvoBuddy
SHELL        := /bin/bash

# The sample dictionary stays bundled until the real Top-1000 data replaces it.
DICT_SOURCES ?= $(CORE_DIR)/Tests/LingvoCoreTests/Fixtures/sample-dictionary.json
DICT_OUT     := App/Resources/dictionary.sqlite

# Extra launch arguments for `make run`, for example ARGS="--user-db demo --seed-demo --open card".
ARGS ?=

.PHONY: test dictionary project app run snapshots clean

test:
	swift test --package-path $(CORE_DIR)

dictionary:
	swift run --package-path $(CORE_DIR) lingvo-dict build --out $(DICT_OUT) $(DICT_SOURCES)

project:
	xcodegen generate --quiet

app: dictionary project
	xcodebuild -project LingvoBuddy.xcodeproj -scheme LingvoBuddy -configuration $(CONFIG) -destination "platform=macOS,arch=$$(uname -m)" \
		-derivedDataPath $(DERIVED_DIR) -clonedSourcePackagesDirPath $(PACKAGES_DIR) \
		-quiet build

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

clean:
	rm -rf $(BUILD_DIR) LingvoBuddy.xcodeproj $(DICT_OUT) App/Info.plist App/LingvoBuddy.entitlements
	swift package --package-path $(CORE_DIR) clean
