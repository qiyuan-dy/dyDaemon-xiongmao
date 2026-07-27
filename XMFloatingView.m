//
//  XMFloatingView.m
//  dyDaemon - 熊猫平台版
//
//  悬浮控制面板 — v2.1.0 可滑动 + 双数据源
//

#import "XMFloatingView.h"
#import "XMGlobalManager.h"
#import "XMOperationEngine.h"
#import "XMLogWindow.h"

// 颜色宏
#define RGB(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define RGBA(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]

@interface XMFloatingView ()

// 悬浮球
@property (nonatomic, strong) UIView *ballView;
@property (nonatomic, assign) CGPoint startPoint;

// 面板
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) BOOL isPanelShowing;

// 控制元素
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *startStopBtn;
@property (nonatomic, strong) UILabel *statsLabel;

// 数据源开关
@property (nonatomic, strong) UISwitch *dns2Switch;
@property (nonatomic, strong) UISwitch *pandaSwitch;

// DNS2 配置
@property (nonatomic, strong) UITextField *dns2HostField;
@property (nonatomic, strong) UITextField *dns2PortField;
@property (nonatomic, strong) UITextField *dns2KeyField;

// 熊猫配置
@property (nonatomic, strong) UITextField *pandaKeyField;

// 任务开关
@property (nonatomic, strong) UISwitch *followCH1Switch;
@property (nonatomic, strong) UITextField *followCH1Target;
@property (nonatomic, strong) UILabel *followCH1Progress;
@property (nonatomic, strong) UISwitch *followCH2Switch;
@property (nonatomic, strong) UITextField *followCH2Target;
@property (nonatomic, strong) UILabel *followCH2Progress;
@property (nonatomic, strong) UISwitch *followCH3Switch;
@property (nonatomic, strong) UITextField *followCH3Target;
@property (nonatomic, strong) UILabel *followCH3Progress;
@property (nonatomic, strong) UISwitch *diggSwitch;
@property (nonatomic, strong) UISwitch *collectSwitch;
@property (nonatomic, strong) UISwitch *shareSwitch;
@property (nonatomic, strong) UISwitch *commentSwitch;
@property (nonatomic, strong) UISwitch *playSwitch;

// 按钮
@property (nonatomic, strong) UIButton *configBtn;
@property (nonatomic, strong) UIButton *closeBtn;

@end

@implementation XMFloatingView

+ (instancetype)sharedView {
    static XMFloatingView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMFloatingView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.layer.zPosition = 9999;
        
        [self setupBallView];
        [self setupPanelView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStats)
                                                     name:@"XMStatsUpdated"
                                                   object:nil];
        
        // 监听日志
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLogMessage:)
                                                     name:@"XMLogMessage"
                                                   object:nil];
    }
    return self;
}

#pragma mark - 悬浮球

- (void)setupBallView {
    CGFloat ballSize = 42;
    self.ballView = [[UIView alloc] initWithFrame:CGRectMake(self.bounds.size.width - ballSize - 8, 150, ballSize, ballSize)];
    self.ballView.backgroundColor = RGBA(30, 140, 255, 0.92);
    self.ballView.layer.cornerRadius = ballSize / 2;
    self.ballView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.ballView.layer.shadowOffset = CGSizeMake(0, 2);
    self.ballView.layer.shadowOpacity = 0.3;
    self.ballView.layer.shadowRadius = 4;
    self.ballView.clipsToBounds = NO;
    self.ballView.userInteractionEnabled = YES;
    
    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, ballSize, ballSize)];
    icon.text = @"🐼";
    icon.font = [UIFont systemFontOfSize:22];
    icon.textAlignment = NSTextAlignmentCenter;
    [self.ballView addSubview:icon];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBallTapped)];
    [self.ballView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onBallPanned:)];
    [self.ballView addGestureRecognizer:pan];
    
    [self addSubview:self.ballView];
}

- (void)onBallTapped {
    if (self.isPanelShowing) [self hidePanel]; else [self showPanel];
}

