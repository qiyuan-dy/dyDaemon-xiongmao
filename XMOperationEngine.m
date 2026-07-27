//
//  XMOperationEngine.m
//  dyDaemon - 熊猫平台版
//
//  抖音操作引擎实现（高级版）
//  方案：调用抖音内部 AWENetworkService 发请求，自动携带签名
//

#import "XMOperationEngine.h"
#import "XMGlobalManager.h"
#import "XMNetworkDetector.h"
#import "XMDaemonClient.h"
#import "XMDNS2Client.h"

// 抖音私有类声明
@interface AWEUserManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)currentUserID;
- (NSString *)currentSecUserID;
@end

@interface TTAccount : NSObject
+ (instancetype)sharedAccount;
- (NSString *)userID;
@end

// ============================================================================
// 抖音 API 接口地址（App 端）
// ============================================================================

static NSString * const kAwemeBaseURL = @"https://aweme.snssdk.com";

// 点赞接口
static NSString * const kAwemeDiggPath = @"/aweme/v1/commit/item/digg/";
// 关注接口
static NSString * const kAwemeFollowPath = @"/aweme/v1/commit/follow/user/";
// 收藏接口
static NSString * const kAwemeCollectPath = @"/aweme/v1/aweme/collect/";
// 播放统计接口
static NSString * const kAwemeStatsPath = @"/aweme/v1/aweme/stats/";
// 评论发布接口
static NSString * const kAwemeCommentPublishPath = @"/aweme/v1/comment/publish/";
// 用户资料接口
static NSString * const kAwemeUserProfilePath = @"/aweme/v1/user/profile/other/";

// 极速版前缀
static NSString * const kSicilyDiggPath = @"/sicily/v1/commit/item/digg/";
static NSString * const kSicilyFollowPath = @"/sicily/v1/commit/follow/user/";
static NSString * const kSicilyCollectPath = @"/sicily/v1/collect/";

@interface XMOperationEngine ()

/// 当前是否为极速版
@property (nonatomic, assign) BOOL isSicilyVersion;

@end

@implementation XMOperationEngine

