APP_NAME   := MailSink
BUNDLE_ID  := io.github.iuhw.mailsink
VERSION    := 1.0.0
PREFIX     ?= $(HOME)/Applications
APP        := $(PREFIX)/$(APP_NAME).app
BUILD_DIR  := build
STAGED     := $(BUILD_DIR)/$(APP_NAME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all app install uninstall check icon clean

all: install

app: $(STAGED)

$(STAGED): Sources/MailSink.swift Resources/Info.plist Resources/AppIcon.icns
	@rm -rf "$(STAGED)"
	@mkdir -p "$(STAGED)/Contents/MacOS" "$(STAGED)/Contents/Resources"
	swiftc -O -swift-version 5 -o "$(STAGED)/Contents/MacOS/$(APP_NAME)" Sources/MailSink.swift
	@cp Resources/Info.plist "$(STAGED)/Contents/Info.plist"
	@cp Resources/AppIcon.icns "$(STAGED)/Contents/Resources/AppIcon.icns"
	@codesign --force --sign - --identifier "$(BUNDLE_ID)" "$(STAGED)"
	@echo "Built: $(STAGED)"

install: $(STAGED)
	@mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources" "$(APP)/Contents/_CodeSignature"
	@cp -f "$(STAGED)/Contents/MacOS/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	@cp -f "$(STAGED)/Contents/Info.plist" "$(APP)/Contents/Info.plist"
	@cp -f "$(STAGED)/Contents/Resources/AppIcon.icns" "$(APP)/Contents/Resources/AppIcon.icns"
	@cp -f "$(STAGED)/Contents/_CodeSignature/CodeResources" "$(APP)/Contents/_CodeSignature/CodeResources"
	@$(LSREGISTER) -f "$(APP)"
	@"$(APP)/Contents/MacOS/$(APP_NAME)" --install
	@echo "Installed: $(APP)"

uninstall:
	@"$(APP)/Contents/MacOS/$(APP_NAME)" --uninstall || true
	@$(LSREGISTER) -u "$(APP)" || true
	@rm -rf "$(APP)"
	@echo "Removed: $(APP)"

check:
	@echo "mailto: is handled by $$( '$(APP)/Contents/MacOS/$(APP_NAME)' --check )"

icon:
	swiftc -O -o $(BUILD_DIR)/makeicon Sources/MakeIcon.swift
	$(BUILD_DIR)/makeicon docs/icon.png
	@rm -rf $(BUILD_DIR)/AppIcon.iconset && mkdir -p $(BUILD_DIR)/AppIcon.iconset
	@for s in 16 32 128 256 512; do \
		sips -z $$s $$s docs/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
		d=$$((s*2)); \
		sips -z $$d $$d docs/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	@iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "Regenerated Resources/AppIcon.icns"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned"
