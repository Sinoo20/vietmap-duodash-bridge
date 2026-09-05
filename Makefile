TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME := rootless
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VietMapDuoDash

VietMapDuoDash_FILES = Tweak.x
VietMapDuoDash_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
