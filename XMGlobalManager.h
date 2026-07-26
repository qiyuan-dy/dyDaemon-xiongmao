//
//  XMGlobalManager.h
//  dyDaemon - 熊猫平台版 v2.0
//
//  全局配置与状态管理中心
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIViewController;

#define XM_VERSION @"2.0.0"

@interface XMGlobalManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 本地服务器配置（任务拉取）
@property (nonatomic, assign) BOOL useLocalServer;
@property (nonatomic, copy) NSString *localServerURL;
@property (nonatomic, copy) NSString *localApiKey;
@property (nonatomic, copy) NSString *deviceName;

#pragma mark - 当前账号信息
@property (nonatomic, copy, nullable) NSString *currentUid;
@property (nonatomic, copy, nullable) NSString *currentSecUid;

#pragma mark - 关注通道开关
@property (nonatomic, assign) BOOL followCh1Enabled;  // daemon followUser3
@property (nonatomic, assign) BOOL followCh2Enabled;  // daemon followUserByLive2
@property (nonatomic, assign) BOOL followCh3Enabled;  // 直连标准API

#pragma mark - 任务开关
@property (nonatomic, assign) BOOL diggEnabled;
@property (nonatomic, assign) BOOL followEnabled;
@property (nonatomic, assign) BOOL collectEnabled;
@property (nonatomic, assign) BOOL shareEnabled;
@property (nonatomic, assign) BOOL commentEnabled;
@property (nonatomic, assign) BOOL playEnabled;

#pragma mark - 任务参数
@property (nonatomic, assign) NSInteger minInterval;
@property (nonatomic, assign) NSInteger maxInterval;
@property (nonatomic, assign) NSInteger maxErrorCount;

#pragma mark - 运行状态
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, weak, nullable) UIViewController *playViewController;

#pragma mark - 操作
- (void)startAllTasks;
- (void)stopAllTasks;
- (void)saveConfig;
- (void)loadConfig;

@end

NS_ASSUME_NONNULL_END
