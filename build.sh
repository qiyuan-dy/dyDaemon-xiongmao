#!/bin/bash
# ============================================================================
# 熊猫平台 dyDaemon 一键编译脚本
# 使用方法：在 macOS 上安装 Theos 后，运行 ./build.sh
# ============================================================================

set -e

echo "============================================"
echo "  熊猫平台 dyDaemon 编译脚本"
echo "============================================"

# 检查 Theos
if [ -z "$THEOS" ]; then
    if [ -d "$(brew --prefix theos 2>/dev/null)" ]; then
        export THEOS="$(brew --prefix theos)"
    elif [ -d "/opt/theos" ]; then
        export THEOS="/opt/theos"
    elif [ -d "$HOME/theos" ]; then
        export THEOS="$HOME/theos"
    else
        echo "❌ 未找到 Theos，请先安装："
        echo "   brew install theos"
        echo "   或者参考：https://theos.dev/docs/installation-macos"
        exit 1
    fi
fi

echo "✅ Theos 路径: $THEOS"

# 检查 SDK
SDK_PATH="$THEOS/sdks"
if [ -d "$SDK_PATH" ]; then
    SDK_COUNT=$(ls -1 "$SDK_PATH"/*.sdk 2>/dev/null | wc -l)
    echo "✅ iOS SDK 数量: $SDK_COUNT"
else
    echo "⚠️  未找到 SDK 目录，将使用系统默认"
fi

# 编译
echo ""
echo "🚀 开始编译..."
echo ""

make clean
make package FINALPACKAGE=1

echo ""
echo "============================================"
echo "  ✅ 编译完成！"
echo "============================================"

# 找 deb 文件
DEB_FILE=$(ls -t *.deb 2>/dev/null | head -1)
if [ -n "$DEB_FILE" ]; then
    echo "📦 输出文件: $PWD/$DEB_FILE"
    echo "📦 文件大小: $(du -h "$DEB_FILE" | cut -f1)"
    
    # 显示包信息
    echo ""
    echo "📋 包信息:"
    dpkg-deb -I "$DEB_FILE" 2>/dev/null || echo "  (需要 dpkg 查看)"
fi

echo ""
echo "📲 安装到设备："
echo "   scp $DEB_FILE root@手机IP:/tmp/"
echo "   ssh root@手机IP"
echo "   dpkg -i /tmp/$DEB_FILE"
echo "   killall -9 Aweme  # 重启抖音"
