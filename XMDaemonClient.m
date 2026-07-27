//
//  XMDaemonClient.m
//  dyDaemon - 熊猫平台版
//
//  Daemon API 客户端实现
//  daemon 运行在 localhost:12933（CH1/CH2 业务）
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

#pragma mark - CH1: followUser3

- (void)ch1_followUser:(NSString *)uid
                secUid:(NSString *)secUid
            completion:(void (^)(BOOL, NSString *))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/followUser3", kDaemonHost];
    NSDictionary *body = @{
        @"uid": uid ?: @"",
        @"sec_uid": secUid ?: @""
    };
    
    [XMGlobalManager log:@"🔵 CH1 关注: uid=%@", uid];
    [self post:urlStr body:body completion:completion];
}

#pragma mark - CH2: followUserByLive2

- (void)ch2_followUserByLive:(NSString *)uid
                  completion:(void (^)(BOOL, NSString *))completion {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/followUserByLive2", kDaemonHost];
    NSDictionary *body = @{
        @"uid": uid ?: @""
    };
    
    [XMGlobalManager log:@"🟢 CH2 关注: uid=%@", uid];
    [self post:urlStr body:body completion:completion];
}

#pragma mark - 通用 POST

- (void)post:(NSString *)urlStr
        body:(NSDictionary *)body
  completion:(void (^)(BOOL, NSString *))completion {
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.timeoutInterval = 15;
    
    NSError *err = nil;
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&err];
    if (err) {
        if (completion) completion(NO, err.localizedDescription);
        return;
    }
    
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
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, msg);
        });
    }];
    [task resume];
}

@end
