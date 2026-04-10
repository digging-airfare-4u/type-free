APP_NAME = TypeFree
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build run install clean

build:
	swift build -c release
	@# Create .app bundle
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@# Sign the app (ad-hoc)
	codesign --force --sign - \
		--entitlements TypeFree.entitlements \
		--options runtime \
		$(APP_BUNDLE)
	@echo "Built: $(APP_BUNDLE)"

run: build
	open $(APP_BUNDLE)

install: build
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	rm -rf .build
