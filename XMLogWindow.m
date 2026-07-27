//
//  XMLogWindow.m
//  dyDaemon - 熊猫平台版
//
//  屏幕顶部日志悬浮框
//  点击穿透（userInteractionEnabled = NO），不阻挡后续页面操作
//

#import "XMLogWindow.h"

#define MAX_LOG_LINES 5
#define LOG_FONT_SIZE 10

@interface XMLogWindow ()
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) NSMutableArray<NSString *> *logLines;
@end

@implementation XMLogWindow

+ (instancetype)sharedWindow {
    static XMLogWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMLogWindow alloc] initWithFrame:CGRectZero];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    CGFloat w = [UIScreen mainScreen].bounds.size.width;
    CGFloat h = 80;
    self = [super initWithFrame:CGRectMake(0, 0, w, h)];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        self.userInteractionEnabled = NO;  // ⚡ 点击穿透
        self.layer.zPosition = 9998;
        
        _logLines = [NSMutableArray array];
        
        _logLabel = [[UILabel alloc] initWithFrame:CGRectMake(6, 4, w - 12, h - 8)];
        _logLabel.textColor = [UIColor colorWithRed:0.7 green:0.9 blue:1.0 alpha:1.0];
        _logLabel.font = [UIFont fontWithName:@"Menlo" size:LOG_FONT_SIZE] ?: [UIFont systemFontOfSize:LOG_FONT_SIZE];
        _logLabel.numberOfLines = 0;
        _logLabel.textAlignment = NSTextAlignmentLeft;
        _logLabel.text = @"🐼 熊猫云控 v2.1 就绪";
        [self addSubview:_logLabel];
    }
    return self;
}

- (void)addLog:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!text.length) return;
        
        // 加时间戳
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
        NSString *ts = [df stringFromDate:[NSDate date]];
        NSString *line = [NSString stringWithFormat:@"%@ %@", ts, text];
        
        [self.logLines addObject:line];
        
        // 只保留最近 N 行
        while (self.logLines.count > MAX_LOG_LINES) {
            [self.logLines removeObjectAtIndex:0];
        }
        
        self.logLabel.text = [self.logLines componentsJoinedByString:@"\n"];
    });
}

- (void)show {
    self.hidden = NO;
}

- (void)hide {
    self.hidden = YES;
}

@end