- (void)onBallPanned:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan translationInView:self];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.startPoint = self.ballView.center;
    }
    
    CGFloat newX = self.startPoint.x + point.x;
    CGFloat newY = self.startPoint.y + point.y;
    CGFloat b = self.ballView.frame.size.width / 2;
    newX = MAX(b, MIN(newX, self.bounds.size.width - b));
    newY = MAX(b, MIN(newY, self.bounds.size.height - b));
    self.ballView.center = CGPointMake(newX, newY);
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat midX = self.bounds.size.width / 2;
        CGFloat snapX = (newX < midX) ? b : self.bounds.size.width - b;
        [UIView animateWithDuration:0.25 animations:^{
            self.ballView.center = CGPointMake(snapX, newY);
        }];
    }
}

#pragma mark - 面板基础

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    
    if (!self.panelView || self.panelView.hidden) {
        // 面板隐藏：只响应悬浮球点击
        if (hit && (hit == self.ballView || [hit isDescendantOfView:self.ballView])) {
            return hit;
        }
        return nil; // 其他区域穿透给抖音
    }
    
    // 面板显示：检查点击位置
    CGPoint panelPoint = [self convertPoint:point toView:self.panelView];
    BOOL insidePanel = [self.panelView pointInside:panelPoint withEvent:event];
    
    if (insidePanel) {
        // 面板内部：找实际命中控件
        UIView *panelHit = [self.panelView hitTest:panelPoint withEvent:event];
        if (panelHit) return panelHit;
        return hit; // 面板内空白
    }
    
    // 点击面板外 → 关闭面板 + 透传
    [self hidePanel];
    // 让触摸穿透到抖音（via pointInside override on the whole view）
    return nil;
}

