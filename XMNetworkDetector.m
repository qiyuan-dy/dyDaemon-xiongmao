//
//  XMNetworkDetector.m
//  dyDaemon - 熊猫平台版
//
//  抖音网络服务探测器实现
//  自动检测当前抖音版本可用的网络请求类
//  支持版本：抖音 25.x ~ 39.x+
//

#import "XMNetworkDetector.h"
#import <objc/runtime.h>

@interface XMNetworkDetector ()

@property (nonatomic, strong) NSString *detectedServiceClassName;
@property (nonatomic, strong) NSString *detectedMethodName;
@property (nonatomic, assign) BOOL isReady;
@property (nonatomic, strong) NSMutableDictionary *detectionResults;

// 探测到的目标对象
@property (nonatomic, strong) id detectedServiceInstance;
@property (nonatomic, assign) SEL detectedSelector;

@end

@implementation XMNetworkDetector

+ (instancetype)sharedDetector {
    static XMNetworkDetector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMNetworkDetector alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _detectionResults = [NSMutableDictionary dictionary];
        _isReady = NO;
    }
    return self;
}

#pragma mark - 候选类列表（按优先级排序）
// 这些是抖音不同版本可能存在的网络服务类名

- (NSArray *)candidateServiceClasses {
    return @[
        // 高优先级（常见）
        @"AWENetworkService",
        @"TTNetworkManager",
        @"TTAccountNetworkManager",
        @"AWEAPIManager",
        @"IESHTTPService",
        @"IESNetworkManager",
        // 中优先级
        @"AWEHTTPRequestOperationManager",
        @"AWENetworkRequestManager",
        @"AWEHTTPSessionManager",
        @"BDNNetworkManager",
        @"XIGNetworkService",
        // 低优先级（特殊版本）
        @"AWENewNetworkService",
        @"AWEAccountNetworkManager",
        @"DYNetworkService",
        @"DouyinNetworkManager",
    ];
}

- (NSArray *)candidateMethodNames {
    return @[
        // 标准 AFNetworking 风格
        @"POST:parameters:headers:progress:success:failure:",
        @"POST:parameters:progress:success:failure:",
        @"POST:parameters:success:failure:",
        // 抖音自定义
        @"POST:params:success:failure:",
        @"requestWithURL:params:method:success:failure:",
        @"sendRequest:parameters:method:completion:",
        // GET 备选
        @"GET:parameters:progress:success:failure:",
        @"GET:parameters:success:failure:",
    ];
}

#pragma mark - 开始探测

- (void)startDetection {
    NSLog(@"[熊猫-探测] 开始检测抖音网络服务类...");
    
    __block BOOL found = NO;
    
    // 遍历所有候选类
    for (NSString *className in [self candidateServiceClasses]) {
        Class cls = NSClassFromString(className);
        if (!cls) {
            self.detectionResults[className] = @"类不存在";
            continue;
        }
        
        // 检查单例方法
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if (![cls respondsToSelector:sharedSel]) {
            sharedSel = NSSelectorFromString(@"sharedManager");
        }
        if (![cls respondsToSelector:sharedSel]) {
            sharedSel = NSSelectorFromString(@"defaultManager");
        }
        if (![cls respondsToSelector:sharedSel]) {
            sharedSel = NSSelectorFromString(@"sharedService");
        }
        
        if (![cls respondsToSelector:sharedSel]) {
            self.detectionResults[className] = @"无单例方法";
            continue;
        }
        
        // 获取单例
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id instance = [cls performSelector:sharedSel];
        #pragma clang diagnostic pop
        
        if (!instance) {
            self.detectionResults[className] = @"单例返回nil";
            continue;
        }
        
        // 检查是否有 POST 方法
        for (NSString *methodName in [self candidateMethodNames]) {
            SEL methodSel = NSSelectorFromString(methodName);
            
            if ([instance respondsToSelector:methodSel]) {
                // 找到可用的类和方法！
                self.detectedServiceClassName = className;
                self.detectedMethodName = methodName;
                self.detectedServiceInstance = instance;
                self.detectedSelector = methodSel;
                self.isReady = YES;
                
                self.detectionResults[className] = [NSString stringWithFormat:@"✅ 可用 - 方法: %@", methodName];
                
                NSLog(@"[熊猫-探测] ✅ 找到可用网络服务: %@, 方法: %@", className, methodName);
                
                found = YES;
                break;
            }
        }
        
        if (found) break;
        
        // 没有找到标准POST方法，记录所有方法名（调试用）
        NSMutableArray *methodList = [NSMutableArray array];
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(object_getClass(instance), &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(sel);
            if ([name containsString:@"POST"] || [name containsString:@"post"] || 
                [name containsString:@"request"] || [name containsString:@"Request"]) {
                [methodList addObject:name];
            }
        }
        free(methods);
        
        if (methodList.count > 0) {
            self.detectionResults[className] = [NSString stringWithFormat:@"类存在，方法列表: %@", methodList];
        } else {
            self.detectionResults[className] = @"类存在，无匹配方法";
        }
    }
    
    if (!found) {
        NSLog(@"[熊猫-探测] ❌ 未找到可用的网络服务类，将使用兜底方案");
    }
    
    // 打印探测结果摘要
    NSLog(@"[熊猫-探测] 探测完成，结果: %@", self.isReady ? @"成功" : @"失败");
}

