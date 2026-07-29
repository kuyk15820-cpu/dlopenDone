ARCHS := arm64
TARGET := iphone:clang:latest:14.0
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := DylibTester

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := DylibTester

Trash_SRC = $(wildcard Trash/*.mm) $(wildcard Trash/*.m)
Splash_SRC = $(wildcard Splash/*.mm) $(wildcard Splash/*.m)
src_SRC = $(shell find src -name "*.m" -o -name "*.mm")
src_INC = $(addprefix -I,$(shell find src -type d))
Shared_SRC = $(shell find Shared -name "*.m" -o -name "*.mm")
Shared_INC = $(addprefix -I,$(shell find Shared -type d))

$(APPLICATION_NAME)_USE_MODULES := 0

$(APPLICATION_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)
# $(APPLICATION_NAME)_FILES += $(wildcard sources/Settings/*.mm sources/Settings/*.m)
# $(APPLICATION_NAME)_FILES += $(Trash_SRC)
$(APPLICATION_NAME)_FILES += $(Splash_SRC)
$(APPLICATION_NAME)_FILES += $(src_SRC)
$(APPLICATION_NAME)_FILES += $(Shared_SRC)

# [ปรับปรุง] เพิ่ม -fobjc-arc-exceptions รองรับ ObjC++ (.mm)
$(APPLICATION_NAME)_CFLAGS += -fobjc-arc -fobjc-arc-exceptions -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wunused-but-set-variable -Wno-error=missing-noescape -Wno-error=objc-dictionary-duplicate-keys -Wno-error -Wno-unused-property-ivar -Wno-implicit-function-declaration
$(APPLICATION_NAME)_CFLAGS += -Iheaders -Isources -ISplash -Isources/Settings -F./deps -I./deps/ffmpegkit.framework/Headers
$(APPLICATION_NAME)_CFLAGS += $(src_INC) $(Shared_INC)

$(APPLICATION_NAME)_STRIP = 1
$(APPLICATION_NAME)_SWIFTFLAGS = -I.

$(APPLICATION_NAME)_CCFLAGS += -std=c++17 -fno-rtti -DNDEBUG -Wall -fvisibility=hidden -Wno-unused-variable

# [ปรับปรุง] เปลี่ยน -lstdc++ เป็น -lc++ และเพิ่ม -rdynamic สำหรับ dlopen
$(APPLICATION_NAME)_LDFLAGS += -lc++ -undefined dynamic_lookup -F./deps -Wl,-rpath,@executable_path/Frameworks -rdynamic

$(APPLICATION_NAME)_FRAMEWORKS += UIKit Foundation CoreGraphics QuartzCore Security AVFoundation AudioToolbox CoreMedia MobileCoreServices SystemConfiguration ImageIO WebKit UniformTypeIdentifiers PhotosUI CoreText CFNetwork Network

$(APPLICATION_NAME)_EXTRA_FRAMEWORKS += ffmpegkit Lottie

$(APPLICATION_NAME)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(APPLICATION_NAME)_RESOURCE_DIRS = ./layout/Resources

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	@echo "[*] Copying all FFmpegKit frameworks from deps into App Bundle..."
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/Frameworks
	@cp -a ./deps/*.framework $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/Frameworks/
	
	@echo "[*] Cleaning developer headers and modules inside app bundle..."
	@rm -rf $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/Frameworks/*.framework/Headers
	@rm -rf $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/Frameworks/*.framework/Modules

	# [เพิ่ม] ตั้งสิทธิ์ Executable ให้ ldid หากถูกวางไว้ใน App Bundle
	@if [ -f $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/ldid ]; then \
		chmod 755 $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/ldid; \
	fi

after-package::
	@rm -rf Payload
	@mkdir -p Payload
	@cp -r .theos/_/Applications/$(APPLICATION_NAME).app Payload/
	@chmod 755 Payload/$(APPLICATION_NAME).app/$(APPLICATION_NAME)
	@zip -rq $(APPLICATION_NAME).ipa Payload
	@rm -rf Payload
	@mkdir -p packages
	@mv $(APPLICATION_NAME).ipa packages/
	@echo "[*] Success: packages/$(APPLICATION_NAME).ipa"