- (void)dismissKeyboard {
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

- (void)setupPanelView {
    CGFloat pw = self.bounds.size.width - 20;
    CGFloat ph = self.bounds.size.height - 120;
    
    self.panelView = [[UIView alloc] initWithFrame:CGRectMake(10, 60, pw, ph)];
    self.panelView.backgroundColor = RGBA(15, 15, 20, 0.96);
    self.panelView.layer.cornerRadius = 14;
    self.panelView.clipsToBounds = YES;
    self.panelView.hidden = YES;
    
    // ScrollView
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.panelView.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.scrollView.alwaysBounceVertical = YES;
    [self.panelView addSubview:self.scrollView];
    
    CGFloat w = pw - 20;   // 内边距
    CGFloat x = 10;
    CGFloat y = 12;
    
    // === 标题 ===
    self.titleLabel = [self label:CGRectMake(x, y, w, 24) text:@"🐼 熊猫云控 v2.1" font:[UIFont boldSystemFontOfSize:15] align:NSTextAlignmentCenter];
    [self.scrollView addSubview:self.titleLabel];
    y += 32;
    
    // === 分区A: DNS2 数据源 ===
    y = [self addSectionLabel:@"📡 数据源1: DNS2 数据库" y:y w:w x:x];
    
    self.dns2Switch = [self addSwitchRow:@"启用 DNS2:" y:y w:w x:x tag:10];
    y += 32;
    
    self.dns2HostField = [self addField:@"服务器地址" y:y w:w x:x placeholder:@"64.90.8.209"];
    y += 38;
    
    self.dns2PortField = [self addField:@"端口" y:y w:w x:x placeholder:@"8081" keyboard:UIKeyboardTypeNumberPad];
    y += 38;
    
    self.dns2KeyField = [self addField:@"API Key" y:y w:w x:x placeholder:@"qiyuan…2026"];
    y += 46;
    
    // === 分区B: 熊猫平台 ===
    y = [self addSectionLabel:@"🐼 数据源2: 熊猫平台" y:y w:w x:x];
    
    self.pandaSwitch = [self addSwitchRow:@"启用熊猫:" y:y w:w x:x tag:11];
    y += 32;
    
    self.pandaKeyField = [self addField:@"熊猫 API Key" y:y w:w x:x placeholder:@"输入熊猫平台 Key"];
    y += 46;
    
    // === 关注三通道 ===
    y = [self addSectionLabel:@"❤️ 关注通道 (CH1/CH2/CH3)" y:y w:w x:x];
    
    y = [self addChannelRow:@"CH1 (followUser3)" y:y w:w x:x swPtr:&_followCH1Switch tfPtr:&_followCH1Target lbPtr:&_followCH1Progress tag:20];
    y = [self addChannelRow:@"CH2 (followByLive2)" y:y w:w x:x swPtr:&_followCH2Switch tfPtr:&_followCH2Target lbPtr:&_followCH2Progress tag:21];
    y = [self addChannelRow:@"CH3 (直连API)" y:y w:w x:x swPtr:&_followCH3Switch tfPtr:&_followCH3Target lbPtr:&_followCH3Progress tag:22];
    
    // === 分区C: 其他任务类型 ===
    y = [self addSectionLabel:@"⚙️ 其他任务" y:y w:w x:x];
    
    NSArray *tasks = @[
        @[@"点赞", @"", @1],
        @[@"收藏", @"", @3],
        @[@"分享", @"", @4],
        @[@"评论", @"", @5],
        @[@"播放", @"", @6],
    ];
    
    CGFloat colW = w / 2;
    for (NSInteger i = 0; i < tasks.count; i++) {
        NSInteger col = i % 2;
        NSInteger row = i / 2;
        CGFloat sx = x + col * colW;
        CGFloat sy = y + row * 32;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(sx, sy, 50, 30)];
        lbl.text = tasks[i][0];
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:13];
        [self.scrollView addSubview:lbl];
        
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(sx + 55, sy, 50, 30)];
        sw.tag = [tasks[i][2] integerValue];
        sw.onTintColor = RGB(30, 180, 100);
        [sw addTarget:self action:@selector(onTaskSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scrollView addSubview:sw];
        
        switch (sw.tag) {
            case 1: self.diggSwitch = sw; break;
            case 3: self.collectSwitch = sw; break;
            case 4: self.shareSwitch = sw; break;
            case 5: self.commentSwitch = sw; break;
            case 6: self.playSwitch = sw; break;
        }
    }
    y += ceil(tasks.count / 2.0) * 32 + 8;
    
    // === 分区D: 统计 ===
    [self addSectionLabel:@"📊 运行统计" y:y w:w x:x];
    y += 24;
    
    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 50)];
    self.statsLabel.textColor = RGB(180, 200, 220);
    self.statsLabel.font = [UIFont systemFontOfSize:11];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.text = @"总:0 赞:0 关:0 藏:0\n分:0 评:0 播:0";
    [self.scrollView addSubview:self.statsLabel];
    y += 56;
    
    // === 按钮区 ===
    self.startStopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startStopBtn.frame = CGRectMake(x, y, w, 40);
    [self.startStopBtn setTitle:@"▶ 开始任务" forState:UIControlStateNormal];
    [self.startStopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startStopBtn.backgroundColor = RGB(40, 170, 70);
    self.startStopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.startStopBtn.layer.cornerRadius = 8;
    [self.startStopBtn addTarget:self action:@selector(onStartStopTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.startStopBtn];
    y += 48;
    
    CGFloat btnW = (w - 8) / 2;
    self.configBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.configBtn.frame = CGRectMake(x, y, btnW, 36);
    [self.configBtn setTitle:@"💾 保存配置" forState:UIControlStateNormal];
    [self.configBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.configBtn.backgroundColor = RGBA(60, 60, 70, 0.8);
    self.configBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    self.configBtn.layer.cornerRadius = 7;
    [self.configBtn addTarget:self action:@selector(onSaveConfigTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.configBtn];
    
    self.closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeBtn.frame = CGRectMake(x + btnW + 8, y, btnW, 36);
    [self.closeBtn setTitle:@"✕ 关闭面板" forState:UIControlStateNormal];
    [self.closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeBtn.backgroundColor = RGBA(60, 60, 70, 0.8);
    self.closeBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    self.closeBtn.layer.cornerRadius = 7;
    [self.closeBtn addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.closeBtn];
    y += 50;
    
    self.scrollView.contentSize = CGSizeMake(w, y);
    [self addSubview:self.panelView];
}

#pragma mark - 辅助方法

#pragma mark - 辅助 UI 创建

- (UILabel *)label:(CGRect)frame text:(NSString *)text font:(UIFont *)font align:(NSTextAlignment)align {
    UILabel *lbl = [[UILabel alloc] initWithFrame:frame];
    lbl.text = text;
    lbl.font = font;
    lbl.textAlignment = align;
    lbl.textColor = [UIColor whiteColor];
    return lbl;
}

- (CGFloat)addSectionLabel:(NSString *)text y:(CGFloat)y w:(CGFloat)w x:(CGFloat)x {
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 1)];
    bar.backgroundColor = RGBA(60, 60, 80, 0.6);
    [self.scrollView addSubview:bar];
    y += 8;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, 20)];
    lbl.text = text;
    lbl.textColor = RGB(120, 180, 255);
    lbl.font = [UIFont boldSystemFontOfSize:12];
    [self.scrollView addSubview:lbl];
    y += 26;
    return y;
}

