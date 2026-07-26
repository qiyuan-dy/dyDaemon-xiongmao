//
//  XMGlobalManager.m
//  dyDaemon - 熊猫平台版 v2.0
//

#import "XMGlobalManager.h"

static NSString * const kXMConfigFileName = @"xiongmao_config_v2.plist";

@implementation XMGlobalManager {
    BOOL _isRunning;
}

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
        // 默认值
        _localServerURL = @"http://64.90.8.209:8081";
        _localApiKey = @"qiyuan_follow_2026";
        _useLocalServer = YES;
        _deviceName = @"z0997";
        _minInterval = 5;
        _maxInterval = 15;
        _maxErrorCount = 10;
        // 默认启用三个通道
        _followCh1Enabled = YES;
        _followCh2Enabled = YES;
        _followCh3Enabled = YES;
        // 默认启用关注和点赞
        _followEnabled = YES;
        _diggEnabled = NO;
        [self loadConfig];
    }
    return self;
}

#pragma mark - 任务控制

- (BOOL)isRunning {
    return _isRunning;
}

- (void)startAllTasks {
    if (_isRunning) return;
    
    if (self.useLocalServer) {
        if (!self.localApiKey || self.localApiKey.length == 0) {
            NSLog(@"[熊猫] ERROR: localApiKey 为空");
            return;
        }
    }
    
    _isRunning = YES;
    NSLog(@"[熊猫] v%@ 任务启动", XM_VERSION);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStartTasks" object:nil];
}

- (void)stopAllTasks {
    _isRunning = NO;
    NSLog(@"[熊猫] 任务已停止");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStopTasks" object:nil];
}

#pragma mark - 配置持久化

- (void)saveConfig {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [docPath stringByAppendingPathComponent:kXMConfigFileName];
    
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
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
    config[@"maxErrorCount"] = @(self.maxErrorCount);
    
    [config writeToFile:configPath atomically:YES];
    NSLog(@"[熊猫] 配置已保存");
}

- (void)loadConfig {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [docPath stringByAppendingPathComponent:kXMConfigFileName];
    
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (!config) return;
    
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
    if (config[@"maxErrorCount"]) self.maxErrorCount = [config[@"maxErrorCount"] integerValue];
}

@end
