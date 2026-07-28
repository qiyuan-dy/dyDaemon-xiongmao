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
#import "XMDNS2Client.h"
#import "XMLogWindow.h"
#import "XMDaemonClient.h"

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
// 前向声明
// ============================================================================

static void updateCurrentUserInfo(void);

// ============================================================================
// 初始化构造器
// ============================================================================

static void __attribute__((constructor)) initialize() {
    NSLog(@"[熊猫] dyDaemon 熊猫平台版 已加载");
    NSLog(@"[熊猫] 版本: 2.1.0");
    
    // 延迟初始化，等 App 启动完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[熊猫] 开始初始化...");
        
        // 初始化全局管理器
        [XMGlobalManager sharedInstance];
        
        // 初始化 DNS2 客户端
        [XMDNS2Client sharedInstance];
        
        // 初始化 daemon 客户端
        [XMDaemonClient sharedInstance];
        
        // 初始化任务服务
        [XMTaskService sharedInstance];
        
        // 初始化操作引擎
        [XMOperationEngine sharedInstance];
        
        // 创建日志窗口（头顶，穿透）
        UIWindow *kw = [UIApplication sharedApplication].keyWindow;
        if (kw && ![XMLogWindow sharedWindow].superview) {
            [kw addSubview:[XMLogWindow sharedWindow]];
        }
        
        // 创建悬浮窗
        [[XMFloatingView sharedView] show];
        
        // 尝试获取当前用户信息
        updateCurrentUserInfo();
        
        // 自动启动任务引擎（延迟确保 daemon 就绪）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            XMGlobalManager *gm = [XMGlobalManager sharedInstance];
            if (gm.dns2Enabled) {
                NSLog(@"[熊猫] 自动启动: DNS2=%d CH1=%d CH2=%d CH3=%d",
                      gm.dns2Enabled, gm.followCH1Enabled, gm.followCH2Enabled, gm.followCH3Enabled);
                [gm startAllTasks];
            }
        });
        
        NSLog(@"[熊猫] 初始化完成");
    });
}

// ============================================================================
// 更新当前用户信息（多方案降级查找）
// ============================================================================

static void updateCurrentUserInfo() {
    NSLog(@"[熊猫] === 开始获取账号信息 ===");
    
    NSArray *classNames = @[
        @"AWEUserManager",
        @"IESUserModel",
        @"AWELoginManager",
        @"TTAccount"
    ];
    NSArray *uidSels = @[@"currentUserID", @"userID", @"uid", @"currentUserId"];
    NSArray *secSels  = @[@"currentSecUserID", @"secUserID", @"secUid"];
    NSArray *sharedSels = @[@"sharedManager", @"sharedInstance", @"sharedAccount", @"sharedModel"];
    
    for (NSString *cn in classNames) {
        Class cls = NSClassFromString(cn);
        if (!cls) { NSLog(@"[熊猫] 类 %@ 不存在", cn); continue; }
        NSLog(@"[熊猫] 找到类: %@", cn);
        
        id inst = nil;
        for (NSString *sn in sharedSels) {
            SEL sel = NSSelectorFromString(sn);
            if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                inst = [cls performSelector:sel];
#pragma clang diagnostic pop
                if (inst) { NSLog(@"[熊猫] %@.%@ 获取实例成功", cn, sn); break; }
            }
        }
        if (!inst) continue;
        
        for (NSString *sn in uidSels) {
            SEL sel = NSSelectorFromString(sn);
            if ([inst respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                NSString *v = [inst performSelector:sel];
#pragma clang diagnostic pop
                if (v && [v isKindOfClass:[NSString class]] && v.length > 0) {
                    [XMGlobalManager sharedInstance].currentUid = v;
                    NSLog(@"[熊猫] ✅ UID(%@.%@) = %@", cn, sn, v);
                    break;
                }
            }
        }
        for (NSString *sn in secSels) {
            SEL sel = NSSelectorFromString(sn);
            if ([inst respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                NSString *v = [inst performSelector:sel];
#pragma clang diagnostic pop
                if (v && [v isKindOfClass:[NSString class]] && v.length > 0) {
                    [XMGlobalManager sharedInstance].currentSecUid = v;
                    NSLog(@"[熊猫] ✅ SecUID(%@.%@) = %@", cn, sn, v);
                    break;
                }
            }
        }
        if ([XMGlobalManager sharedInstance].currentUid) break;
    }
    
    // 降级: NSUserDefaults
    if (![XMGlobalManager sharedInstance].currentUid) {
        NSLog(@"[熊猫] 类查找全失败, 尝试 UserDefaults...");
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        for (NSString *k in @[@"uid", @"user_id", @"current_uid", @"aweme_uid"]) {
            NSString *v = [ud stringForKey:k];
            if (v.length > 5) {
                [XMGlobalManager sharedInstance].currentUid = v;
                NSLog(@"[熊猫] ✅ UID(UserDefaults[%@]) = %@", k, v);
                break;
            }
        }
    }
    
    NSLog(@"[熊猫] 账号信息结果: UID=%@ SecUID=%@",
          [XMGlobalManager sharedInstance].currentUid ?: @"(nil)",
          [XMGlobalManager sharedInstance].currentSecUid ?: @"(nil)");
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
            if (keyWindow && ![XMLogWindow sharedWindow].superview) {
                [keyWindow addSubview:[XMLogWindow sharedWindow]];
            }
        });
    });
}

%end
