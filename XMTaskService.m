//
//  XMTaskService.m
//  dyDaemon - 熊猫平台版 v2.0
//
//  任务调度 + 三通道关注执行
//  CH1/CH2 → daemon (:12933)
//  CH3    → 直连抖音 API
//  点赞   → daemon 优先，失败直连
//

#import "XMTaskService.h"
#import "XMGlobalManager.h"
#import "XMDaemonClient.h"

@interface XMTaskService ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) NSInteger channelIndex;
@end

@implementation XMTaskService

+ (instancetype)sharedInstance {
    static XMTaskService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[XMTaskService alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _channelIndex = 0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStart) name:@"XMStartTasks" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStop) name:@"XMStopTasks" object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)onStart  { [self startTaskLoop]; }
- (void)onStop   { [self stopTaskLoop]; }

#pragma mark - 任务循环

- (void)startTaskLoop {
    if (self.isRunning) return;
    self.isRunning = YES;
    self.consecutiveErrorCount = 0;
    self.channelIndex = 0;
    NSLog(@"[熊猫] 任务循环启动");
    [self executeNextTask];
}

- (void)stopTaskLoop {
    self.isRunning = NO;
    NSLog(@"[熊猫] 任务循环停止");
}

#pragma mark - 通道轮转

/// 返回下一个启用通道号 (1/2/3)，全关返回 0
- (NSInteger)nextChannel {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    for (NSInteger i = 0; i < 3; i++) {
        self.channelIndex = (self.channelIndex % 3) + 1;
        if (self.channelIndex == 1 && gm.followCh1Enabled) return 1;
        if (self.channelIndex == 2 && gm.followCh2Enabled) return 2;
        if (self.channelIndex == 3 && gm.followCh3Enabled) return 3;
    }
    return 0;
}

#pragma mark - 执行

- (void)executeNextTask {
    if (!self.isRunning) return;
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    // 检查是否有任何启用的通道
    if (!gm.followCh1Enabled && !gm.followCh2Enabled && !gm.followCh3Enabled) {
        NSLog(@"[熊猫] 所有关注通道已关闭，等待...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self executeNextTask];
        });
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self fetchLocalFollowTask:^(NSString *uid, NSString *secUid, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isRunning) return;
        
        if (error) {
            if (error.code == 406) {  // 无任务
                strongSelf.consecutiveErrorCount = 0;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [strongSelf executeNextTask];
                });
                return;
            }
            strongSelf.consecutiveErrorCount++;
            if (strongSelf.consecutiveErrorCount >= gm.maxErrorCount) {
                [gm stopAllTasks];
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [strongSelf executeNextTask];
            });
            return;
        }
        
        strongSelf.consecutiveErrorCount = 0;
        NSInteger channel = [strongSelf nextChannel];
        NSInteger delay = gm.minInterval + arc4random_uniform((uint32_t)(gm.maxInterval - gm.minInterval + 1));
        
        NSLog(@"[熊猫] 关注 %@ 通道%ld (延迟%lds)", uid, (long)channel, (long)delay);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!strongSelf.isRunning) return;
            [strongSelf followUser:uid secUid:secUid channel:channel completion:^(BOOL ok, NSString *reason) {
                [strongSelf reportResult:uid success:ok reason:reason];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [strongSelf executeNextTask];
                });
            }];
        });
    }];
}

#pragma mark - 三通道关注

- (void)followUser:(NSString *)uid
            secUid:(NSString *)secUid
           channel:(NSInteger)channel
        completion:(void(^)(BOOL ok, NSString *reason))completion {
    
    switch (channel) {
        case 1: // daemon followUser3
            [[XMDaemonClient sharedClient] followUserCh1:uid secUid:secUid completion:^(BOOL ok, NSDictionary *result, NSString *error) {
                if (completion) {
                    NSString *code = result[@"code"] ?: result[@"status_code"];
                    BOOL success = ok && (code == nil || [code integerValue] == 0 || [code isEqualToString:@"0"]);
                    completion(success, error ?: (success ? @"daemon-ch1-ok" : @"daemon-ch1-fail"));
                }
            }];
            break;
            
        case 2: // daemon followUserByLive2
            [[XMDaemonClient sharedClient] followUserCh2:uid secUid:secUid completion:^(BOOL ok, NSDictionary *result, NSString *error) {
                if (completion) {
                    NSString *code = result[@"code"] ?: result[@"status_code"];
                    BOOL success = ok && (code == nil || [code integerValue] == 0 || [code isEqualToString:@"0"]);
                    completion(success, error ?: (success ? @"daemon-ch2-ok" : @"daemon-ch2-fail"));
                }
            }];
            break;
            
        case 3: // 直连抖音标准 API
            [self followUserDirect:uid secUid:secUid completion:completion];
            break;
            
        default:
            if (completion) completion(NO, @"no-channel");
            break;
    }
}

