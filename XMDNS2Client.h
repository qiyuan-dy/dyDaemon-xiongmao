//
//  XMDNS2Client.h
//  dyDaemon - 熊猫平台版
//
//  DNS2 关注数据库客户端
//  从 dns2:8081 拉取关注目标 + 上报结果
//

#import <Foundation/Foundation.h>

@interface XMDNS2Client : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 获取任务

/// 从 DNS2 数据库拉取待关注目标
/// @param count 请求数量
/// @param completion 回调（code=406 表示无任务）
- (void)fetchTasks:(NSInteger)count
        completion:(void (^)(NSArray<NSDictionary *> *targets, NSInteger code, NSString *msg))completion;

#pragma mark - 上报结果

/// 上报关注结果
/// @param uid 目标 UID
/// @param success 是否成功
/// @param reason 失败原因
/// @param completion 回调
- (void)reportTask:(NSString *)uid
           success:(BOOL)success
            reason:(NSString *)reason
        completion:(void (^)(BOOL ok))completion;

@end