#pragma mark - 发送请求

- (void)sendPOSTRequestWithURL:(NSString *)urlString
                      parameters:(NSDictionary *)params
                      completion:(void (^)(NSDictionary *response, NSError *error))completion {
    
    if (self.isReady && self.detectedServiceInstance && self.detectedSelector) {
        [self sendRequestWithDetectedService:urlString parameters:params completion:completion];
    } else {
        // 兜底方案
        [self sendFallbackRequest:urlString parameters:params completion:completion];
    }
}

- (void)sendRequestWithDetectedService:(NSString *)urlString
                            parameters:(NSDictionary *)params
                            completion:(void (^)(NSDictionary *, NSError *))completion {
    
    id instance = self.detectedServiceInstance;
    SEL selector = self.detectedSelector;
    NSString *methodName = self.detectedMethodName;
    NSInteger paramCount = [[methodName componentsSeparatedByString:@":"] count] - 1;
    
    NSLog(@"[熊猫-网络] 使用 %@ 发送请求: %@", self.detectedServiceClassName, urlString);
    
    // 构建 success / failure block
    void (^successBlock)(NSURLSessionDataTask *, id) = ^(NSURLSessionDataTask *task, id responseObject) {
        NSDictionary *dict = nil;
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            dict = responseObject;
        } else if ([responseObject isKindOfClass:[NSData class]]) {
            dict = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
        } else if (responseObject) {
            // 尝试其他转换
            dict = @{@"response": responseObject};
        }
        if (completion) completion(dict, nil);
    };
    
    void (^failureBlock)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"[熊猫-网络] 请求失败: %@", error);
        if (completion) completion(nil, error);
    };
    
    // 根据参数数量调用不同版本的方法
    // 常见签名：POST:parameters:headers:progress:success:failure: (6参数)
    //          POST:parameters:progress:success:failure: (5参数)
    //          POST:parameters:success:failure: (4参数)
    
    NSMethodSignature *sig = [instance methodSignatureForSelector:selector];
    if (!sig) {
        NSLog(@"[熊猫-网络] 无法获取方法签名");
        if (completion) completion(nil, [NSError errorWithDomain:@"XMNetwork" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法获取方法签名"}]);
        return;
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
    invocation.target = instance;
    invocation.selector = selector;
    
    // 设置参数（从 index 2 开始，0是self，1是_cmd）
    NSInteger argIndex = 2;
    
    // 参数1: URL
    NSString *url = urlString;
    [invocation setArgument:&url atIndex:argIndex++];
    
    // 参数2: parameters
    NSDictionary *parameters = params;
    [invocation setArgument:&parameters atIndex:argIndex++];
    
    // 根据 paramCount 决定后续参数
    if (paramCount >= 6) {
        // POST:parameters:headers:progress:success:failure:
        NSDictionary *headers = nil;
        void *progress = NULL;
        [invocation setArgument:&headers atIndex:argIndex++];  // headers
        [invocation setArgument:&progress atIndex:argIndex++]; // progress
        [invocation setArgument:&successBlock atIndex:argIndex++]; // success
        [invocation setArgument:&failureBlock atIndex:argIndex++]; // failure
    } else if (paramCount >= 5) {
        // POST:parameters:progress:success:failure:
        void *progress = NULL;
        [invocation setArgument:&progress atIndex:argIndex++]; // progress
        [invocation setArgument:&successBlock atIndex:argIndex++]; // success
        [invocation setArgument:&failureBlock atIndex:argIndex++]; // failure
    } else if (paramCount >= 4) {
        // POST:parameters:success:failure:
        [invocation setArgument:&successBlock atIndex:argIndex++]; // success
        [invocation setArgument:&failureBlock atIndex:argIndex++]; // failure
    } else {
        NSLog(@"[熊猫-网络] 不支持的方法参数数量: %ld", (long)paramCount);
        if (completion) completion(nil, [NSError errorWithDomain:@"XMNetwork" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"不支持的方法签名"}]);
        return;
    }
    
    [invocation invoke];
}

#pragma mark - 兜底方案

- (void)sendFallbackRequest:(NSString *)urlString
                 parameters:(NSDictionary *)params
                 completion:(void (^)(NSDictionary *, NSError *))completion {
    
    NSLog(@"[熊猫-网络] 使用兜底方案发送请求: %@", urlString);
    
    NSMutableArray *paramPairs = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *pair = [NSString stringWithFormat:@"%@=%@", key, obj];
        [paramPairs addObject:pair];
    }];
    NSString *bodyStr = [paramPairs componentsJoinedByString:@"&"];
    NSData *bodyData = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    // 从 Cookie 存储中获取抖音 Cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSDictionary *cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    if (cookieHeaders[@"Cookie"]) {
        [request setValue:cookieHeaders[@"Cookie"] forHTTPHeaderField:@"Cookie"];
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (completion) completion(json, nil);
        } else {
            if (completion) completion(nil, [NSError errorWithDomain:@"XMNetwork" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"无返回数据"}]);
        }
    }];
    [task resume];
}

#pragma mark - 调试信息

- (NSDictionary *)allDetectedClasses {
    return [self.detectionResults copy];
}

@end
