//
//  XMDaemonClient.h
//  dyDaemon - 熊猫平台版
//
//  Daemon API 客户端（CH1/CH2）
//  CH1: followUser3   — 需要 uid + sec_uid
//  CH2: followUserByLive2 — 只需 uid
//

#import <Foundation/Foundation.h>

@interface XMDaemonClient : NSObject

+ (instancetype)sharedInstance;

/// CH1: followUser3（需要 uid + sec_uid）
- (void)ch1_followUser:(NSString *)uid
                secUid:(NSString *)secUid
            completion:(void (^)(BOOL success, NSString *msg))completion;

/// CH2: followUserByLive2（需 uid，可选 sec_uid）
- (void)ch2_followUserByLive:(NSString *)uid
                      secUid:(NSString *)secUid
                  completion:(void (^)(BOOL success, NSString *msg))completion;

@end
