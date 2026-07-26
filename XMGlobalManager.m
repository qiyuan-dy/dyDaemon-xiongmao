//
//  XMGlobalManager.m
//  dyDaemon - 熊猫平台版
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
        // 默认启用三个关注通道
        _followCh1Enabled = YES;
        _followCh2Enabled = YES;
        _followCh3Enabled = YES;
        [self loadConfig];
    }
    return self;
}

- (void)startAllTasks {
    if (self.isRunning) return;
    
    if (self.useLocalServer) {
        if (!self.localApiKey || self.localApiKey.length == 0) {
            NSLog(@"[xm] Error: localApiKey not set");
            return;
        }
    } else {
        if (!self.apiKey || self.apiKey.length == 0) {
            NSLog(@"[xm] Error: apiKey not set");
            return;
        }
        if (!self.currentUid || !self.currentSecUid) {
            NSLog(@"[xm] Error: account info not available");
            return;
        }
    }
    
    self.isRunning = YES;
    NSLog(@"[熊猫] 任务启动成功");
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
    config[@"followCh1Enabled"] = @(self.followCh1Enabled);
    config[@"followCh2Enabled"] = @(self.followCh2Enabled);
    config[@"followCh3Enabled"] = @(self.followCh3Enabled);
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
        if (config[@"followCh1Enabled"]) self.followCh1Enabled = [config[@"followCh1Enabled"] boolValue];
        if (config[@"followCh2Enabled"]) self.followCh2Enabled = [config[@"followCh2Enabled"] boolValue];
        if (config[@"followCh3Enabled"]) self.followCh3Enabled = [config[@"followCh3Enabled"] boolValue];
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
