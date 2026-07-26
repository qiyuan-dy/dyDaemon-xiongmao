//
//  XMDaemonClient.h
//  dyDaemon - 熊猫平台版 v2.0
//
//  HTTP 客户端：调用本地 daemon (:12933 业务 / :10010 配置)
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^XMDaemonCallback)(BOOL success, NSDictionary * _Nullable result, NSString * _Nullable error);

@interface XMDaemonClient : NSObject

+ (instancetype)sharedClient;

#pragma mark - 业务操作 (daemon :12933)

/// CH1 关注 - followUser3 风格 (channel_id=13)
- (void)followUserCh1:(NSString *)userId
               secUid:(NSString *)secUid
           completion:(XMDaemonCallback)completion;

/// CH2 关注 - followUserByLive2 风格
- (void)followUserCh2:(NSString *)userId
               secUid:(NSString *)secUid
           completion:(XMDaemonCallback)completion;

/// 点赞
- (void)digg:(NSString *)awemeId
  completion:(XMDaemonCallback)completion;

/// 查询用户信息
- (void)otherUser:(NSString *)userId
           secUid:(NSString *)secUid
       completion:(XMDaemonCallback)completion;

#pragma mark - 配置读写 (daemon :10010)

/// 获取配置值
- (void)getConfigValue:(NSString *)key
            completion:(void(^)(NSString * _Nullable value))completion;

/// 设置字符串配置
- (void)setConfigValue:(NSString *)key
            stringValue:(NSString *)value
             completion:(nullable void(^)(BOOL ok))completion;

/// 设置整数配置
- (void)setConfigValue:(NSString *)key
              intValue:(NSInteger)value
            completion:(nullable void(^)(BOOL ok))completion;

/// 同步配置
- (void)syncConfig:(nullable void(^)(BOOL ok))completion;

@end

NS_ASSUME_NONNULL_END
