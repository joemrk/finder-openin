APP_NAME := FinderOpenIn
EXT_ID := io.github.joemrk.FinderOpenIn.FinderExtension
BUILD_DIR := build
BUILT_APP := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app
INSTALLED_APP := /Applications/$(APP_NAME).app
APPEX := Contents/PlugIns/FinderExtension.appex
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
XCODEBUILD := xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) \
	-configuration Debug -derivedDataPath $(BUILD_DIR)

.PHONY: gen build test install log

gen:
	xcodegen generate

build: gen
	$(XCODEBUILD) build

test: gen
	$(XCODEBUILD) -destination 'platform=macOS' test

install: build
	-pkill -x $(APP_NAME)
	rm -rf $(INSTALLED_APP)
	ditto $(BUILT_APP) $(INSTALLED_APP)
	@# The copy in the build folder must not claim the extension or the URL scheme.
	-pluginkit -r $(BUILT_APP)/$(APPEX)
	-$(LSREGISTER) -u $(BUILT_APP)
	pluginkit -a $(INSTALLED_APP)/$(APPEX)
	@# Registration is asynchronous: enable as soon as pluginkit sees the extension.
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		pluginkit -m -i $(EXT_ID) | grep -q '^+' && break; \
		sleep 1; \
		pluginkit -e use -i $(EXT_ID); \
	done
	@pluginkit -m -i $(EXT_ID)
	@# Every registration/enable adds one more extension instance to Finder while the old
	@# ones stay, so menu items get duplicated. Kill them all: Finder restarts exactly one.
	@sleep 2
	-pkill -f "$(APPEX)/Contents/MacOS/FinderExtension"
	open $(INSTALLED_APP)

log:
	log stream --level debug --predicate 'subsystem == "io.github.joemrk.FinderOpenIn"'
