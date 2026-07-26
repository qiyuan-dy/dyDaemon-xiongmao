//
//  XMGlobalManager.h
//  dyDaemon - 熊猫平台版
//
//  全局状态管理中心
//

#import <Foundation/Foundation.h>

@class UIViewController;

@interface XMGlobalManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 平台配置
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *baseURL;

#pragma mark - 本地服务器配置
@property (nonatomic, assign) BOOL useLocalServer;
@property (nonatomic, copy) NSString *localServerURL;
@property (nonatomic, copy) NSString *localApiKey;
@property (nonatomic, copy) NSString *deviceName;

#pragma mark - 当前账号信息
@property (nonatomic, copy) NSString *currentUid;
@property (nonatomic, copy) NSString *currentSecUid;

#pragma mark - 关注通道开关（本地模式）
/// CH1: followUser3 通道
@property (nonatomic, assign) BOOL followCh1Enabled;
/// CH2: followUserByLive2 通道
@property (nonatomic, assign) BOOL followCh2Enabled;
/// CH3: 标准关注 API 通道
@property (nonatomic, assign) BOOL followCh3Enabled;

#pragma mark - 任务开关（熊猫平台模式）
@property (nonatomic, assign) BOOL diggEnabled;
@property (nonatomic, assign) BOOL followEnabled;
@property (nonatomic, assign) BOOL collectEnabled;
@property (nonatomic, assign) BOOL shareEnabled;
@property (nonatomic, assign) BOOL commentEnabled;
@property (nonatomic, assign) BOOL playEnabled;

#pragma mark - 任务参数
@property (nonatomic, assign) NSInteger minInterval;
@property (nonatomic, assign) NSInteger maxInterval;
@property (nonatomic, assign) NSInteger threadCount;
@property (nonatomic, assign) NSInteger maxErrorCount;

#pragma mark - 运行状态
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, weak) UIViewController *playViewController;

- (void)startAllTasks;
- (void)stopAllTasks;
- (void)saveConfig;
- (void)loadConfig;

@end