+ (instancetype)sharedInstance {
    static XMOperationEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMOperationEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 检测是否为极速版
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        _isSicilyVersion = [bundleId containsString:@"lite"] || [bundleId containsString:@"sicily"];
        
        NSLog(@"[熊猫] 当前App: %@ (%@)", bundleId, _isSicilyVersion ? @"极速版" : @"主版");
        
        // 启动网络服务探测
        [[XMNetworkDetector sharedDetector] startDetection];
        
        // 监听任务执行通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onExecuteTask:)
                                                     name:@"XMExecuteTask"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 判断版本

- (NSString *)diggPath {
    return self.isSicilyVersion ? kSicilyDiggPath : kAwemeDiggPath;
}

- (NSString *)followPath {
    return self.isSicilyVersion ? kSicilyFollowPath : kAwemeFollowPath;
}

- (NSString *)collectPath {
    return self.isSicilyVersion ? kSicilyCollectPath : kAwemeCollectPath;
}

#pragma mark - 任务执行入口

- (void)onExecuteTask:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSString *taskId = userInfo[@"taskId"];
    NSDictionary *params = userInfo[@"params"];
    NSString *type = userInfo[@"type"];
    
    NSLog(@"[熊猫-操作引擎] 执行任务: %@ type=%@", taskId, type);
    
    __weak typeof(self) weakSelf = self;
    void (^submitBlock)(BOOL) = ^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (success) {
            strongSelf.totalTaskCount++;
            if ([type isEqualToString:@"dz"]) strongSelf.diggSuccessCount++;
            else if ([type hasPrefix:@"gz"]) strongSelf.followSuccessCount++;
            else if ([type isEqualToString:@"sc"]) strongSelf.collectSuccessCount++;
            else if ([type isEqualToString:@"fx"]) strongSelf.shareSuccessCount++;
            else if ([type isEqualToString:@"pl"]) strongSelf.commentSuccessCount++;
            else if ([type isEqualToString:@"bf"]) strongSelf.playSuccessCount++;
        }
        
        // 关注通道计数
        if (success) {
            XMGlobalManager *gm = [XMGlobalManager sharedInstance];
            if ([type isEqualToString:@"gz1"]) {
                gm.followCH1Done++;
                [XMGlobalManager log:@"🔵 CH1 ✅ (%ld/%ld) uid=%@", (long)gm.followCH1Done, (long)gm.followCH1Target, taskId];
                [gm checkCHTargetReached];
            } else if ([type isEqualToString:@"gz2"]) {
                gm.followCH2Done++;
                [XMGlobalManager log:@"🟢 CH2 ✅ (%ld/%ld) uid=%@", (long)gm.followCH2Done, (long)gm.followCH2Target, taskId];
                [gm checkCHTargetReached];
            } else if ([type isEqualToString:@"gz3"]) {
                gm.followCH3Done++;
                [XMGlobalManager log:@"🟡 CH3 ✅ (%ld/%ld) uid=%@", (long)gm.followCH3Done, (long)gm.followCH3Target, taskId];
                [gm checkCHTargetReached];
            }
        }
        
        // 上报结果到 DNS2
        [[XMDNS2Client sharedInstance] reportTask:taskId success:success reason:success ? @"ok" : @"failed" completion:nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStatsUpdated" object:nil];
    };
    
    // 根据类型执行对应操作
    NSString *awemeId = params[@"video_id"] ?: params[@"aweme_id"];
    NSString *secUid = params[@"sec_uid"];
    NSString *userId = params[@"uid"];
    
    if ([type isEqualToString:@"dz"]) {
        if (awemeId) {
            [self diggAweme:awemeId completion:^(BOOL success, NSError *error) {
                submitBlock(success);
            }];
        } else {
            NSLog(@"[熊猫] 点赞任务缺少 video_id");
            submitBlock(NO);
        }
    }
    else if ([type hasPrefix:@"gz"]) {
        if (secUid || userId) {
            // CH1/CH2/CH3 通道分配
            
            if ([type isEqualToString:@"gz1"]) {
                // CH1: daemon followUser3
                [[XMDaemonClient sharedInstance] ch1_followUser:userId secUid:secUid completion:^(BOOL s, NSString *msg) {
                    submitBlock(s);
                }];
            } else if ([type isEqualToString:@"gz2"]) {
                // CH2: daemon followUserByLive2（只需UID）
                [[XMDaemonClient sharedInstance] ch2_followUserByLive:userId completion:^(BOOL s, NSString *msg) {
                    submitBlock(s);
                }];
            } else {
                // CH3: 直连抖音 API
                [self followUser:userId secUid:secUid completion:^(BOOL s, NSError *error) {
                    submitBlock(s);
                }];
            }
        } else {
            [XMGlobalManager log:@"⚠️ 关注任务缺少 uid/sec_uid"];
            submitBlock(NO);
        }
    }
    else if ([type isEqualToString:@"sc"]) {
        if (awemeId) {
            [self collectAweme:awemeId completion:^(BOOL success, NSError *error) {
                submitBlock(success);
            }];
        } else {
            submitBlock(NO);
        }
    }
    else if ([type isEqualToString:@"fx"] || [type isEqualToString:@"fx2"]) {
        if (awemeId) {
            [self shareAweme:awemeId completion:^(BOOL success, NSError *error) {
                submitBlock(success);
            }];
        } else {
            submitBlock(NO);
        }
    }
    else if ([type isEqualToString:@"pl"] || [type isEqualToString:@"pl2"]) {
        if (awemeId) {
            NSString *content = params[@"content"] ?: @"666";
            [self commentAweme:awemeId content:content completion:^(BOOL success, NSError *error) {
                submitBlock(success);
            }];
        } else {
            submitBlock(NO);
        }
    }
    else if ([type isEqualToString:@"bf"] || [type isEqualToString:@"bf2"]) {
        if (awemeId) {
            NSInteger cnt = [params[@"cnt"] integerValue];
            if (cnt == 0) cnt = 1;
            [self playAweme:awemeId duration:cnt * 3 completion:^(BOOL success, NSError *error) {
                submitBlock(success);
            }];
        } else {
            submitBlock(NO);
        }
    }
    else {
        NSLog(@"[熊猫] 未知任务类型: %@", type);
        submitBlock(NO);
    }
}

