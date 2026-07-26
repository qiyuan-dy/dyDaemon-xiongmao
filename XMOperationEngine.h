//
//  XMOperationEngine.h
//  dyDaemon - 熊猫平台版
//
//  抖音操作引擎：直接 NSURLSession 发请求（绕过网络探测器）
//

#import <Foundation/Foundation.h>

@interface XMOperationEngine : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 账号信息
- (void)fetchCurrentUserInfo;

#pragma mark - 点赞
- (void)diggAweme:(NSString *)awemeId completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 关注（三个通道）
/// CH1: followUser3 风格 关注
- (void)followUserCh1:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion;
/// CH2: followUserByLive2 风格 关注
- (void)followUserCh2:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion;
/// CH3: 标准关注 API
- (void)followUser:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion;

#pragma mark - 收藏
- (void)collectAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion;

#pragma mark - 分享
- (void)shareAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion;

#pragma mark - 评论
- (void)commentAweme:(NSString *)awemeId content:(NSString *)content completion:(void (^)(BOOL, NSError *))completion;

#pragma mark - 播放
- (void)playAweme:(NSString *)awemeId duration:(NSInteger)duration completion:(void (^)(BOOL, NSError *))completion;

#pragma mark - 统计
@property (nonatomic, assign) NSInteger diggSuccessCount;
@property (nonatomic, assign) NSInteger followSuccessCount;
@property (nonatomic, assign) NSInteger collectSuccessCount;
@property (nonatomic, assign) NSInteger shareSuccessCount;
@property (nonatomic, assign) NSInteger commentSuccessCount;
@property (nonatomic, assign) NSInteger playSuccessCount;
@property (nonatomic, assign) NSInteger totalTaskCount;

@end
