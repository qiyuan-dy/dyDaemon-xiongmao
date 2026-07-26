//
//  XMOperationEngine.m
//  dyDaemon - 熊猫平台版
//
//  抖音操作引擎：直接 NSURLSession 发请求
//  本地服务器模式下绕过网络探测器，已验证 API 无需签名即可返回 status_code:0
//

#import "XMOperationEngine.h"
#import "XMGlobalManager.h"
#import "XMTaskService.h"
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wobjc-method-access"

static NSString * const kAwemeBaseURL = @"https://aweme.snssdk.com";
static NSString * const kAwemeDiggPath = @"/aweme/v1/commit/item/digg/";
static NSString * const kAwemeFollowPath = @"/aweme/v1/commit/follow/user/";
static NSString * const kAwemeCollectPath = @"/aweme/v1/aweme/collect/";
static NSString * const kAwemeStatsPath = @"/aweme/v1/aweme/stats/";
static NSString * const kAwemeCommentPublishPath = @"/aweme/v1/comment/publish/";

@interface XMOperationEngine ()
@property (nonatomic, assign) BOOL isSicilyVersion;
@property (nonatomic, assign) NSInteger currentChannel; // 当前使用的关注通道 1/2/3
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
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        _isSicilyVersion = [bundleId containsString:@"lite"] || [bundleId containsString:@"sicily"];
        _currentChannel = 1;
        NSLog(@"[熊猫] 当前App: %@ (%@)", bundleId, _isSicilyVersion ? @"极速版" : @"主版");
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onExecuteTask:)
                                                     name:@"XMExecuteTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLocalFollowTask:)
                                                     name:@"XMLocalFollowTask" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 获取下一个要用的通道

- (NSInteger)nextFollowChannel {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    // 轮转：找到下一个启用的通道
    for (NSInteger i = 0; i < 3; i++) {
        _currentChannel = (_currentChannel % 3) + 1;
        if (_currentChannel == 1 && gm.followCh1Enabled) return 1;
        if (_currentChannel == 2 && gm.followCh2Enabled) return 2;
        if (_currentChannel == 3 && gm.followCh3Enabled) return 3;
    }
    return 0; // 全部未启用
}

#pragma mark - 本地关注任务（多通道轮转）

- (void)onLocalFollowTask:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSString *uid = userInfo[@"uid"];
    NSString *secUid = userInfo[@"sec_uid"];
    NSInteger channel = [userInfo[@"channel"] integerValue];
    
    NSLog(@"[操作引擎] 本地关注任务: uid=%@ channel=%ld", uid, (long)channel);
    
    if (!uid) {
        NSLog(@"[操作引擎] 本地任务缺少uid");
        // 继续下一个任务
        [self scheduleNextLocalTask];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    void (^doneBlock)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (success) {
            strongSelf.totalTaskCount++;
            strongSelf.followSuccessCount++;
        }
        
        // 上报结果到 dns2
        Class taskService = NSClassFromString(@"XMTaskService");
        if (taskService && [taskService respondsToSelector:@selector(sharedInstance)]) {
            id service = [taskService sharedInstance];
            if ([service respondsToSelector:@selector(reportLocalFollowResultWithUid:success:reason:completion:)]) {
                NSString *reason = error ? error.localizedDescription : @"";
                [service reportLocalFollowResultWithUid:uid success:success reason:reason completion:nil];
            }
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStatsUpdated" object:nil];
        [strongSelf scheduleNextLocalTask];
    };
    
    // 根据通道执行
    switch (channel) {
        case 1:
            [self followUserCh1:uid secUid:secUid completion:doneBlock];
            break;
        case 2:
            [self followUserCh2:uid secUid:secUid completion:doneBlock];
            break;
        case 3:
        default:
            [self followUser:uid secUid:secUid completion:doneBlock];
            break;
    }
}

- (void)scheduleNextLocalTask {
    if (![XMGlobalManager sharedInstance].isRunning) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        Class taskService = NSClassFromString(@"XMTaskService");
        if (taskService && [taskService respondsToSelector:@selector(sharedInstance)]) {
            id service = [taskService sharedInstance];
            if ([service respondsToSelector:@selector(startLocalTaskLoop)]) {
                [service startLocalTaskLoop];
            }
        }
    });
}

