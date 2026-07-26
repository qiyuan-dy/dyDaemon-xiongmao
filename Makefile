ARCHS = arm64 arm64e
TARGET = iphone:clang:15.0:12.0
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = dyDaemon-XiongMao

# v2.0: daemon API 模式
dyDaemon-XiongMao_FILES = Tweak.xm \
    XMGlobalManager.m \
    XMTaskService.m \
    XMDaemonClient.m \
    XMFloatingView.m

dyDaemon-XiongMao_FRAMEWORKS = UIKit Foundation

dyDaemon-XiongMao_LDFLAGS = -Wl,-undefined,dynamic_lookup

dyDaemon-XiongMao_CFLAGS = -fobjc-arc -O2 -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
