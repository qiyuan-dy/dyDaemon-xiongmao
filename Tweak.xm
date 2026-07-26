//
//  Tweak.xm
//  dyDaemon - 熊猫平台版 v2.0
//
//  UI dylib + daemon API 调用
//  CH1/CH2 → daemon :12933
//  CH3    → 直连抖音 API
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "XMGlobalManager.h"
#import "XMTaskService.h"
#import "XMDaemonClient.h"
#import "XMFloatingView.h"

// ============================================================================
// 抖音关键类声明
// ============================================================================

@class AppDelegate;
@class AWETabBarController;
@class AWEDetailViewController;

@interface AWEUserManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)currentUserID;
- (NSString *)currentSecUserID;
@end

// ============================================================================
// 构建函数
// ============================================================================

static void updateCurrentUserInfo(void);

static void __attribute__((constructor)) initialize() {
    NSLog(@"[熊猫] dyDaemon v2.0 已加载 (daemon API 模式)");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[熊猫] 开始初始化 v2.0...");
        
        [XMGlobalManager sharedInstance];
        [XMTaskService sharedInstance];
        [XMDaemonClient sharedClient];
        [[XMFloatingView sharedView] show];
        
        updateCurrentUserInfo();
        
        NSLog(@"[熊猫] v2.0 初始化完成");
    });
}

static void updateCurrentUserInfo() {
    Class userManagerClass = NSClassFromString(@"AWEUserManager");
    if (userManagerClass) {
        id userManager = [userManagerClass sharedManager];
        if ([userManager respondsToSelector:@selector(currentUserID)]) {
            NSString *uid = [userManager currentUserID];
            if (uid) {
                [XMGlobalManager sharedInstance].currentUid = uid;
                NSLog(@"[熊猫] UID: %@", uid);
            }
        }
        if ([userManager respondsToSelector:@selector(currentSecUserID)]) {
            NSString *secUid = [userManager currentSecUserID];
            if (secUid) {
                [XMGlobalManager sharedInstance].currentSecUid = secUid;
                NSLog(@"[熊猫] SecUID: %@", secUid);
            }
        }
    }
}

// ============================================================================
// Hook: AppDelegate
// ============================================================================

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[XMFloatingView sharedView] show];
        updateCurrentUserInfo();
    });
    return result;
}

%end

// ============================================================================
// Hook: 用户登录/登出
// ============================================================================

%hook AWEUserManager

- (void)userDidLogin {
    %orig;
    NSLog(@"[熊猫] 检测到用户登录");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        updateCurrentUserInfo();
    });
}

- (void)userDidLogout {
    %orig;
    NSLog(@"[熊猫] 检测到用户登出");
    [XMGlobalManager sharedInstance].currentUid = nil;
    [XMGlobalManager sharedInstance].currentSecUid = nil;
    [[XMGlobalManager sharedInstance] stopAllTasks];
}

%end

// ============================================================================
// Hook: TabBarController — 保持悬浮窗在最前
// ============================================================================

%hook AWETabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[XMFloatingView sharedView] show];
}

%end

// ============================================================================
// Hook: 视频详情页
// ============================================================================

%hook AWEDetailViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [XMGlobalManager sharedInstance].playViewController = (UIViewController *)self;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if ([XMGlobalManager sharedInstance].playViewController == (UIViewController *)self) {
        [XMGlobalManager sharedInstance].playViewController = nil;
    }
}

%end

// ============================================================================
// Hook: 窗口
// ============================================================================

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow && ![XMFloatingView sharedView].superview) {
                [keyWindow addSubview:[XMFloatingView sharedView]];
            }
        });
    });
}

%end
