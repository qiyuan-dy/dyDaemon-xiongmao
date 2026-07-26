//
//  XMGlobalManager.m
//  dyDaemon - 熊猫平台版
//
//  全局状态管理中心实现
//

#import "XMGlobalManager.h"

static NSString * const kXMConfigFileName = @"xiongmao_config.plist";

@implementation XMGlobalManager

+ (instancetype)sharedInstance {
    static XMGlobalManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMGlobalManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _baseURL = @"https://xiongmao88.xyz";
        _localServerURL = @"http://64.90.8.209:8081";
        _localApiKey = @"qiyuan_follow_2026";
        _useLocalServer = YES;
        _deviceName = @"z0997";
        _minInterval = 5;
        _maxInterval = 15;
        _threadCount = 1;
        _maxErrorCount = 10;
        [self loadConfig];
    }
    return self;
}

#pragma mark - 启动/停止

- (void)startAllTasks {
    if (self.isRunning) return;
    
    if (!self.apiKey || self.apiKey.length == 0) {
        NSLog(@"[熊猫] 错误: 未设置 API Key");
        return;
    }
    
    if (!self.currentUid || !self.currentSecUid) {
        NSLog(@"[熊猫] 错误: 未获取到当前账号信息");
        return;
    }
    
    self.isRunning = YES;
    NSLog(@"[熊猫] 任务启动成功");
    
    // 通知任务服务开始拉任务
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStartTasks" object:nil];
}

- (void)stopAllTasks {
    self.isRunning = NO;
    NSLog(@"[熊猫] 任务已停止");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStopTasks" object:nil];
}

#pragma mark - 配置持久化

- (void)saveConfig {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [docPath stringByAppendingPathComponent:kXMConfigFileName];
    
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    if (self.apiKey) config[@"apiKey"] = self.apiKey;
    if (self.baseURL) config[@"baseURL"] = self.baseURL;
    config[@"useLocalServer"] = @(self.useLocalServer);
    if (self.localServerURL) config[@"localServerURL"] = self.localServerURL;
    if (self.localApiKey) config[@"localApiKey"] = self.localApiKey;
    if (self.deviceName) config[@"deviceName"] = self.deviceName;
    config[@"diggEnabled"] = @(self.diggEnabled);
    config[@"followEnabled"] = @(self.followEnabled);
    config[@"collectEnabled"] = @(self.collectEnabled);
    config[@"shareEnabled"] = @(self.shareEnabled);
    config[@"commentEnabled"] = @(self.commentEnabled);
    config[@"playEnabled"] = @(self.playEnabled);
    config[@"minInterval"] = @(self.minInterval);
    config[@"maxInterval"] = @(self.maxInterval);
    config[@"threadCount"] = @(self.threadCount);
    config[@"maxErrorCount"] = @(self.maxErrorCount);
    
    [config writeToFile:configPath atomically:YES];
}

- (void)loadConfig {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [docPath stringByAppendingPathComponent:kXMConfigFileName];
    
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (config) {
        self.apiKey = config[@"apiKey"];
        if (config[@"baseURL"]) self.baseURL = config[@"baseURL"];
        if (config[@"useLocalServer"]) self.useLocalServer = [config[@"useLocalServer"] boolValue];
        if (config[@"localServerURL"]) self.localServerURL = config[@"localServerURL"];
        if (config[@"localApiKey"]) self.localApiKey = config[@"localApiKey"];
        if (config[@"deviceName"]) self.deviceName = config[@"deviceName"];
        self.diggEnabled = [config[@"diggEnabled"] boolValue];
        self.followEnabled = [config[@"followEnabled"] boolValue];
        self.collectEnabled = [config[@"collectEnabled"] boolValue];
        self.shareEnabled = [config[@"shareEnabled"] boolValue];
        self.commentEnabled = [config[@"commentEnabled"] boolValue];
        self.playEnabled = [config[@"playEnabled"] boolValue];
        if (config[@"minInterval"]) self.minInterval = [config[@"minInterval"] integerValue];
        if (config[@"maxInterval"]) self.maxInterval = [config[@"maxInterval"] integerValue];
        if (config[@"threadCount"]) self.threadCount = [config[@"threadCount"] integerValue];
        if (config[@"maxErrorCount"]) self.maxErrorCount = [config[@"maxErrorCount"] integerValue];
    }
}

@end
