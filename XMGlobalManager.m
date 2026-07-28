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
        _deviceTag = @"z0997";
        _dns2Host = @"64.90.8.209";
        _dns2Port = 8081;
        _dns2ApiKey = @"qiyuan…2026";
        _dns2Enabled = YES;
        _pandaEnabled = NO;
        _baseURL = @"https://xiongmao88.xyz";
        _followCH1Enabled = NO;
        _followCH2Enabled = YES;  // CH2 默认开启（只需UID）
        _followCH3Enabled = NO;
        _minInterval = 5;
        _maxInterval = 15;
        _threadCount = 1;
        _maxErrorCount = 10;
        [self loadConfig];
    }
    return self;
}

#pragma mark - 日志广播

+ (void)log:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"[熊猫] %@", msg);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XMLogMessage"
                                                            object:nil
                                                          userInfo:@{@"text": msg}];
    });
}

#pragma mark - 启动/停止

- (void)startAllTasks {
    if (self.isRunning) return;
    
    if (!self.dns2Enabled && !self.pandaEnabled) {
        [XMGlobalManager log:@"❌ 未启用任何数据源"];
        return;
    }
    
    // 熊猫平台需要当前账号信息
    if (self.pandaEnabled && !self.currentUid) {
        [XMGlobalManager log:@"❌ 未获取到当前账号 UID (熊猫平台必需)"];
        return;
    }
    
    // 重置计数
    self.followCH1Done = 0;
    self.followCH2Done = 0;
    self.followCH3Done = 0;
    
    self.isRunning = YES;
    [XMGlobalManager log:@"🚀 启动: DNS2=%d 熊猫=%d CH1=%d CH2=%d CH3=%d",
     self.dns2Enabled, self.pandaEnabled,
     self.followCH1Enabled, self.followCH2Enabled, self.followCH3Enabled];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStartTasks" object:nil];
}

- (void)stopAllTasks {
    self.isRunning = NO;
    [XMGlobalManager log:@"⏹ 停止: CH1:%ld/%ld CH2:%ld/%ld CH3:%ld/%ld",
     (long)self.followCH1Done, (long)self.followCH1Target,
     (long)self.followCH2Done, (long)self.followCH2Target,
     (long)self.followCH3Done, (long)self.followCH3Target];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XMStopTasks" object:nil];
}

#pragma mark - 通道检查

/// 检查某个 CH 通道是否达目标（达目标自动关闭）
- (BOOL)checkCHTargetReached {
    BOOL changed = NO;
    if (self.followCH1Target > 0 && self.followCH1Done >= self.followCH1Target) {
        if (self.followCH1Enabled) {
            [XMGlobalManager log:@"🎯 CH1 目标达成 (%ld/%ld)", (long)self.followCH1Done, (long)self.followCH1Target];
            self.followCH1Enabled = NO;
            changed = YES;
        }
    }
    if (self.followCH2Target > 0 && self.followCH2Done >= self.followCH2Target) {
        if (self.followCH2Enabled) {
            [XMGlobalManager log:@"🎯 CH2 目标达成 (%ld/%ld)", (long)self.followCH2Done, (long)self.followCH2Target];
            self.followCH2Enabled = NO;
            changed = YES;
        }
    }
    if (self.followCH3Target > 0 && self.followCH3Done >= self.followCH3Target) {
        if (self.followCH3Enabled) {
            [XMGlobalManager log:@"🎯 CH3 目标达成 (%ld/%ld)", (long)self.followCH3Done, (long)self.followCH3Target];
            self.followCH3Enabled = NO;
            changed = YES;
        }
    }
    return changed;
}

#pragma mark - 配置持久化