- (UISwitch *)addSwitchRow:(NSString *)label y:(CGFloat)y w:(CGFloat)w x:(CGFloat)x tag:(NSInteger)tag {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w - 60, 30)];
    lbl.text = label;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13];
    [self.scrollView addSubview:lbl];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(x + w - 55, y, 50, 30)];
    sw.onTintColor = RGB(30, 140, 255);
    sw.tag = tag;
    [sw addTarget:self action:@selector(onSourceSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:sw];
    
    return sw;
}

- (UITextField *)addField:(NSString *)label y:(CGFloat)y w:(CGFloat)w x:(CGFloat)x placeholder:(NSString *)ph {
    return [self addField:label y:y w:w x:x placeholder:ph keyboard:UIKeyboardTypeDefault];
}

- (UITextField *)addField:(NSString *)label y:(CGFloat)y w:(CGFloat)w x:(CGFloat)x placeholder:(NSString *)ph keyboard:(UIKeyboardType)kt {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, y, 70, 30)];
    lbl.text = label;
    lbl.textColor = RGB(160, 170, 190);
    lbl.font = [UIFont systemFontOfSize:11];
    [self.scrollView addSubview:lbl];
    
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(x + 72, y, w - 72, 30)];
    tf.placeholder = ph;
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:ph attributes:@{NSForegroundColorAttributeName: RGBA(100,100,120,0.6)}];
    tf.backgroundColor = RGBA(40, 42, 50, 0.8);
    tf.textColor = [UIColor whiteColor];
    tf.font = [UIFont systemFontOfSize:12];
    tf.layer.cornerRadius = 4;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 30)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    tf.keyboardType = kt;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    
    
    UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,320,44)];
    tb.barStyle = UIBarStyleBlack;
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@\"完成\" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    tb.items = @[flex, done];
    tf.inputAccessoryView = tb;
    
    return tf;
}

/// 添加关注通道行（开关 + 目标数量 + 进度）
- (CGFloat)addChannelRow:(NSString *)label y:(CGFloat)y w:(CGFloat)w x:(CGFloat)x swPtr:(UISwitch * __strong *)swPtr tfPtr:(UITextField * __strong *)tfPtr lbPtr:(UILabel * __strong *)lbPtr tag:(NSInteger)tag {
    // 开关
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(x, y, 50, 30)];
    sw.onTintColor = RGB(30, 140, 255);
    sw.tag = tag;
    [sw addTarget:self action:@selector(onTaskSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:sw];
    *swPtr = sw;
    
    // 标签
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x + 55, y, 120, 30)];
    lbl.text = label;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:12];
    [self.scrollView addSubview:lbl];
    
    // 数量输入
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(x + 170, y, 50, 30)];
    tf.placeholder = @"0";
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"0" attributes:@{NSForegroundColorAttributeName: RGBA(100,100,120,0.5)}];
    tf.backgroundColor = RGBA(40, 42, 50, 0.8);
    tf.textColor = [UIColor whiteColor];
    tf.font = [UIFont systemFontOfSize:12];
    tf.textAlignment = NSTextAlignmentCenter;
    tf.layer.cornerRadius = 4;
    tf.keyboardType = UIKeyboardTypeNumberPad;
    
    
    UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,320,44)];
    tb.barStyle = UIBarStyleBlack;
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@\"完成\" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    tb.items = @[flex, done];
    tf.inputAccessoryView = tb;
    *tfPtr = tf;
    
    // 进度
    UILabel *pb = [[UILabel alloc] initWithFrame:CGRectMake(x + w - 60, y, 55, 30)];
    pb.text = @"0/0";
    pb.textColor = RGB(255, 200, 50);
    pb.font = [UIFont boldSystemFontOfSize:12];
    pb.textAlignment = NSTextAlignmentRight;
    [self.scrollView addSubview:pb];
    *lbPtr = pb;
    
    return y + 34;
}

