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

/// 启动任务循环
- (void)startTaskLoop;

/// 停止任务循环
- (void)stopTaskLoop;

/// 当前是否正在运行
@property (nonatomic, assign, readonly) BOOL isRunning;

/// 当前连续错误次数
@property (nonatomic, assign) NSInteger consecutiveErrorCount;

@end
