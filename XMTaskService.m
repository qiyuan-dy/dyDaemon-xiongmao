//
//  XMTaskService.m
//  dyDaemon - 熊猫平台版
//

#import "XMTaskService.h"
#import "XMGlobalManager.h"
#import <objc/message.h>

@interface XMTaskService ()
@property (nonatomic, strong) NSTimer *taskTimer;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) NSInteger currentTaskTypeIndex;
@end

@implementation XMTaskService

+ (instancetype)sharedInstance {
    static XMTaskService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMTaskService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStartTasks) name:@"XMStartTasks" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStopTasks) name:@"XMStopTasks" object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)onStartTasks { [self startTaskLoop]; }
- (void)onStopTasks { [self stopTaskLoop]; }

#pragma mark - 获取任务（熊猫平台）

- (void)fetchTaskWithPlatform:(NSString *)platform type:(NSString *)type completion:(void (^)(NSString *, NSDictionary *, NSError *))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    if (!gm.apiKey || !gm.currentUid || !gm.currentSecUid) {
        if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"配置不完整"}]);
        return;
    }
    NSString *urlStr = [NSString stringWithFormat:@"%@/studio/api/task/get?key=%@&platform=%@&type=%@&uid=%@&sec_uid=%@",
                        gm.baseURL, gm.apiKey, platform, type, gm.currentUid, gm.currentSecUid];
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) { if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL格式错误"}]); return; }
    
    [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(nil, nil, err); return; }
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSInteger code = [json[@"code"] integerValue];
            if (code == 0 && json[@"data"]) {
                if (completion) completion(json[@"data"][@"studiotask_id"], json[@"data"][@"params"], nil);
            } else {
                if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:code userInfo:@{NSLocalizedDescriptionKey: json[@"msg"]?:@"未知错误"}]);
            }
        } else { if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]); }
    }];
}

- (void)submitTaskWithPlatform:(NSString *)platform type:(NSString *)type taskId:(NSString *)taskId success:(BOOL)success completion:(void (^)(BOOL, NSError *))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSString *urlStr = [NSString stringWithFormat:@"%@/studio/api/task/submit?platform=%@&type=%@&studiotask_id=%@&key=%@&result=%@",
                        gm.baseURL, platform, type, taskId, gm.apiKey, success ? @"true" : @"false"];
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) { if (completion) completion(NO, [NSError errorWithDomain:@"XMTaskService" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL格式错误"}]); return; }
    
    [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(NO, err); return; }
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion([json[@"success"] boolValue], nil);
        } else { if (completion) completion(NO, [NSError errorWithDomain:@"XMTaskService" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]); }
    }];
}

#pragma mark - 任务循环

- (NSArray *)enabledTaskTypes {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSMutableArray *types = [NSMutableArray array];
    if (gm.diggEnabled) [types addObject:@{@"platform": @"dy", @"type": @"dz"}];
    if (gm.followEnabled) [types addObject:@{@"platform": @"dy", @"type": @"gz"}];
    if (gm.collectEnabled) [types addObject:@{@"platform": @"dy", @"type": @"sc"}];
    if (gm.shareEnabled) [types addObject:@{@"platform": @"dy", @"type": @"fx"}];
    if (gm.commentEnabled) [types addObject:@{@"platform": @"dy", @"type": @"pl"}];
    if (gm.playEnabled) [types addObject:@{@"platform": @"dy", @"type": @"bf"}];
    return types;
}

- (void)startTaskLoop {
    if (self.isRunning) return;
    self.isRunning = YES;
    self.consecutiveErrorCount = 0;
    self.currentTaskTypeIndex = 0;
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    if (gm.useLocalServer && gm.localServerURL.length > 0) {
        NSLog(@"[熊猫] 使用本地服务器模式: %@", gm.localServerURL);
        [self startLocalTaskLoop];
        return;
    }
    [self executeNextTask];
}

- (void)stopTaskLoop { self.isRunning = NO; [self.taskTimer invalidate]; self.taskTimer = nil; }

- (void)executeNextTask {
    if (!self.isRunning) return;
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSArray *taskTypes = [self enabledTaskTypes];
    if (taskTypes.count == 0) { [self scheduleNextTask:5]; return; }
    
    NSDictionary *taskInfo = taskTypes[self.currentTaskTypeIndex % taskTypes.count];
    self.currentTaskTypeIndex++;
    
    __weak typeof(self) weakSelf = self;
    [self fetchTaskWithPlatform:taskInfo[@"platform"] type:taskInfo[@"type"] completion:^(NSString *taskId, NSDictionary *params, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            NSInteger code = error.code;
            strongSelf.consecutiveErrorCount++;
            if (code == 406) { strongSelf.consecutiveErrorCount = 0; [strongSelf scheduleNextTask:2]; return; }
            if (code == 403) { [strongSelf scheduleNextTask:30]; return; }
            if (strongSelf.consecutiveErrorCount >= gm.maxErrorCount) { [gm stopAllTasks]; return; }
            [strongSelf scheduleNextTask:5]; return;
        }
        strongSelf.consecutiveErrorCount = 0;
        [strongSelf executeTask:taskId params:params platform:taskInfo[@"platform"] type:taskInfo[@"type"]];
    }];
}