#pragma mark - 关注通道 1: followUser3 风格
// 对应旧版 /followUser3?user_id=xxx&sec_id=yyy&channel=13

- (void)followUserCh1:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫-CH1] followUser3 风格: user_id=%@", userId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (userId) params[@"user_id"] = userId;
    if (secUid && secUid.length > 0) params[@"sec_uid"] = secUid;
    params[@"type"] = @"1";
    params[@"channel_id"] = @"13";  // CH1 特有
    params[@"from"] = @"0";
    params[@"from_pre"] = @"";
    params[@"from_action"] = @"0";
    
    [self sendDirectRequest:[self followPath] params:params completion:^(NSDictionary *response, NSError *error) {
        [self handleFollowResponse:response error:error channel:@"CH1" completion:completion];
    }];
}

#pragma mark - 关注通道 2: followUserByLive2 风格
// 对应旧版 /followUserByLive2?user_id=xxx&sec_id=yyy

- (void)followUserCh2:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫-CH2] followUserByLive2 风格: user_id=%@", userId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (userId) params[@"user_id"] = userId;
    if (secUid && secUid.length > 0) params[@"sec_uid"] = secUid;
    params[@"type"] = @"1";
    params[@"from"] = @"0";         // CH2 特有简洁参数
    params[@"from_pre"] = @"";
    
    [self sendDirectRequest:[self followPath] params:params completion:^(NSDictionary *response, NSError *error) {
        [self handleFollowResponse:response error:error channel:@"CH2" completion:completion];
    }];
}

#pragma mark - 关注通道 3: 标准 API
- (void)followUser:(NSString *)userId secUid:(NSString *)secUid completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫-CH3] 标准关注: user_id=%@", userId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (userId) params[@"user_id"] = userId;
    if (secUid && secUid.length > 0) params[@"sec_uid"] = secUid;
    params[@"type"] = @"1";
    params[@"from"] = @"0";
    params[@"from_type"] = @"0";
    params[@"from_pre"] = @"";
    params[@"from_action"] = @"0";
    
    [self sendDirectRequest:[self followPath] params:params completion:^(NSDictionary *response, NSError *error) {
        [self handleFollowResponse:response error:error channel:@"CH3" completion:completion];
    }];
}

- (void)handleFollowResponse:(NSDictionary *)response error:(NSError *)error channel:(NSString *)channel completion:(void (^)(BOOL, NSError *))completion {
    if (error) {
        NSLog(@"[熊猫-%@] 关注失败: %@", channel, error);
        if (completion) completion(NO, error);
        return;
    }
    
    NSInteger statusCode = [response[@"status_code"] integerValue];
    BOOL success = (statusCode == 0);
    NSString *msg = response[@"status_msg"] ?: @"";
    
    NSLog(@"[熊猫-%@] 关注结果: %@ (code=%ld %@)", channel, success ? @"成功" : @"失败", (long)statusCode, msg);
    
    if (completion) {
        completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: msg}]);
    }
}

#pragma mark - 点赞

- (void)diggAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行点赞: aweme_id=%@", awemeId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"item_type"] = @"0";
    params[@"type"] = @"1";
    params[@"channel_id"] = @"0";
    params[@"action_time"] = @([[NSDate date] timeIntervalSince1970]).stringValue;
    
    [self sendDirectRequest:[self diggPath] params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 点赞失败: %@", error);
            if (completion) completion(NO, error);
            return;
        }
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        NSString *msg = response[@"status_msg"] ?: @"";
        NSLog(@"[熊猫] 点赞结果: %@ (code=%ld %@)", success ? @"成功" : @"失败", (long)statusCode, msg);
        if (completion) completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: msg}]);
    }];
}

#pragma mark - 收藏

- (void)collectAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion {
    NSLog(@"[熊猫] 执行收藏: aweme_id=%@", awemeId);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"collects_flag"] = @"1";
    
    [self sendDirectRequest:kAwemeCollectPath params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) { if (completion) completion(NO, error); return; }
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        if (completion) completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: response[@"status_msg"] ?: @""}]);
    }];
}

#pragma mark - 分享

