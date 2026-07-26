//
//  XMDaemonClient.m
//  dyDaemon - 熊猫平台版 v2.0
//
//  通过 HTTP 调用本地 daemon API
//  daemon 端口: 12933 (业务操作) / 10010 (配置读写)
//

#import "XMDaemonClient.h"

static NSString *const kDaemonOpsBase  = @"http://127.0.0.1:12933";
static NSString *const kDaemonCfgBase  = @"http://127.0.0.1:10010";
static NSTimeInterval const kTimeout   = 15.0;

@implementation XMDaemonClient

+ (instancetype)sharedClient {
    static XMDaemonClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[XMDaemonClient alloc] init]; });
    return instance;
}

#pragma mark - Internal

- (void)getURL:(NSString *)urlString completion:(XMDaemonCallback)completion {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(NO, nil, @"invalid url");
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:kTimeout];
    [req setHTTPMethod:@"GET"];
    [req setValue:@"dyDaemon/2.0" forHTTPHeaderField:@"User-Agent"];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req
                                            completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) {
            if (completion) completion(NO, nil, err.localizedDescription);
            return;
        }
        if (!data) {
            if (completion) completion(NO, nil, @"empty response");
            return;
        }
        NSError *jsonErr;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
            // 纯文本响应也接受
            NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (completion) completion(YES, str ? @{@"raw": str} : @{}, nil);
            return;
        }
        if (completion) completion(YES, (NSDictionary *)obj, nil);
    }];
    [task resume];
}

#pragma mark - 业务操作

- (void)followUserCh1:(NSString *)userId secUid:(NSString *)secUid completion:(XMDaemonCallback)completion {
    NSString *uid = userId ?: @"";
    NSString *sid = secUid ?: @"";
    NSString *encUid = [uid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: uid;
    NSString *encSid = [sid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: sid;
    NSString *url = [NSString stringWithFormat:@"%@/followUser3?user_id=%@&sec_id=%@&channel=13", kDaemonOpsBase, encUid, encSid];
    NSLog(@"[熊猫-Daemon] CH1 follow: %@", url);
    [self getURL:url completion:completion];
}

- (void)followUserCh2:(NSString *)userId secUid:(NSString *)secUid completion:(XMDaemonCallback)completion {
    NSString *uid = userId ?: @"";
    NSString *sid = secUid ?: @"";
    NSString *encUid = [uid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: uid;
    NSString *encSid = [sid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: sid;
    NSString *url = [NSString stringWithFormat:@"%@/followUserByLive2?user_id=%@&sec_id=%@", kDaemonOpsBase, encUid, encSid];
    NSLog(@"[熊猫-Daemon] CH2 follow: %@", url);
    [self getURL:url completion:completion];
}

- (void)digg:(NSString *)awemeId completion:(XMDaemonCallback)completion {
    NSString *aid = awemeId ?: @"";
    NSString *encAid = [aid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: aid;
    NSString *url = [NSString stringWithFormat:@"%@/digg?aweme_id=%@", kDaemonOpsBase, encAid];
    NSLog(@"[熊猫-Daemon] digg: %@", url);
    [self getURL:url completion:completion];
}

- (void)otherUser:(NSString *)userId secUid:(NSString *)secUid completion:(XMDaemonCallback)completion {
    NSString *uid = userId ?: @"";
    NSString *sid = secUid ?: @"";
    NSString *encUid = [uid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: uid;
    NSString *encSid = [sid stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: sid;
    NSString *url = [NSString stringWithFormat:@"%@/otherUser?user_id=%@&sec_id=%@", kDaemonOpsBase, encUid, encSid];
    [self getURL:url completion:completion];
}

#pragma mark - 配置读写

- (void)getConfigValue:(NSString *)key completion:(void(^)(NSString * _Nullable))completion {
    NSString *encKey = [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: key;
    NSString *url = [NSString stringWithFormat:@"%@/getValue?key=%@", kDaemonCfgBase, encKey];
    [self getURL:url completion:^(BOOL ok, NSDictionary *result, NSString *err) {
        if (completion) {
            NSString *val = ok ? (result[@"raw"] ?: result[@"value"]) : nil;
            completion(val);
        }
    }];
}

- (void)setConfigValue:(NSString *)key stringValue:(NSString *)value completion:(void(^)(BOOL))completion {
    NSString *encKey = [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: key;
    NSString *encVal = [value stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: value;
    NSString *url = [NSString stringWithFormat:@"%@/settingValue?key=%@&val=%@", kDaemonCfgBase, encKey, encVal];
    [self getURL:url completion:^(BOOL ok, NSDictionary *result, NSString *err) {
        if (completion) completion(ok);
    }];
}

- (void)setConfigValue:(NSString *)key intValue:(NSInteger)value completion:(void(^)(BOOL))completion {
    NSString *encKey = [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: key;
    NSString *url = [NSString stringWithFormat:@"%@/settingValue?key=%@&val=%ld", kDaemonCfgBase, encKey, (long)value];
    [self getURL:url completion:^(BOOL ok, NSDictionary *result, NSString *err) {
        if (completion) completion(ok);
    }];
}

- (void)syncConfig:(void(^)(BOOL))completion {
    NSString *url = [NSString stringWithFormat:@"%@/syncLocalSetting", kDaemonCfgBase];
    [self getURL:url completion:^(BOOL ok, NSDictionary *result, NSString *err) {
        if (completion) completion(ok);
    }];
}

@end
