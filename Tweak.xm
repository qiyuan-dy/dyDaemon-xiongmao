//
//  Tweak.xm
//  dyDaemon - 熊猫平台版
//
//  主入口文件：初始化 + 关键方法 Hook
//  使用 Logos 语法编写
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "XMGlobalManager.h"
#import "XMTaskService.h"
#import "XMOperationEngine.h"
#import "XMFloatingView.h"

// ============================================================================
// 抖音关键类声明（Hook 用）
// ============================================================================

@interface AWEUserManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)currentUserID;
- (NSString *)currentSecUserID;
@end

@interface AWENetworkConfiguration : NSObject
+ (instancetype)sharedInstance;
- (NSDictionary *)commonParameters;
@end

// ============================================================================
// 初始化构造器
// ============================================================================

static void __attribute__((constructor)) initialize() {
    NSLog(@"[熊猫] dyDaemon 熊猫平台版 已加载");
    NSLog(@"[熊猫] 版本: 1.0.0");
    
    // 延迟初始化，等 App 启动完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[熊猫] 开始初始化...");
        
        // 初始化全局管理器
        [XMGlobalManager sharedInstance];
        
        // 初始化任务服务
        [XMTaskService sharedInstance];
        
        // 初始化操作引擎
        [XMOperationEngine sharedInstance];
        
        // 创建悬浮窗
        [[XMFloatingView sharedView] show];
        
        // 尝试获取当前用户信息
        updateCurrentUserInfo();
        
        NSLog(@"[熊猫] 初始化完成");
    });
}

// ============================================================================
// 更新当前用户信息
// ============================================================================

static void updateCurrentUserInfo() {
    // 尝试通过 AWEUserManager 获取当前用户信息
    Class userManagerClass = NSClassFromString(@"AWEUserManager");
    if (userManagerClass) {
        id userManager = [userManagerClass sharedManager];
        if ([userManager respondsToSelector:@selector(currentUserID)]) {
            NSString *uid = [userManager currentUserID];
            if (uid) {
                [XMGlobalManager sharedInstance].currentUid = uid;
                NSLog(@"[熊猫] 获取到 UID: %@", uid);
            }
        }
        if ([userManager respondsToSelector:@selector(currentSecUserID)]) {
            NSString *secUid = [userManager currentSecUserID];
            if (secUid) {
                [XMGlobalManager sharedInstance].currentSecUid = secUid;
                NSLog(@"[熊猫] 获取到 SecUID: %@", secUid);
            }
        }
    }
}

// ============================================================================
// Hook 点：AppDelegate 启动完成后显示悬浮窗
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
// Hook 点：用户登录状态变化时更新信息
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
    
    // 自动停止任务
    [[XMGlobalManager sharedInstance] stopAllTasks];
}

%end

// ============================================================================
// Hook 点：拦截抖音网络请求（获取签名参数示例）
// ============================================================================
// 如果需要直接调用抖音内部 API，需要获取正确的签名头
// 这里提供 Hook 点示例，实际使用时按需开启

/*
%hook TTNetworkManager

+ (instancetype)sharedManager {
    return %orig;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                       headers:(NSDictionary *)headers
                      progress:(void *)uploadProgress
                       success:(void *)success
                       failure:(void *)failure {
    // 可以在这里拦截请求，获取签名头等信息
    // NSLog(@"[熊猫-网络] POST: %@", URLString);
    return %orig;
}

%end
*/

// ============================================================================
// Hook 点：视频播放页（可用于判断是否在播放页）
// ============================================================================

%hook AWETabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 确保悬浮窗在最前面
    [[XMFloatingView sharedView] show];
}

%end

// ============================================================================
// Hook 点：视频详情页出现时记录
// ============================================================================

%hook AWEDetailViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 记录当前在播放页
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
// 备用：如果上面的类名不对，用通用方式 Hook 窗口
// ============================================================================

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 将悬浮窗添加到 keyWindow
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow && ![XMFloatingView sharedView].superview) {
                [keyWindow addSubview:[XMFloatingView sharedView]];
            }
        });
    });
}

%end
