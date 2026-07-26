//
//  XMFloatingView.h
//  dyDaemon - 熊猫平台版
//
//  悬浮窗控制面板
//

#import <UIKit/UIKit.h>

@interface XMFloatingView : UIView

+ (instancetype)sharedView;

/// 显示悬浮球
- (void)show;

/// 隐藏悬浮球
- (void)hide;

/// 更新统计显示
- (void)updateStats;

@end