- (void)saveConfig {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [docPath stringByAppendingPathComponent:kXMConfigFileName];
    
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    if (self.deviceTag) config[@"deviceTag"] = self.deviceTag;
    if (self.dns2Host) config[@"dns2Host"] = self.dns2Host;
    config[@"dns2Port"] = @(self.dns2Port);
    if (self.dns2ApiKey) config[@"dns2ApiKey"] = self.dns2ApiKey;
    config[@"dns2Enabled"] = @(self.dns2Enabled);
    config[@"pandaEnabled"] = @(self.pandaEnabled);
    if (self.apiKey) config[@"apiKey"] = self.apiKey;
    if (self.baseURL) config[@"baseURL"] = self.baseURL;
    
    config[@"followCH1Enabled"] = @(self.followCH1Enabled);
    config[@"followCH1Target"] = @(self.followCH1Target);
    config[@"followCH2Enabled"] = @(self.followCH2Enabled);
    config[@"followCH2Target"] = @(self.followCH2Target);
    config[@"followCH3Enabled"] = @(self.followCH3Enabled);
    config[@"followCH3Target"] = @(self.followCH3Target);
    
    config[@"diggEnabled"] = @(self.diggEnabled);
    config[@"collectEnabled"] = @(self.collectEnabled);
    config[@"shareEnabled"] = @(self.shareEnabled);
    config[@"commentEnabled"] = @(self.commentEnabled);
    config[@"playEnabled"] = @(self.playEnabled);
    config[@"minInterval"] = @(self.minInterval);
    config[@"maxInterval"] = @(self.maxInterval);
    config[@"threadCount"] = @(self.threadCount);
    config[@"maxErrorCount"] = @(self.maxErrorCount);
    
    [config writeToFile:configPath atomically:YES];
    [XMGlobalManager log:@"💾 配置已保存"];
}

- (void)loadConfig {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *configPath = [docPath stringByAppendingPathComponent:kXMConfigFileName];
    
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (!config) return;
    
    if (config[@"deviceTag"]) self.deviceTag = config[@"deviceTag"];
    if (config[@"dns2Host"]) self.dns2Host = config[@"dns2Host"];
    if (config[@"dns2Port"]) self.dns2Port = [config[@"dns2Port"] integerValue];
    if (config[@"dns2ApiKey"]) self.dns2ApiKey = config[@"dns2ApiKey"];
    if (config[@"dns2Enabled"]) self.dns2Enabled = [config[@"dns2Enabled"] boolValue];
    if (config[@"pandaEnabled"]) self.pandaEnabled = [config[@"pandaEnabled"] boolValue];
    if (config[@"apiKey"]) self.apiKey = config[@"apiKey"];
    if (config[@"baseURL"]) self.baseURL = config[@"baseURL"];
    
    if (config[@"followCH1Enabled"]) self.followCH1Enabled = [config[@"followCH1Enabled"] boolValue];
    if (config[@"followCH1Target"]) self.followCH1Target = [config[@"followCH1Target"] integerValue];
    if (config[@"followCH2Enabled"]) self.followCH2Enabled = [config[@"followCH2Enabled"] boolValue];
    if (config[@"followCH2Target"]) self.followCH2Target = [config[@"followCH2Target"] integerValue];
    if (config[@"followCH3Enabled"]) self.followCH3Enabled = [config[@"followCH3Enabled"] boolValue];
    if (config[@"followCH3Target"]) self.followCH3Target = [config[@"followCH3Target"] integerValue];
    
    if (config[@"diggEnabled"]) self.diggEnabled = [config[@"diggEnabled"] boolValue];
    if (config[@"collectEnabled"]) self.collectEnabled = [config[@"collectEnabled"] boolValue];
    if (config[@"shareEnabled"]) self.shareEnabled = [config[@"shareEnabled"] boolValue];
    if (config[@"commentEnabled"]) self.commentEnabled = [config[@"commentEnabled"] boolValue];
    if (config[@"playEnabled"]) self.playEnabled = [config[@"playEnabled"] boolValue];
    if (config[@"minInterval"]) self.minInterval = [config[@"minInterval"] integerValue];
    if (config[@"maxInterval"]) self.maxInterval = [config[@"maxInterval"] integerValue];
    if (config[@"threadCount"]) self.threadCount = [config[@"threadCount"] integerValue];
    if (config[@"maxErrorCount"]) self.maxErrorCount = [config[@"maxErrorCount"] integerValue];
}

@end
