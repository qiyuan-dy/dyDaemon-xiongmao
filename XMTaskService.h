//
//  XMTaskService.h
//  dyDaemon - 熊猫平台版 v2.0
//
//  任务调度服务：拉取任务 → 通过 daemon/直连执行
//

#import <Foundation/Foundation.h>

@interface XMTaskService : NSObject

+ (instancetype)sharedInstance;

/// 开始任务循环
- (void)startTaskLoop;
/// 停止任务循环
- (void)stopTaskLoop;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign) NSInteger consecutiveErrorCount;

@end
