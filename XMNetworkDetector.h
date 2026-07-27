//
//  XMNetworkDetector.h
//  dyDaemon - 熊猫平台版
//
//  抖音网络服务探测器
//  自动检测当前抖音版本可用的网络请求类和方法
//

#import <Foundation/Foundation.h>

@interface XMNetworkDetector : NSObject

/// 单例
+ (instancetype)sharedDetector;

/// 开始探测（启动时调用一次）
- (void)startDetection;

/// 探测结果
@property (nonatomic, strong, readonly) NSString *detectedServiceClassName;
@property (nonatomic, strong, readonly) NSString *detectedMethodName;
@property (nonatomic, assign, readonly) BOOL isReady;

/// 发送请求（自动选择可用方案）
- (void)sendPOSTRequestWithURL:(NSString *)urlString
                      parameters:(NSDictionary *)params
                      completion:(void (^)(NSDictionary *response, NSError *error))completion;

/// 探测到的所有可用类（调试用）
- (NSDictionary *)allDetectedClasses;

@end
