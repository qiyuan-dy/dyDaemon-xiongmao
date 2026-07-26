//
//  XMTaskService.m
//  dyDaemon - 熊猫平台版
//
//  任务调度服务实现（对接熊猫平台 API）
//

#import "XMTaskService.h"
#import "XMGlobalManager.h"

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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onStartTasks)
                                                     name:@"XMStartTasks"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onStopTasks)
                                                     name:@"XMStopTasks"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 通知回调

- (void)onStartTasks {
    [self startTaskLoop];
}

- (void)onStopTasks {
    [self stopTaskLoop];
}

#pragma mark - 获取任务

- (void)fetchTaskWithPlatform:(NSString *)platform
                         type:(NSString *)type
                   completion:(void (^)(NSString *taskId, NSDictionary *params, NSError *error))completion {
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    if (!gm.apiKey || !gm.currentUid || !gm.currentSecUid) {
        NSError *err = [NSError errorWithDomain:@"XMTaskService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"配置不完整"}];
        if (completion) completion(nil, nil, err);
        return;
    }
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/studio/api/task/get?key=%@&platform=%@&type=%@&uid=%@&sec_uid=%@",
                        gm.baseURL, gm.apiKey, platform, type, gm.currentUid, gm.currentSecUid];
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) {
        NSError *err = [NSError errorWithDomain:@"XMTaskService" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL 格式错误"}];
        if (completion) completion(nil, nil, err);
        return;
    }
    
    NSLog(@"[熊猫] 获取任务: %@ type=%@", platform, type);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 获取任务失败: %@", error);
            if (completion) completion(nil, nil, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSInteger code = [json[@"code"] integerValue];
            
            if (code == 0 && json[@"data"]) {
                NSString *taskId = json[@"data"][@"studiotask_id"];
                NSDictionary *params = json[@"data"][@"params"];
                NSString *taskType = json[@"data"][@"type"];
                NSLog(@"[熊猫] 拿到任务: %@ type=%@", taskId, taskType);
                if (completion) completion(taskId, params, nil);
            } else {
                NSString *msg = json[@"msg"] ?: @"未知错误";
                NSError *err = [NSError errorWithDomain:@"XMTaskService" code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
                NSLog(@"[熊猫] 获取任务失败 code=%ld msg=%@", (long)code, msg);
                if (completion) completion(nil, nil, err);
            }
        } else {
            if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

#pragma mark - 提交任务

- (void)submitTaskWithPlatform:(NSString *)platform
                          type:(NSString *)type
                        taskId:(NSString *)taskId
                       success:(BOOL)success
                    completion:(void (^)(BOOL success, NSError *error))completion {
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    NSString *resultStr = success ? @"true" : @"false";
    NSString *urlStr = [NSString stringWithFormat:@"%@/studio/api/task/submit?platform=%@&type=%@&studiotask_id=%@&key=%@&result=%@",
                        gm.baseURL, platform, type, taskId, gm.apiKey, resultStr];
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) {
        if (completion) completion(NO, [NSError errorWithDomain:@"XMTaskService" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL 格式错误"}]);
        return;
    }
    
    NSLog(@"[熊猫] 提交任务: %@ success=%d", taskId, success);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[熊猫] 提交任务失败: %@", error);
            if (completion) completion(NO, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL ok = [json[@"success"] boolValue];
            NSInteger code = [json[@"code"] integerValue];
            NSString *msg = json[@"msg"] ?: @"";
            
            NSLog(@"[熊猫] 提交结果: %@ code=%ld msg=%@", ok ? @"成功" : @"失败", (long)code, msg);
            if (completion) completion(ok, ok ? nil : [NSError errorWithDomain:@"XMTaskService" code:code userInfo:@{NSLocalizedDescriptionKey: msg}]);
        } else {
            if (completion) completion(NO, [NSError errorWithDomain:@"XMTaskService" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
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
    
    // 判断是否使用本地服务器
    if (gm.useLocalServer && gm.localServerURL.length > 0) {
        NSLog(@"[熊猫] 使用本地服务器模式: %@", gm.localServerURL);
        [self startLocalTaskLoop];
        return;
    }
    
    // 立即执行一次（熊猫平台模式）
    [self executeNextTask];
}

- (void)stopTaskLoop {
    self.isRunning = NO;
    [self.taskTimer invalidate];
    self.taskTimer = nil;
}

- (void)executeNextTask {
    if (!self.isRunning) return;
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSArray *taskTypes = [self enabledTaskTypes];
    
    if (taskTypes.count == 0) {
        NSLog(@"[熊猫] 没有启用的任务类型");
        [self scheduleNextTask:5];
        return;
    }
    
    // 轮询不同任务类型
    NSDictionary *taskInfo = taskTypes[self.currentTaskTypeIndex % taskTypes.count];
    self.currentTaskTypeIndex++;
    
    NSString *platform = taskInfo[@"platform"];
    NSString *type = taskInfo[@"type"];
    
    __weak typeof(self) weakSelf = self;
    [self fetchTaskWithPlatform:platform type:type completion:^(NSString *taskId, NSDictionary *params, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error) {
            NSInteger code = error.code;
            strongSelf.consecutiveErrorCount++;
            
            // 没有任务(406)不算错误
            if (code == 406) {
                NSLog(@"[熊猫] 当前类型无任务，换下一个");
                strongSelf.consecutiveErrorCount = 0;
                [strongSelf scheduleNextTask:2];
                return;
            }
            
            // 访问太频繁(403)，多等一会儿
            if (code == 403) {
                NSLog(@"[熊猫] 访问太频繁，休息30秒");
                [strongSelf scheduleNextTask:30];
                return;
            }
            
            // 连续错误太多
            if (strongSelf.consecutiveErrorCount >= gm.maxErrorCount) {
                NSLog(@"[熊猫] 连续错误过多，停止任务");
                [[XMGlobalManager sharedInstance] stopAllTasks];
                return;
            }
            
            [strongSelf scheduleNextTask:5];
            return;
        }
        
        strongSelf.consecutiveErrorCount = 0;
        
        // 执行任务
        [strongSelf executeTask:taskId params:params platform:platform type:type];
    }];
}

- (void)executeTask:(NSString *)taskId params:(NSDictionary *)params platform:(NSString *)platform type:(NSString *)type {
    // 随机等待一段时间再执行
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSInteger minInterval = gm.minInterval;
    NSInteger maxInterval = gm.maxInterval;
    NSInteger delay = minInterval + arc4random_uniform((uint32_t)(maxInterval - minInterval + 1));
    
    NSLog(@"[熊猫] 任务 %@ 将在 %ld 秒后执行", taskId, (long)delay);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 根据任务类型执行对应的操作
        // 这里通过通知发送给操作引擎去执行
        NSDictionary *userInfo = @{
            @"taskId": taskId ?: @"",
            @"params": params ?: @{},
            @"platform": platform ?: @"",
            @"type": type ?: @""
        };
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMExecuteTask" object:nil userInfo:userInfo];
    });
}

- (void)scheduleNextTask:(NSInteger)delay {
    if (!self.isRunning) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self executeNextTask];
    });
}

#pragma mark - 本地服务器模式

- (void)startLocalTaskLoop {
    if (!self.isRunning) return;
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
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
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!strongSelf.isRunning) return;
            
            NSDictionary *userInfo = @{
                @"uid": uid ?: @"",
                @"secUid": secUid ?: @"",
                @"platform": @"local",
                @"type": @"gz"
            };
            [[NSNotificationCenter defaultCenter] postNotificationName:@"XMLocalFollowTask"
                                                                object:nil
                                                              userInfo:userInfo];
        });
    }];
}

