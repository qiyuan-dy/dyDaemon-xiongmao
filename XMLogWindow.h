//
//  XMLogWindow.h
//  dyDaemon - 熊猫平台版
//
//  屏幕顶部日志悬浮框 — 点击穿透，不挡抖音操作
//

#import <UIKit/UIKit.h>

@interface XMLogWindow : UIView

+ (instancetype)sharedWindow;

/// 添加日志
- (void)addLog:(NSString *)text;

/// 显示
- (void)show;

/// 隐藏
- (void)hide;

@end
