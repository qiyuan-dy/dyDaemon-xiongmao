ARCHS = arm64 arm64e
TARGET = iphone:clang:15.0:12.0
INSTALL_TARGET_PROCESSES = Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = dyDaemon-XiongMao

# 源文件列表
dyDaemon-XiongMao_FILES = Tweak.xm \
    XMGlobalManager.m \
    XMDNS2Client.m \
    XMDaemonClient.m \
    XMLogWindow.m \
    XMTaskService.m \
    XMOperationEngine.m \
    XMFloatingView.m \
    XMNetworkDetector.m

# 编译框架
dyDaemon-XiongMao_FRAMEWORKS = UIKit Foundation

# 私有库（按需添加）
# dyDaemon-XiongMao_PRIVATE_FRAMEWORKS =

# 其他链接标记
dyDaemon-XiongMao_LDFLAGS = -Wl,-undefined,dynamic_lookup

# 优化级别
dyDaemon-XiongMao_CFLAGS = -fobjc-arc -O2 -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
