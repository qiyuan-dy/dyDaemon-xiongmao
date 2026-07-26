//
//  XMGlobalManager.h
//  dyDaemon - 熊猫平台版
//
//  全局状态管理中心（替代原 uihdwBuqCIreudAT）
//

#import <Foundation/Foundation.h>

@class UIViewController;

@interface XMGlobalManager : NSObject

/// 单例
+ (instancetype)sharedInstance;

#pragma mark - 平台配置
/// 熊猫平台 API Key
@property (nonatomic, copy) NSString *apiKey;
/// 平台地址
@property (nonatomic, copy) NSString *baseURL;

#pragma mark - 本地服务器配置
/// 是否使用本地服务器（优先于熊猫平台）
@property (nonatomic, assign) BOOL useLocalServer;
/// 本地服务器地址
@property (nonatomic, copy) NSString *localServerURL;
/// 本地服务器 API Key
@property (nonatomic, copy) NSString *localApiKey;
/// 设备标识名
@property (nonatomic, copy) NSString *deviceName;

#pragma mark - 当前账号信息
/// 当前抖音号 UID
@property (nonatomic, copy) NSString *currentUid;
/// 当前抖音号 sec_uid
@property (nonatomic, copy) NSString *currentSecUid;

#pragma mark - 任务开关
/// 点赞任务开关
@property (nonatomic, assign) BOOL diggEnabled;
/// 关注任务开关
@property (nonatomic, assign) BOOL followEnabled;
/// 收藏任务开关
@property (nonatomic, assign) BOOL collectEnabled;
/// 分享任务开关
@property (nonatomic, assign) BOOL shareEnabled;
/// 评论任务开关
@property (nonatomic, assign) BOOL commentEnabled;
/// 播放任务开关
@property (nonatomic, assign) BOOL playEnabled;

#pragma mark - 任务参数
/// 最小间隔（秒）
@property (nonatomic, assign) NSInteger minInterval;
/// 最大间隔（秒）
@property (nonatomic, assign) NSInteger maxInterval;
/// 任务线程数
@property (nonatomic, assign) NSInteger threadCount;
/// 最大连续错误数
@property (nonatomic, assign) NSInteger maxErrorCount;

#pragma mark - 运行状态
/// 是否正在运行
@property (nonatomic, assign) BOOL isRunning;
/// 当前播放页控制器（弱引用）
@property (nonatomic, weak) UIViewController *playViewController;

#pragma mark - 方法
/// 启动所有任务
- (void)startAllTasks;
/// 停止所有任务
- (void)stopAllTasks;
/// 保存配置到本地
- (void)saveConfig;
/// 从本地加载配置
- (void)loadConfig;

@end