- (void)fetchLocalFollowTaskWithCompletion:(void (^)(NSString *uid, NSString *secUid, NSError *error))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/task?device=%@&count=1",
                        gm.localServerURL, gm.deviceName ?: @"unknown"];
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) {
        if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL错误"}]);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:gm.localApiKey forHTTPHeaderField:@"X-API-Key"];
    request.timeoutInterval = 15;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, nil, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSInteger code = [json[@"code"] integerValue];
            
            if (code == 0 && [json[@"data"] isKindOfClass:[NSArray class]]) {
                NSArray *targets = json[@"data"];
                if (targets.count > 0) {
                    NSDictionary *target = targets[0];
                    NSString *uid = target[@"uid"];
                    NSString *secUid = target[@"sec_uid"] ?: @"";
                    if (completion) completion(uid, secUid, nil);
                } else {
                    if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:406 userInfo:@{NSLocalizedDescriptionKey: @"无任务"}]);
                }
            } else {
                NSString *msg = json[@"msg"] ?: @"未知错误";
                if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:code userInfo:@{NSLocalizedDescriptionKey: msg}]);
            }
        } else {
            if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTask" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

- (void)reportLocalFollowResultWithUid:(NSString *)uid success:(BOOL)success reason:(NSString *)reason completion:(void (^)(BOOL ok, NSError *error))completion {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/report", gm.localServerURL];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO, [NSError errorWithDomain:@"XMTask" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL错误"}]);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:gm.localApiKey forHTTPHeaderField:@"X-API-Key"];
    request.timeoutInterval = 15;
    
    NSDictionary *body = @{
        @"device": gm.deviceName ?: @"unknown",
        @"uid": uid ?: @"",
        @"ok": @(success),
        @"reason": reason ?: @""
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSInteger code = [json[@"code"] integerValue];
            BOOL ok = (code == 0);
            if (completion) completion(ok, ok ? nil : [NSError errorWithDomain:@"XMTask" code:code userInfo:@{NSLocalizedDescriptionKey: json[@"msg"] ?: @"上报失败"}]);
        } else {
            if (completion) completion(NO, [NSError errorWithDomain:@"XMTask" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

@end
