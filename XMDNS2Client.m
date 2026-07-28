//
//  XMDNS2Client.m
//  dyDaemon - 熊猫平台版
//
//  DNS2 关注数据库客户端实现
//

#import "XMDNS2Client.h"
#import "XMGlobalManager.h"

@interface XMDNS2Client ()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation XMDNS2Client

+ (instancetype)sharedInstance {
    static XMDNS2Client *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMDNS2Client alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 10;
        config.timeoutIntervalForResource = 15;
        self.session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - 构建 URL

- (NSString *)baseURL {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    NSString *host = gm.dns2Host ?: @"64.90.8.209";
    NSInteger port = gm.dns2Port > 0 ? gm.dns2Port : 8081;
    return [NSString stringWithFormat:@"http://%@:%ld", host, (long)port];
}

- (NSString *)apiKey {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    return gm.dns2ApiKey ?: @"qiyuan_follow_2026";
}

- (NSString *)deviceName {
    // 使用设备标签
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    return gm.deviceTag ?: @"z0997";
}

#pragma mark - 获取任务

- (void)fetchTasks:(NSInteger)count
        completion:(void (^)(NSArray<NSDictionary *> *, NSInteger, NSString *))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/task?device=%@&count=%ld",
                        [self baseURL], [self deviceName], (long)count];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    [req setValue:[self apiKey] forHTTPHeaderField:@"X-API-Key"];
    req.timeoutInterval = 10;
    
    NSLog(@"[DNS2] 拉取任务: %@", urlStr);
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            NSLog(@"[DNS2] 网络错误: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -1, error.localizedDescription);
            });
            return;
        }
        
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -2, @"无返回数据");
            });
            return;
        }
        
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        
        if (jsonErr) {
            NSLog(@"[DNS2] JSON解析失败: %@", jsonErr);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, -3, jsonErr.localizedDescription);
            });
            return;
        }
        
        NSInteger code = [json[@"code"] integerValue];
        NSString *msg = json[@"msg"] ?: @"";
        NSArray *targets = json[@"data"];
        
        if (code == 0 && targets && [targets isKindOfClass:[NSArray class]]) {
            NSLog(@"[DNS2] 获取到 %lu 个关注目标", (unsigned long)targets.count);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(targets, 0, nil);
            });
        } else if (code == 406) {
            NSLog(@"[DNS2] 暂无待关注目标");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, 406, msg);
            });
        } else {
            NSLog(@"[DNS2] 错误: code=%ld msg=%@", (long)code, msg);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, code, msg);
            });
        }
    }];
    [task resume];
}

#pragma mark - 上报结果

- (void)reportTask:(NSString *)uid
           success:(BOOL)success
            reason:(NSString *)reason
        completion:(void (^)(BOOL))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/report", [self baseURL]];
    NSURL *url = [NSURL URLWithString:urlStr];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:[self apiKey] forHTTPHeaderField:@"X-API-Key"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{
        @"device": [self deviceName],
        @"uid": uid ?: @"",
        @"ok": @(success),
        @"reason": reason ?: @""
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSLog(@"[DNS2] 上报: uid=%@ ok=%d", uid, success);
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        BOOL ok = (error == nil);
        if (error) {
            NSLog(@"[DNS2] 上报失败: %@", error);
        } else {
            NSLog(@"[DNS2] 上报成功: uid=%@", uid);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(ok);
        });
    }];
    [task resume];
}

@end
