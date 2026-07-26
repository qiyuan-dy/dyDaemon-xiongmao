//
//  XMTaskService.h
//  dyDaemon - 熊猫平台版
//

#import <Foundation/Foundation.h>

@interface XMTaskService : NSObject

+ (instancetype)sharedInstance;

- (void)fetchTaskWithPlatform:(NSString *)platform
                         type:(NSString *)type
                   completion:(void (^)(NSString *taskId, NSDictionary *params, NSError *error))completion;

- (void)submitTaskWithPlatform:(NSString *)platform
                          type:(NSString *)type
                        taskId:(NSString *)taskId
                       success:(BOOL)success
                    completion:(void (^)(BOOL success, NSError *error))completion;

- (void)fetchLocalFollowTaskWithCompletion:(void (^)(NSString *uid, NSString *secUid, NSError *error))completion;
- (void)reportLocalFollowResultWithUid:(NSString *)uid success:(BOOL)success reason:(NSString *)reason completion:(void (^)(BOOL ok, NSError *error))completion;
- (void)startTaskLoop;
- (void)startLocalTaskLoop;
- (void)stopTaskLoop;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign) NSInteger consecutiveErrorCount;

@end