#pragma mark - CH3 直连抖音 API

- (void)followUserDirect:(NSString *)uid
                  secUid:(NSString *)secUid
              completion:(void(^)(BOOL ok, NSString *reason))completion {
    
    NSString *urlStr = [NSString stringWithFormat:
        @"https://aweme.snssdk.com/aweme/v1/commit/follow/user/?"
        @"user_id=%@&sec_user_id=%@&type=1&channel_id=13&from=0&from_type=0&from_pre=&from_action=0",
        uid ?: @"", secUid ?: @""];
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
    if (!url) {
        if (completion) completion(NO, @"ch3-bad-url");
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:15];
    [req setHTTPMethod:@"GET"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    
    NSLog(@"[熊猫-CH3] 直连关注 %@", uid);
    
    [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) {
            if (completion) completion(NO, [NSString stringWithFormat:@"ch3-net:%@", err.localizedDescription]);
            return;
        }
        if (!data) {
            if (completion) completion(NO, @"ch3-empty");
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSInteger code = [json[@"status_code"] integerValue];
        BOOL ok = (code == 0);
        NSLog(@"[熊猫-CH3] 关注结果: status_code=%ld", (long)code);
        if (completion) completion(ok, ok ? @"ch3-ok" : [NSString stringWithFormat:@"ch3-code-%ld", (long)code]);
    }];
}

#pragma mark - 点赞（daemon 优先，失败直连回退）

- (void)digg:(NSString *)awemeId completion:(void(^)(BOOL ok, NSString *reason))completion {
    [[XMDaemonClient sharedClient] digg:awemeId completion:^(BOOL ok, NSDictionary *result, NSString *error) {
        if (ok && !error) {
            if (completion) completion(YES, @"daemon-digg-ok");
            return;
        }
        // daemon 失败，直连回退
        NSLog(@"[熊猫] daemon digg失败(%@)，直连回退", error);
        [self diggDirect:awemeId completion:completion];
    }];
}

- (void)diggDirect:(NSString *)awemeId completion:(void(^)(BOOL ok, NSString *reason))completion {
    NSString *urlStr = [NSString stringWithFormat:
        @"https://aweme.snssdk.com/aweme/v1/commit/item/digg/?aweme_id=%@&type=1",
        awemeId ?: @""];
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
    if (!url) {
        if (completion) completion(NO, @"digg-bad-url");
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:15];
    [req setHTTPMethod:@"GET"];
    [req setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    
    [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(NO, err.localizedDescription); return; }
        if (!data) { if (completion) completion(NO, @"digg-empty"); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSInteger code = [json[@"status_code"] integerValue];
        if (completion) completion(code == 0, code == 0 ? @"digg-ok" : [NSString stringWithFormat:@"digg-code-%ld", (long)code]);
    }];
}

#pragma mark - 任务拉取

- (void)fetchLocalFollowTask:(void(^)(NSString *uid, NSString *secUid, NSError *error))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/task?device=%@&count=1",
                        gm.localServerURL, gm.deviceName ?: @"unknown"];
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
    if (!url) {
        if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL错误"}]);
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:15];
    [req setValue:gm.localApiKey forHTTPHeaderField:@"X-API-Key"];
    
    [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(nil, nil, err); return; }
        if (!data) { if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"空响应"}]); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSInteger code = [json[@"code"] integerValue];
        if (code == 0 && [json[@"data"] isKindOfClass:[NSArray class]]) {
            NSArray *targets = json[@"data"];
            if (targets.count > 0) {
                NSDictionary *t = targets[0];
                if (completion) completion(t[@"uid"], t[@"sec_uid"] ?: @"", nil);
            } else {
                if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:406 userInfo:@{NSLocalizedDescriptionKey: @"无任务"}]);
            }
        } else {
            if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:code userInfo:@{NSLocalizedDescriptionKey: json[@"msg"]?:@"失败"}]);
        }
    }];
}

#pragma mark - 结果上报

- (void)reportResult:(NSString *)uid success:(BOOL)ok reason:(NSString *)reason {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/report", gm.localServerURL];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:10];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:gm.localApiKey forHTTPHeaderField:@"X-API-Key"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{
        @"device": gm.deviceName ?: @"unknown",
        @"uid": uid ?: @"",
        @"ok": @(ok),
        @"reason": reason ?: @""
    } options:0 error:nil];
    
    [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!err) NSLog(@"[熊猫] 结果已上报: %@ (%@)", uid, ok ? @"成功" : @"失败");
    }];
}

@end