#pragma mark - 获取当前用户信息

- (void)fetchCurrentUserInfo {
    NSLog(@"[熊猫] 获取当前用户信息...");
    
    // 方式1: 从 AWEUserManager 获取
    Class userManager = NSClassFromString(@"AWEUserManager");
    if (userManager && [userManager respondsToSelector:@selector(sharedManager)]) {
        id manager = [userManager sharedManager];
        
        if ([manager respondsToSelector:@selector(currentUserID)]) {
            NSString *uid = [manager currentUserID];
            if (uid) {
                [XMGlobalManager sharedInstance].currentUid = uid;
                NSLog(@"[熊猫] UID: %@", uid);
            }
        }
        
        if ([manager respondsToSelector:@selector(currentSecUserID)]) {
            NSString *secUid = [manager currentSecUserID];
            if (secUid) {
                [XMGlobalManager sharedInstance].currentSecUid = secUid;
                NSLog(@"[熊猫] SecUID: %@", secUid);
            }
        }
    }
    
    // 方式2: 从 TTAccount 获取
    if (![XMGlobalManager sharedInstance].currentUid) {
        Class ttAccount = NSClassFromString(@"TTAccount");
        if (ttAccount && [ttAccount respondsToSelector:@selector(sharedAccount)]) {
            id account = [ttAccount sharedAccount];
            if ([account respondsToSelector:@selector(userID)]) {
                NSString *uid = [account userID];
                if (uid) {
                    [XMGlobalManager sharedInstance].currentUid = uid;
                    NSLog(@"[熊猫] UID(TTAccount): %@", uid);
                }
            }
        }
    }
}

#pragma mark - 点赞
// 最新接口参数（2026年验证）:
// aweme_id / item_id: 视频ID
// item_type: 0(视频) 67(图文)
// type: 1(点赞) 0(取消点赞)

- (void)diggAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行点赞: aweme_id=%@", awemeId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"item_type"] = @"0";     // 0=视频 67=图文
    params[@"type"] = @"1";          // 1=点赞 0=取消
    params[@"channel_id"] = @"0";
    params[@"action_time"] = @([[NSDate date] timeIntervalSince1970]).stringValue;
    
    [self sendAwemeRequestWithPath:[self diggPath] params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 点赞失败: %@", error);
            if (completion) completion(NO, error);
            return;
        }
        
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        NSString *msg = response[@"status_msg"] ?: @"";
        
        NSLog(@"[熊猫] 点赞结果: %@ (code=%ld %@)", success ? @"成功" : @"失败", (long)statusCode, msg);
        
        if (completion) {
            completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: msg}]);
        }
    }];
}

#pragma mark - 关注
// 最新接口参数:
// user_id / sec_uid: 用户ID
// type: 1(关注) 0(取消关注)
// from: 来源标识
// from_type: 来源类型

- (void)followUser:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行关注: user_id=%@ sec_uid=%@", userId, secUid);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (userId) params[@"user_id"] = userId;
    if (secUid) params[@"sec_uid"] = secUid;
    params[@"type"] = @"1";          // 1=关注 0=取关
    params[@"from"] = @"0";
    params[@"from_type"] = @"0";
    params[@"from_pre"] = @"";
    params[@"from_action"] = @"0";
    
    [self sendAwemeRequestWithPath:[self followPath] params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 关注失败: %@", error);
            if (completion) completion(NO, error);
            return;
        }
        
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        NSString *msg = response[@"status_msg"] ?: @"";
        
        NSLog(@"[熊猫] 关注结果: %@ (code=%ld %@)", success ? @"成功" : @"失败", (long)statusCode, msg);
        
        if (completion) {
            completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: msg}]);
        }
    }];
}