#pragma mark - 显示/隐藏

- (void)showPanel {
    [self refreshUI];
    self.panelView.hidden = NO;
    self.isPanelShowing = YES;
    [self.scrollView setContentOffset:CGPointZero animated:NO];
    [[XMLogWindow sharedWindow] show];
}

- (void)hidePanel {`n    [self dismissKeyboard];
    self.panelView.hidden = YES;
    self.isPanelShowing = NO;
    [[XMLogWindow sharedWindow] hide];
}

- (void)refreshUI {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    self.dns2Switch.on = gm.dns2Enabled;
    self.pandaSwitch.on = gm.pandaEnabled;
    self.dns2HostField.text = gm.dns2Host;
    self.dns2PortField.text = [NSString stringWithFormat:@"%ld", (long)gm.dns2Port];
    self.dns2KeyField.text = gm.dns2ApiKey;
    self.pandaKeyField.text = gm.apiKey;
    
    // 关注三通道
    self.followCH1Target.text = [NSString stringWithFormat:@"%ld", (long)gm.followCH1Target];
    self.followCH1Progress.text = [NSString stringWithFormat:@"%ld/%ld", (long)gm.followCH1Done, (long)gm.followCH1Target];
    
    self.followCH2Switch.on = gm.followCH2Enabled;
    self.followCH2Target.text = [NSString stringWithFormat:@"%ld", (long)gm.followCH2Target];
    self.followCH2Progress.text = [NSString stringWithFormat:@"%ld/%ld", (long)gm.followCH2Done, (long)gm.followCH2Target];
    
    self.followCH3Switch.on = gm.followCH3Enabled;
    self.followCH3Target.text = [NSString stringWithFormat:@"%ld", (long)gm.followCH3Target];
    self.followCH3Progress.text = [NSString stringWithFormat:@"%ld/%ld", (long)gm.followCH3Done, (long)gm.followCH3Target];
    
    self.diggSwitch.on = gm.diggEnabled;
    self.collectSwitch.on = gm.collectEnabled;
    self.shareSwitch.on = gm.shareEnabled;
    self.commentSwitch.on = gm.commentEnabled;
    self.playSwitch.on = gm.playEnabled;
    
    [self updateStats];
    [self updateStartButton];
}

- (void)updateStartButton {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    if (gm.isRunning) {
        [self.startStopBtn setTitle:@"■ 停止任务" forState:UIControlStateNormal];
        self.startStopBtn.backgroundColor = RGB(200, 50, 40);
    } else {
        [self.startStopBtn setTitle:@"▶ 开始任务" forState:UIControlStateNormal];
        self.startStopBtn.backgroundColor = RGB(40, 170, 70);
    }
}

#pragma mark - 数据源开关

- (void)onSourceSwitchChanged:(UISwitch *)sw {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    if (sw.tag == 10) gm.dns2Enabled = sw.on;
    else if (sw.tag == 11) gm.pandaEnabled = sw.on;
}

#pragma mark - 任务开关

- (void)onTaskSwitchChanged:(UISwitch *)sw {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    switch (sw.tag) {
        case 20: gm.followCH1Enabled = sw.on; break;
        case 21: gm.followCH2Enabled = sw.on; break;
        case 22: gm.followCH3Enabled = sw.on; break;
        case 1: gm.diggEnabled = sw.on; break;
        case 3: gm.collectEnabled = sw.on; break;
        case 4: gm.shareEnabled = sw.on; break;
        case 5: gm.commentEnabled = sw.on; break;
        case 6: gm.playEnabled = sw.on; break;
    }
}

#pragma mark - 按钮

- (void)onStartStopTapped {
    [self saveCurrentConfig];
    
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    if (gm.isRunning) {
        [gm stopAllTasks];
        [self updateStartButton];
        return;
    }
    
    // 检查数据源
    if (!gm.dns2Enabled && !gm.pandaEnabled) {
        [self alert:@"请至少启用一个数据源"];
        return;
    }
    
    // 获取用户信息
    [[NSClassFromString(@"XMOperationEngine") sharedInstance] fetchCurrentUserInfo];
    
    [gm startAllTasks];
    [self updateStartButton];
}

- (void)onSaveConfigTapped {
    [self saveCurrentConfig];
    [self alert:@"✅ 配置已保存"];
}

- (void)saveCurrentConfig {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    gm.dns2Enabled = self.dns2Switch.isOn;
    gm.pandaEnabled = self.pandaSwitch.isOn;
    gm.dns2Host = self.dns2HostField.text;
    gm.dns2Port = [self.dns2PortField.text integerValue] ?: 8081;
    gm.dns2ApiKey = self.dns2KeyField.text;
    gm.apiKey = self.pandaKeyField.text;
    
    gm.followCH1Enabled = self.followCH1Switch.isOn;
    gm.followCH2Enabled = self.followCH2Switch.isOn;
    gm.followCH3Enabled = self.followCH3Switch.isOn;
    gm.followCH1Target = [self.followCH1Target.text integerValue];
    gm.followCH2Target = [self.followCH2Target.text integerValue];
    gm.followCH3Target = [self.followCH3Target.text integerValue];
    
    gm.diggEnabled = self.diggSwitch.isOn;
    gm.collectEnabled = self.collectSwitch.isOn;
    gm.shareEnabled = self.shareSwitch.isOn;
    gm.commentEnabled = self.commentSwitch.isOn;
    gm.playEnabled = self.playSwitch.isOn;
    
    [gm saveConfig];
}

#pragma mark - 统计

- (void)onLogMessage:(NSNotification *)note {
    NSString *text = note.userInfo[@"text"];
    if (text) {
        [[XMLogWindow sharedWindow] addLog:text];
    }
}

- (void)updateStats {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    XMOperationEngine *engine = [NSClassFromString(@"XMOperationEngine") sharedInstance];
    
    self.followCH1Progress.text = [NSString stringWithFormat:@"%ld/%ld", (long)gm.followCH1Done, (long)gm.followCH1Target];
    self.followCH2Progress.text = [NSString stringWithFormat:@"%ld/%ld", (long)gm.followCH2Done, (long)gm.followCH2Target];
    self.followCH3Progress.text = [NSString stringWithFormat:@"%ld/%ld", (long)gm.followCH3Done, (long)gm.followCH3Target];
    
    NSString *s = [NSString stringWithFormat:
        @"✅ 总:%ld 赞:%ld 关:%ld 藏:%ld  分:%ld 评:%ld 播:%ld",
        (long)engine.totalTaskCount, (long)engine.diggSuccessCount,
        (long)engine.followSuccessCount, (long)engine.collectSuccessCount,
        (long)engine.shareSuccessCount, (long)engine.commentSuccessCount,
        (long)engine.playSuccessCount];
    self.statsLabel.text = s;
}

#pragma mark - 提示

- (void)alert:(NSString *)msg {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"熊猫云控" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    [vc presentViewController:ac animated:YES completion:nil];
}

#pragma mark - 公开方法

- (void)show {
    self.hidden = NO;
}

- (void)hide {
    self.hidden = YES;
}

@end