- (void)shareAweme:(NSString *)awemeId completion:(void (^)(BOOL, NSError *))completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"share_type"] = @"0";
    
    [self sendDirectRequest:kAwemeStatsPath params:params completion:^(NSDictionary *response, NSError *error) {
        BOOL success = (error == nil);
        if (completion) completion(success, error);
    }];
}

#pragma mark - 评论

- (void)commentAweme:(NSString *)awemeId content:(NSString *)content completion:(void (^)(BOOL, NSError *))completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"text"] = content;
    
    [self sendDirectRequest:kAwemeCommentPublishPath params:params completion:^(NSDictionary *response, NSError *error) {
        if (error) { if (completion) completion(NO, error); return; }
        NSInteger statusCode = [response[@"status_code"] integerValue];
        BOOL success = (statusCode == 0);
        if (completion) completion(success, success ? nil : [NSError errorWithDomain:@"XMOperation" code:statusCode userInfo:@{NSLocalizedDescriptionKey: response[@"status_msg"] ?: @""}]);
    }];
}

#pragma mark - 播放

- (void)playAweme:(NSString *)awemeId duration:(NSInteger)duration completion:(void (^)(BOOL, NSError *))completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"aweme_id"] = awemeId;
    params[@"item_id"] = awemeId;
    params[@"play_duration"] = @(duration).stringValue;
    params[@"play_type"] = @"0";
    
    [self sendDirectRequest:kAwemeStatsPath params:params completion:^(NSDictionary *response, NSError *error) {
        BOOL success = (error == nil);
        if (completion) completion(success, error);
    }];
}

#pragma mark - 核心：直接 NSURLSession 发请求（绕过网络探测器）

