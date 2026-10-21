CORE_DIR     := LingvoCore
BUILD_DIR    := build
DERIVED_DIR  := $(BUILD_DIR)/DerivedData
PACKAGES_DIR := $(BUILD_DIR)/SourcePackages
CONFIG       ?= Debug
APP          := $(DERIVED_DIR)/Build/Products/$(CONFIG)/LingvoBuddy.app
APP_BINARY   := $(APP)/Contents/MacOS/LingvoBuddy
SHELL        := /bin/bash
PYTHON       ?= python3

# The bundled dictionary is built from data/batches (all 20 batches, ranks 1-10000).
# The 40-word sample in LingvoCore's test fixtures is only a test fixture now.
DICT_TOOLS   := tools/dictionary
DICT_OUT     := App/Resources/dictionary.sqlite

# Extra launch arguments for `make run`, for example ARGS="--user-db demo --seed-demo --open card".
ARGS ?=

.PHONY: test test-core test-dictionary dictionary project app run snapshots clean

test: test-core test-dictionary

test-core:
	swift test --package-path $(CORE_DIR)

# Dictionary tooling tests, the data gate (every rank of the word list has a valid entry),
# and a read of the built file through LingvoCore, as the app reads it.
test-dictionary:
	$(PYTHON) -m unittest discover -s $(DICT_TOOLS)/tests -t $(DICT_TOOLS)
	$(PYTHON) $(DICT_TOOLS)/validate.py --full
	$(PYTHON) $(DICT_TOOLS)/build_dictionary.py --full --out $(BUILD_DIR)/dictionary/dictionary.sqlite
	swift run --package-path $(CORE_DIR) lingvo-dict check $(BUILD_DIR)/dictionary/dictionary.sqlite

dictionary:
	$(PYTHON) $(DICT_TOOLS)/build_dictionary.py --full --out $(DICT_OUT)

project:
	xcodegen generate --quiet

app: dictionary project
	xcodebuild -project LingvoBuddy.xcodeproj -scheme LingvoBuddy -configuration $(CONFIG) -destination "platform=macOS,arch=$$(uname -m)" \
		-derivedDataPath $(DERIVED_DIR) -clonedSourcePackagesDirPath $(PACKAGES_DIR) \
		-quiet build

run: app
	-pkill -x LingvoBuddy
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
