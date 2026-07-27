//
//  XMGlobalManager.h
//  dyDaemon - 熊猫平台版
//
//  全局状态管理中心
//

#import <Foundation/Foundation.h>

@interface XMGlobalManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 设备标识
@property (nonatomic, copy) NSString *deviceTag;

#pragma mark - 数据源1: DNS2 数据库
@property (nonatomic, copy) NSString *dns2Host;
@property (nonatomic, assign) NSInteger dns2Port;
@property (nonatomic, copy) NSString *dns2ApiKey;
@property (nonatomic, assign) BOOL dns2Enabled;

#pragma mark - 数据源2: 熊猫平台
@property (nonatomic, assign) BOOL pandaEnabled;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *baseURL;

#pragma mark - 当前账号信息
@property (nonatomic, copy) NSString *currentUid;
@property (nonatomic, copy) NSString *currentSecUid;

#pragma mark - 关注三通道
@property (nonatomic, assign) BOOL followCH1Enabled;
@property (nonatomic, assign) NSInteger followCH1Target;
@property (nonatomic, assign) NSInteger followCH1Done;

@property (nonatomic, assign) BOOL followCH2Enabled;
@property (nonatomic, assign) NSInteger followCH2Target;
@property (nonatomic, assign) NSInteger followCH2Done;

@property (nonatomic, assign) BOOL followCH3Enabled;
@property (nonatomic, assign) NSInteger followCH3Target;
@property (nonatomic, assign) NSInteger followCH3Done;

#pragma mark - 其他任务开关
@property (nonatomic, assign) BOOL diggEnabled;
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

#pragma mark - 方法
- (void)startAllTasks;
- (void)stopAllTasks;
- (void)saveConfig;
- (void)loadConfig;

/// 便捷日志（广播通知 "XMLogMessage"）
+ (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end