- (void)sendDirectRequest:(NSString *)path params:(NSDictionary *)params completion:(void (^)(NSDictionary *, NSError *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@%@", kAwemeBaseURL, path];
    
    // URL-encode 参数
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
    request.timeoutInterval = 15;
    [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Aweme 39.6.0 rv:396016 (iPhone; iOS 16.1.2; zh_CN) Cronet" forHTTPHeaderField:@"User-Agent"];
    
    // 尝试获取 Cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
    if (cookies.count > 0) {
        NSDictionary *cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
        if (cookieHeaders[@"Cookie"]) {
            [request setValue:cookieHeaders[@"Cookie"] forHTTPHeaderField:@"Cookie"];
        }
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫-网络] 请求失败: %@", error);
            if (completion) completion(nil, error);
            return;
        }
        
        if (data) {
            NSError *jsonErr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr) {
                NSString *rawStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"[熊猫-网络] JSON解析失败: %@, raw=%@", jsonErr, rawStr ?: @"(nil)");
                if (completion) completion(nil, jsonErr);
            } else {
                if (completion) completion(json, nil);
            }
        } else {
            if (completion) completion(nil, [NSError errorWithDomain:@"XMOperation" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

#pragma mark - getCurrentUserInfo

- (void)fetchCurrentUserInfo {
    NSLog(@"[熊猫] 获取当前用户信息...");
    
    Class userManager = NSClassFromString(@"AWEUserManager");
    if (userManager && [userManager respondsToSelector:@selector(sharedManager)]) {
        id manager = ((id (*)(id, SEL))objc_msgSend)(userManager, @selector(sharedManager));
        if ([manager respondsToSelector:@selector(currentUserID)]) {
            NSString *uid = ((NSString *(*)(id, SEL))objc_msgSend)(manager, @selector(currentUserID));
            if (uid) {
                [XMGlobalManager sharedInstance].currentUid = uid;
                NSLog(@"[熊猫] UID: %@", uid);
            }
        }
        if ([manager respondsToSelector:@selector(currentSecUserID)]) {
            NSString *secUid = ((NSString *(*)(id, SEL))objc_msgSend)(manager, @selector(currentSecUserID));
            if (secUid) {
                [XMGlobalManager sharedInstance].currentSecUid = secUid;
                NSLog(@"[熊猫] SecUID: %@", secUid);
            }
        }
    }
    
    if (![XMGlobalManager sharedInstance].currentUid) {
        Class ttAccount = NSClassFromString(@"TTAccount");
        if (ttAccount && [ttAccount respondsToSelector:@selector(sharedAccount)]) {
            id account = ((id (*)(id, SEL))objc_msgSend)(ttAccount, @selector(sharedAccount));
            if ([account respondsToSelector:@selector(userID)]) {
                NSString *uid = ((NSString *(*)(id, SEL))objc_msgSend)(account, @selector(userID));
                if (uid) {
                    [XMGlobalManager sharedInstance].currentUid = uid;
                    NSLog(@"[熊猫] UID(TTAccount): %@", uid);
                }
            }
        }
    }
}

#pragma mark - 任务执行入口（熊猫平台模式）

- (void)onExecuteTask:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSString *taskId = userInfo[@"taskId"];
    NSDictionary *params = userInfo[@"params"];
    NSString *type = userInfo[@"type"];
    NSString *platform = userInfo[@"platform"];
    
    NSLog(@"[熊猫-操作引擎] 执行任务: %@ type=%@", taskId, type);
    
    __weak typeof(self) weakSelf = self;
    void (^submitBlock)(BOOL) = ^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (success) {
            strongSelf.totalTaskCount++;
            if ([type isEqualToString:@"dz"]) strongSelf.diggSuccessCount++;
            else if ([type isEqualToString:@"gz"]) strongSelf.followSuccessCount++;
            else if ([type isEqualToString:@"sc"]) strongSelf.collectSuccessCount++;
            else if ([type isEqualToString:@"fx"]) strongSelf.shareSuccessCount++;
            else if ([type isEqualToString:@"pl"]) strongSelf.commentSuccessCount++;
            else if ([type isEqualToString:@"bf"]) strongSelf.playSuccessCount++;
        }
        Class taskService = NSClassFromString(@"XMTaskService");
        if (taskService && [taskService respondsToSelector:@selector(sharedInstance)]) {
            id service = [taskService sharedInstance];
            if ([service respondsToSelector:@selector(submitTaskWithPlatform:type:taskId:success:completion:)]) {
                [service submitTaskWithPlatform:platform type:type taskId:taskId success:success completion:nil];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStatsUpdated" object:nil];
    };
    
    NSString *awemeId = params[@"video_id"] ?: params[@"aweme_id"];
    NSString *secUid = params[@"sec_uid"];
    NSString *userId = params[@"uid"];
    
    if ([type isEqualToString:@"dz"]) {
        if (awemeId) [self diggAweme:awemeId completion:^(BOOL s, NSError *e) { submitBlock(s); }];
        else submitBlock(NO);
    } else if ([type isEqualToString:@"gz"]) {
        if (secUid || userId) [self followUser:userId secUid:secUid completion:^(BOOL s, NSError *e) { submitBlock(s); }];
        else submitBlock(NO);
    } else if ([type isEqualToString:@"sc"]) {
        if (awemeId) [self collectAweme:awemeId completion:^(BOOL s, NSError *e) { submitBlock(s); }];
        else submitBlock(NO);
    } else if ([type isEqualToString:@"fx"] || [type isEqualToString:@"fx2"]) {
        if (awemeId) [self shareAweme:awemeId completion:^(BOOL s, NSError *e) { submitBlock(s); }];
        else submitBlock(NO);
    } else if ([type isEqualToString:@"pl"] || [type isEqualToString:@"pl2"]) {
        if (awemeId) {
            [self commentAweme:awemeId content:params[@"content"] ?: @"666" completion:^(BOOL s, NSError *e) { submitBlock(s); }];
        } else submitBlock(NO);
    } else if ([type isEqualToString:@"bf"] || [type isEqualToString:@"bf2"]) {
        if (awemeId) {
            NSInteger cnt = [params[@"cnt"] integerValue]; if (cnt == 0) cnt = 1;
            [self playAweme:awemeId duration:cnt * 3 completion:^(BOOL s, NSError *e) { submitBlock(s); }];
        } else submitBlock(NO);
    } else {
        submitBlock(NO);
    }
}

#pragma mark - 路径

- (NSString *)diggPath { return kAwemeDiggPath; }
- (NSString *)followPath { return kAwemeFollowPath; }

#pragma clang diagnostic pop

@end