- (void)executeTask:(NSString *)taskId params:(NSDictionary *)params platform:(NSString *)platform type:(NSString *)type {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSInteger delay = gm.minInterval + arc4random_uniform((uint32_t)(gm.maxInterval - gm.minInterval + 1));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMExecuteTask" object:nil userInfo:@{
            @"taskId": taskId ?: @"", @"params": params ?: @{}, @"platform": platform ?: @"", @"type": type ?: @""}];
    });
}

- (void)scheduleNextTask:(NSInteger)delay {
    if (!self.isRunning) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self executeNextTask];
    });
}

#pragma mark - 本地服务器模式（多通道轮转）

- (void)startLocalTaskLoop {
    if (!self.isRunning) return;
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    // 获取下一个要用的通道号
    NSInteger channel = 0;
    Class engineClass = NSClassFromString(@"XMOperationEngine");
    if (engineClass && [engineClass respondsToSelector:@selector(sharedInstance)]) {
        id engine = [engineClass sharedInstance];
        if ([engine respondsToSelector:@selector(nextFollowChannel)]) {
            channel = (NSInteger)((NSInteger (*)(id, SEL))objc_msgSend)(engine, @selector(nextFollowChannel));
        }
    }
    
    if (channel == 0) {
        NSLog(@"[熊猫] 所有关注通道未启用，等待...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self startLocalTaskLoop];
        });
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self fetchLocalFollowTaskWithCompletion:^(NSString *uid, NSString *secUid, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isRunning) return;
        
        if (error) {
            NSInteger code = error.code;
            strongSelf.consecutiveErrorCount++;
            if (code == 406) {
                strongSelf.consecutiveErrorCount = 0;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [strongSelf startLocalTaskLoop];
                });
                return;
            }
            if (strongSelf.consecutiveErrorCount >= gm.maxErrorCount) {
                [gm stopAllTasks];
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [strongSelf startLocalTaskLoop];
            });
            return;
        }
        
        strongSelf.consecutiveErrorCount = 0;
        NSInteger delay = gm.minInterval + arc4random_uniform((uint32_t)(gm.maxInterval - gm.minInterval + 1));
        
        NSLog(@"[熊猫] 本地任务将在 %ld 秒后执行 (通道%ld)", (long)delay, (long)channel);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!strongSelf.isRunning) return;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"XMLocalFollowTask" object:nil userInfo:@{
                @"uid": uid ?: @"",
                @"sec_uid": secUid ?: @"",
                @"channel": @(channel),
                @"platform": @"local",
                @"type": @"gz"
            }];
        });
    }];
}

- (void)fetchLocalFollowTaskWithCompletion:(void (^)(NSString *, NSString *, NSError *))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/task?device=%@&count=1",
                        gm.localServerURL, gm.deviceName ?: @"unknown"];
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) { if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL错误"}]); return; }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:gm.localApiKey forHTTPHeaderField:@"X-API-Key"];
    request.timeoutInterval = 15;
    
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(nil, nil, err); return; }
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSInteger code = [json[@"code"] integerValue];
            if (code == 0 && [json[@"data"] isKindOfClass:[NSArray class]]) {
                NSArray *targets = json[@"data"];
                if (targets.count > 0) {
                    NSDictionary *target = targets[0];
                    if (completion) completion(target[@"uid"], target[@"sec_uid"] ?: @"", nil);
                } else {
                    if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:406 userInfo:@{NSLocalizedDescriptionKey: @"无任务"}]);
                }
            } else {
                if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:code userInfo:@{NSLocalizedDescriptionKey: json[@"msg"]?:@"未知错误"}]);
            }
        } else { if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]); }
    }];
}

- (void)reportLocalFollowResultWithUid:(NSString *)uid success:(BOOL)success reason:(NSString *)reason completion:(void (^)(BOOL, NSError *))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/report", gm.localServerURL];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) { if (completion) completion(NO, [NSError errorWithDomain:@"XMTask" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL错误"}]); return; }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:gm.localApiKey forHTTPHeaderField:@"X-API-Key"];
    request.timeoutInterval = 15;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{
        @"device": gm.deviceName ?: @"unknown",
        @"uid": uid ?: @"",
        @"ok": @(success),
        @"reason": reason ?: @""
    } options:0 error:nil];
    
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(NO, err); return; }
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion([json[@"code"] integerValue] == 0, nil);
        } else { if (completion) completion(NO, [NSError errorWithDomain:@"XMTask" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]); }
    }];
}

@end
