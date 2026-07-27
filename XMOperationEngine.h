//
//  XMOperationEngine.h
//  dyDaemon - 熊猫平台版
//
//  抖音操作引擎（执行点赞/关注/收藏等操作）
//  核心思路：通过 Hook 抖音原生方法，调用其内部接口
//

#import <Foundation/Foundation.h>

@interface XMOperationEngine : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 账号信息
/// 获取当前登录用户的 uid 和 sec_uid
- (void)fetchCurrentUserInfo;

#pragma mark - 点赞操作
/// 点赞视频
/// @param awemeId 视频ID
/// @param completion 回调
- (void)diggAweme:(NSString *)awemeId completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 关注操作
/// 关注用户
/// @param userId 用户ID
/// @param secUid 秒级UID
/// @param completion 回调
- (void)followUser:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 收藏操作
/// 收藏视频
/// @param awemeId 视频ID
/// @param completion 回调
- (void)collectAweme:(NSString *)awemeId completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 分享操作
/// 分享视频（模拟）
/// @param awemeId 视频ID
/// @param completion 回调
- (void)shareAweme:(NSString *)awemeId completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 评论操作
/// 评论视频
/// @param awemeId 视频ID
/// @param content 评论内容
/// @param completion 回调
- (void)commentAweme:(NSString *)awemeId content:(NSString *)content completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 播放操作
/// 播放视频（模拟播放时长）
/// @param awemeId 视频ID
/// @param duration 播放时长（秒）
/// @param completion 回调
- (void)playAweme:(NSString *)awemeId duration:(NSInteger)duration completion:(void (^)(BOOL success, NSError *error))completion;

#pragma mark - 统计
/// 总点赞成功数
@property (nonatomic, assign) NSInteger diggSuccessCount;
/// 总关注成功数
@property (nonatomic, assign) NSInteger followSuccessCount;
/// 总收藏成功数
@property (nonatomic, assign) NSInteger collectSuccessCount;
/// 总分享成功数
@property (nonatomic, assign) NSInteger shareSuccessCount;
/// 总评论成功数
@property (nonatomic, assign) NSInteger commentSuccessCount;
/// 总播放成功数
@property (nonatomic, assign) NSInteger playSuccessCount;
/// 总任务数
@property (nonatomic, assign) NSInteger totalTaskCount;

@end