#pragma mark - 收藏
// 最新接口参数:
// aweme_id / item_id: 视频ID
// collects_flag: 1(收藏) 0(取消收藏)

- (void)collectAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行收藏: aweme_id=%@", awemeId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"collects_flag"] = @"1";  // 1=收藏 0=取消
    
    [self sendAwemeRequestWithPath:[self collectPath] params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 收藏失败: %@", error);
            if (completion) completion(NO, error);
            return;
        }
        
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        NSString *msg = response[@"status_msg"] ?: @"";
        
        NSLog(@"[熊猫] 收藏结果: %@ (code=%ld %@)", success ? @"成功" : @"失败", (long)statusCode, msg);
        
        if (completion) {
            completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: msg}]);
        }
    }];
}

#pragma mark - 分享

- (void)shareAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行分享(模拟上报): aweme_id=%@", awemeId);
    
    // 分享操作实际是上报分享统计
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"share_type"] = @"0";
    params[@"platform"] = @"0";
    
    // 用 stats 接口模拟分享上报
    [self sendAwemeRequestWithPath:kAwemeStatsPath params:params completion:^(NSDictionary *response, NSError *error) {
        BOOL success = (error == nil);
        NSLog(@"[熊猫] 分享上报结果: %@", success ? @"成功" : @"失败");
        if (completion) completion(success, error);
    }];
}

#pragma mark - 评论

- (void)commentAweme:(NSString *)awemeId content:(NSString *)content completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行评论: aweme_id=%@ content=%@", awemeId, content);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"text"] = content;
    
    [self sendAwemeRequestWithPath:kAwemeCommentPublishPath params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 评论失败: %@", error);
            if (completion) completion(NO, error);
            return;
        }
        
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        NSString *msg = response[@"status_msg"] ?: @"";
        
        NSLog(@"[熊猫] 评论结果: %@ (code=%ld %@)", success ? @"成功" : @"失败", (long)statusCode, msg);
        
        if (completion) {
            completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: msg}]);
        }
    }];
}

#pragma mark - 播放

- (void)playAweme:(NSString *)awemeId duration:(NSInteger)duration completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行播放上报: aweme_id=%@ duration=%lds", awemeId, (long)duration);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"play_duration"] = @(duration).stringValue;
    params[@"play_type"] = @"0";
    params[@"is_pre_load"] = @"0";
    
    [self sendAwemeRequestWithPath:kAwemeStatsPath params:params completion:^(NSDictionary *response, NSError *error) {
        BOOL success = (error == nil);
        NSLog(@"[熊猫] 播放上报结果: %@", success ? @"成功" : @"失败");
        if (completion) completion(success, error);
    }];
}

#pragma mark - 核心：通过网络探测器发请求
// 自动适配不同抖音版本的网络服务类

- (void)sendAwemeRequestWithPath:(NSString *)path params:(NSDictionary *)params completion:(void (^)(NSDictionary *, NSError *))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@%@", kAwemeBaseURL, path];
    
    // 使用探测器发送请求（自动选择最优方案）
    [[XMNetworkDetector sharedDetector] sendPOSTRequestWithURL:urlStr
                                                    parameters:params
                                                    completion:completion];
}

#pragma mark - 兜底请求方案（不推荐，缺少签名）

- (void)sendFallbackRequestWithPath:(NSString *)path params:(NSDictionary *)params completion:(void (^)(NSDictionary *, NSError *))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@%@", kAwemeBaseURL, path];
    
    NSMutableArray *paramPairs = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *pair = [NSString stringWithFormat:@"%@=%@", key, obj];
        [paramPairs addObject:pair];
    }];
    NSString *bodyStr = [paramPairs componentsJoinedByString:@"&"];
    NSData *bodyData = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(json, nil);
        } else {
            if (completion) completion(nil, [NSError errorWithDomain:@"XMOperation" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

@end
