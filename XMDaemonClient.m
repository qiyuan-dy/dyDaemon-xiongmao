//
//  XMDaemonClient.m
//  dyDaemon - 熊猫平台版
//
//  Daemon API 客户端实现
//  daemon 运行在 localhost:12933（CH1/CH2 业务）— GET + query params
//

#import "XMDaemonClient.h"
#import "XMGlobalManager.h"

static NSString * const kDaemonHost = @"http://127.0.0.1:12933";

@interface XMDaemonClient ()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation XMDaemonClient

+ (instancetype)sharedInstance {
    static XMDaemonClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMDaemonClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 15;
        cfg.timeoutIntervalForResource = 20;
        self.session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

#pragma mark - CH1: followUser3 (GET /followUser3?user_id=xxx&sec_id=xxx&channel=13)

- (void)ch1_followUser:(NSString *)uid
                secUid:(NSString *)secUid
            completion:(void (^)(BOOL, NSString *))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/followUser3?user_id=%@&sec_id=%@&channel=13",
                        kDaemonHost,
                        [self urlEncode:uid],
                        [self urlEncode:secUid]];
    
    [XMGlobalManager log:@"🔵 CH1 daemon关注: uid=%@", uid];
    [self get:urlStr completion:completion];
}

#pragma mark - CH2: followUserByLive2 (GET /followUserByLive2?user_id=xxx&sec_id=xxx)

- (void)ch2_followUserByLive:(NSString *)uid
                  completion:(void (^)(BOOL, NSString *))completion {
    
    // CH2 只需 user_id，sec_id 可选（传空也行）
    NSString *urlStr = [NSString stringWithFormat:@"%@/followUserByLive2?user_id=%@",
                        kDaemonHost,
                        [self urlEncode:uid]];
    
    [XMGlobalManager log:@"🟢 CH2 daemon关注: uid=%@", uid];
    [self get:urlStr completion:completion];
}

#pragma mark - 通用 GET

- (void)get:(NSString *)urlStr
 completion:(void (^)(BOOL, NSString *))completion {
    
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO, @"URL格式错误");
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 15;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, error.localizedDescription);
            });
            return;
        }
        
        BOOL success = NO;
        NSString *msg = @"";
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json) {
                NSInteger code = [json[@"code"] integerValue];
                success = (code == 0);
                msg = json[@"msg"] ?: json[@"status_msg"] ?: @"";
            } else {
                // 可能是纯文本响应
                NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (text && text.length > 0) {
                    success = ([text containsString:@"ok"] || [text containsString:@"success"]);
                    msg = text;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, msg);
        });
    }];
    [task resume];
}

#pragma mark - 辅助

- (NSString *)urlEncode:(NSString *)str {
    if (!str) return @"";
    return [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
}

@end
