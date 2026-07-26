//
//  XMTaskService.h
//  dyDaemon - 熊猫平台版
//
//  任务调度服务（对接熊猫平台 API）
//

#import <Foundation/Foundation.h>

@interface XMTaskService : NSObject

/// 单例
+ (instancetype)sharedInstance;

/// 拉取任务
/// @param platform 平台类型 dy/ks/wx/tk/tt
/// @param type 业务类型 dz/gz/sc/fx/pl/bf
/// @param completion 回调 (taskId, params, error)
- (void)fetchTaskWithPlatform:(NSString *)platform
                         type:(NSString *)type
                   completion:(void (^)(NSString *taskId, NSDictionary *params, NSError *error))completion;

/// 提交任务结果
/// @param platform 平台类型
/// @param type 业务类型
/// @param taskId 任务ID (studiotask_id)
/// @param success 是否成功
/// @param completion 回调
- (void)submitTaskWithPlatform:(NSString *)platform
                          type:(NSString *)type
                        taskId:(NSString *)taskId
                       success:(BOOL)success
                    completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 本地服务器模式
/// 从本地服务器拉取关注任务
- (void)fetchLocalFollowTaskWithCompletion:(void (^)(NSString *uid, NSString *secUid, NSError *error))completion;

/// 向本地服务器上报关注结果
- (void)reportLocalFollowResultWithUid:(NSString *)uid success:(BOOL)success reason:(NSString *)reason completion:(void (^)(BOOL ok, NSError *error))completion;

/// 启动任务循环
- (void)startTaskLoop;

/// 停止任务循环
- (void)stopTaskLoop;

/// 当前是否正在运行
@property (nonatomic, assign, readonly) BOOL isRunning;

/// 当前连续错误次数
@property (nonatomic, assign) NSInteger consecutiveErrorCount;

@end
