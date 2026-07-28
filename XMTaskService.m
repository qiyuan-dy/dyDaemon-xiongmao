//
//  XMTaskService.m
//  dyDaemon - 熊猫平台版
//
//  任务调度服务 — 双数据源（DNS2 + 熊猫平台）
//

#import "XMTaskService.h"
#import "XMGlobalManager.h"
#import "XMDNS2Client.h"
#import "XMDaemonClient.h"

@interface XMTaskService ()

@property (nonatomic, strong) NSTimer *taskTimer;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) NSInteger currentTaskTypeIndex;
/// 当前数据源索引（0=DNS2, 1=熊猫平台）
@property (nonatomic, assign) NSInteger currentSourceIndex;

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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onTaskCompleted:)
                                                     name:@"XMTaskCompleted"
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

- (void)onTaskCompleted:(NSNotification *)note {
    if (!self.isRunning) return;
    
    BOOL success = [note.userInfo[@"success"] boolValue];
    NSString *taskId = note.userInfo[@"taskId"];
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSInteger delay = gm.minInterval + arc4random_uniform((uint32_t)(gm.maxInterval - gm.minInterval + 1));
    
    [XMGlobalManager log:@"🔄 任务 %@ %@ → %lds 后取下一个", taskId, success ? @"完成" : @"失败", (long)delay];
    
    [self scheduleNextTask:delay];
}

#pragma mark - 获取启用的数据源

- (NSArray *)enabledSources {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSMutableArray *sources = [NSMutableArray array];
    
    // DNS2: 至少一个关注通道启用
    if (gm.dns2Enabled && (gm.followCH1Enabled || gm.followCH2Enabled || gm.followCH3Enabled)) {
        [sources addObject:@"dns2"];
    }
    
    // 熊猫平台
    if (gm.pandaEnabled) {
        [sources addObject:@"panda"];
    }
    
    return sources;
}

#pragma mark - 熊猫平台任务类型

- (NSArray *)pandaTaskTypes {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSMutableArray *types = [NSMutableArray array];
    
    if (gm.diggEnabled) [types addObject:@{@"platform": @"dy", @"type": @"dz"}];
    if (gm.followCH1Enabled || gm.followCH2Enabled || gm.followCH3Enabled) [types addObject:@{@"platform": @"dy", @"type": @"gz"}];
    if (gm.collectEnabled) [types addObject:@{@"platform": @"dy", @"type": @"sc"}];
    if (gm.shareEnabled) [types addObject:@{@"platform": @"dy", @"type": @"fx"}];
    if (gm.commentEnabled) [types addObject:@{@"platform": @"dy", @"type": @"pl"}];
    if (gm.playEnabled) [types addObject:@{@"platform": @"dy", @"type": @"bf"}];
    
    return types;
}

#pragma mark - 任务循环

- (void)startTaskLoop {
    if (self.isRunning) return;
    
    self.isRunning = YES;
    self.consecutiveErrorCount = 0;
    self.currentTaskTypeIndex = 0;
    self.currentSourceIndex = 0;
    
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
    
    // 检查各通道目标
    [gm checkCHTargetReached];
    
    NSArray *sources = [self enabledSources];
    
    if (sources.count == 0) {
        [XMGlobalManager log:@"⏹ 所有数据源/通道已完成"];
        [gm stopAllTasks];
        return;
    }
    
    NSString *source = sources[self.currentSourceIndex % sources.count];
    self.currentSourceIndex++;
    
    if ([source isEqualToString:@"dns2"]) {
        [self fetchFromDNS2];
    } else if ([source isEqualToString:@"panda"]) {
        [self fetchFromPanda];
    }
}

#pragma mark - DNS2 数据源

- (void)fetchFromDNS2 {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    __weak typeof(self) weakSelf = self;
    [[XMDNS2Client sharedInstance] fetchTasks:1 completion:^(NSArray<NSDictionary *> *targets, NSInteger code, NSString *msg) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (code == 406 || targets.count == 0) {
            strongSelf.consecutiveErrorCount = 0;
            [strongSelf scheduleNextTask:10];
            return;
        }
        
        if (code != 0 || !targets) {
            [XMGlobalManager log:@"⚠️ DNS2 获取失败: code=%ld", (long)code];
            strongSelf.consecutiveErrorCount++;
            if (strongSelf.consecutiveErrorCount >= gm.maxErrorCount) {
                [XMGlobalManager log:@"❌ 连续错误过多，停止"];
                [gm stopAllTasks];
                return;
            }
            [strongSelf scheduleNextTask:10];
            return;
        }
        
        strongSelf.consecutiveErrorCount = 0;
        
        // 选择关注通道（轮转）
        NSString *chType = [strongSelf nextFollowChannel];
        if (!chType) {
            [XMGlobalManager log:@"⚠️ 无可用关注通道"];
            [strongSelf scheduleNextTask:10];
            return;
        }
        
        // 只取第一个目标，逐个处理
        NSDictionary *target = targets.firstObject;
        NSString *uid = target[@"uid"];
        NSString *secUid = target[@"sec_uid"];
        NSString *nickname = target[@"nickname"] ?: @"";
        
        if (!uid) { [strongSelf scheduleNextTask:2]; return; }
        
        NSDictionary *params = @{
            @"uid": uid,
            @"sec_uid": secUid ?: @"",
            @"nickname": nickname,
            @"source": @"dns2",
            @"channel": chType
        };
        
        [strongSelf executeDNS2Task:uid params:params chType:chType];
    }];
}

- (void)executeDNS2Task:(NSString *)uid params:(NSDictionary *)params chType:(NSString *)chType {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSInteger delay = gm.minInterval + arc4random_uniform((uint32_t)(gm.maxInterval - gm.minInterval + 1));
    
    [XMGlobalManager log:@"📋 %@ 将在 %lds 后关注 uid=%@", chType, (long)delay, uid];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{
            @"taskId": uid,
            @"params": params,
            @"platform": @"dns2",
            @"type": chType  // gz1 / gz2 / gz3
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMExecuteTask" object:nil userInfo:userInfo];
    });
}

/// 选择下一个启用的关注通道（轮转 CH1→CH2→CH3）
- (NSString *)nextFollowChannel {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSMutableArray *chs = [NSMutableArray array];
    if (gm.followCH1Enabled) [chs addObject:@"gz1"];
    if (gm.followCH2Enabled) [chs addObject:@"gz2"];
    if (gm.followCH3Enabled) [chs addObject:@"gz3"];
    if (chs.count == 0) return nil;
    
    static NSInteger chIndex = 0;
    chIndex = (chIndex + 1) % chs.count;
    return chs[chIndex];
}

#pragma mark - 熊猫平台数据源

- (void)fetchFromPanda {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSArray *taskTypes = [self pandaTaskTypes];
    
    if (taskTypes.count == 0) {
        NSLog(@"[熊猫] 没有启用的熊猫任务类型");
        [self scheduleNextTask:5];
        return;
    }
    
    NSDictionary *taskInfo = taskTypes[self.currentTaskTypeIndex % taskTypes.count];
    self.currentTaskTypeIndex++;
    
    NSString *platform = taskInfo[@"platform"];
    NSString *type = taskInfo[@"type"];
    
    __weak typeof(self) weakSelf = self;
    [self fetchPandaTaskWithPlatform:platform type:type completion:^(NSString *taskId, NSDictionary *params, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error) {
            NSInteger code = error.code;
            strongSelf.consecutiveErrorCount++;
            
            if (code == 406) {
                strongSelf.consecutiveErrorCount = 0;
                [strongSelf scheduleNextTask:2];
                return;
            }
            
            if (code == 403) {
                [strongSelf scheduleNextTask:30];
                return;
            }
            
            if (strongSelf.consecutiveErrorCount >= gm.maxErrorCount) {
                [[XMGlobalManager sharedInstance] stopAllTasks];
                return;
            }
            
            [strongSelf scheduleNextTask:5];
            return;
        }
        
        strongSelf.consecutiveErrorCount = 0;
        
        NSInteger delay = gm.minInterval + arc4random_uniform((uint32_t)(gm.maxInterval - gm.minInterval + 1));
        NSLog(@"[熊猫] 任务 %@ 将在 %ld 秒后执行", taskId, (long)delay);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{
                @"taskId": taskId ?: @"",
                @"params": params ?: @{},
                @"platform": platform ?: @"",
                @"type": type ?: @""
            };
            [[NSNotificationCenter defaultCenter] postNotificationName:@"XMExecuteTask" object:nil userInfo:userInfo];
        });
    }];
}

#pragma mark - 熊猫平台 API

- (void)fetchPandaTaskWithPlatform:(NSString *)platform
                              type:(NSString *)type
                        completion:(void (^)(NSString *, NSDictionary *, NSError *))completion {
    
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
        if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"URL 格式错误"}]);
        return;
    }
    
    NSLog(@"[熊猫] 获取任务: %@ type=%@", platform, type);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, nil, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSInteger code = [json[@"code"] integerValue];
            
            if (code == 0 && json[@"data"]) {
                NSString *taskId = json[@"data"][@"studiotask_id"];
                NSDictionary *params = json[@"data"][@"params"];
                if (completion) completion(taskId, params, nil);
            } else {
                NSString *msg = json[@"msg"] ?: @"未知错误";
                NSError *err = [NSError errorWithDomain:@"XMTaskService" code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
                if (completion) completion(nil, nil, err);
            }
        } else {
            if (completion) completion(nil, nil, [NSError errorWithDomain:@"XMTaskService" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

#pragma mark - 提交任务（操作引擎完成后回调）

- (void)submitTaskWithPlatform:(NSString *)platform
                          type:(NSString *)type
                        taskId:(NSString *)taskId
                       success:(BOOL)success
                    completion:(void (^)(BOOL success, NSError *error))completion {
    
    if ([platform isEqualToString:@"dns2"]) {
        // DNS2 上报
        NSString *reason = success ? @"" : @"follow_failed";
        [[XMDNS2Client sharedInstance] reportTask:taskId success:success reason:reason completion:^(BOOL ok) {
            if (completion) completion(ok, ok ? nil : [NSError errorWithDomain:@"DNS2" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"上报失败"}]);
        }];
        return;
    }
    
    // 熊猫平台上报
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
            if (completion) completion(NO, error);
            return;
        }
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL ok = [json[@"success"] boolValue] || [json[@"code"] integerValue] == 0;
            if (completion) completion(ok, ok ? nil : [NSError errorWithDomain:@"XMTaskService" code:[json[@"code"] integerValue] userInfo:@{NSLocalizedDescriptionKey: json[@"msg"] ?: @""}]);
        }
    }];
    [task resume];
}

#pragma mark - 调度下一轮

- (void)scheduleNextTask:(NSInteger)delay {
    if (!self.isRunning) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self executeNextTask];
    });
}

@end
