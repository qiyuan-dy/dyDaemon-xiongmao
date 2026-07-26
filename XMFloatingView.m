//
//  XMFloatingView.m
//  dyDaemon - 熊猫平台版 v1.1
//
//  悬浮窗控制面板 — 三通道关注 + 可调间隔
//

#import "XMFloatingView.h"
#import "XMGlobalManager.h"
#import "XMOperationEngine.h"

@interface XMFloatingView ()
@property (nonatomic, strong) UIView *ballView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, assign) BOOL isPanelShowing;
@property (nonatomic, assign) CGPoint startPoint;

// UI 元素
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *startStopBtn;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UISwitch *ch1Switch;
@property (nonatomic, strong) UISwitch *ch2Switch;
@property (nonatomic, strong) UISwitch *ch3Switch;
@property (nonatomic, strong) UISwitch *diggSwitch;
@property (nonatomic, strong) UISwitch *localSwitch;
@property (nonatomic, strong) UITextField *minIntervalField;
@property (nonatomic, strong) UITextField *maxIntervalField;
@property (nonatomic, strong) UITextField *apiKeyField;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStats) name:@"XMStatsUpdated" object:nil];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return nil;
    return hit;
}

#pragma mark - 悬浮球

- (void)setupBallView {
    CGFloat ballSize = 50;
    self.ballView = [[UIView alloc] initWithFrame:CGRectMake(0, 100, ballSize, ballSize)];
    self.ballView.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
    self.ballView.layer.cornerRadius = ballSize / 2;
    self.ballView.clipsToBounds = YES;
    self.ballView.userInteractionEnabled = YES;
    
    UILabel *icon = [[UILabel alloc] initWithFrame:self.ballView.bounds];
    icon.text = @"🐼"; icon.font = [UIFont systemFontOfSize:24];
    icon.textAlignment = NSTextAlignmentCenter;
    [self.ballView addSubview:icon];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBallTapped)];
    [self.ballView addGestureRecognizer:tap];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onBallPanned:)];
    [self.ballView addGestureRecognizer:pan];
    [self addSubview:self.ballView];
}

- (void)onBallTapped {
    if (self.isPanelShowing) [self hidePanel];
    else [self showPanel];
}

- (void)onBallPanned:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan translationInView:self];
    if (pan.state == UIGestureRecognizerStateBegan) self.startPoint = self.ballView.center;
    CGFloat newX = self.startPoint.x + point.x;
    CGFloat newY = self.startPoint.y + point.y;
    CGFloat bs = self.ballView.frame.size.width;
    newX = MAX(bs/2, MIN(newX, self.bounds.size.width - bs/2));
    newY = MAX(bs/2, MIN(newY, self.bounds.size.height - bs/2));
    self.ballView.center = CGPointMake(newX, newY);
    if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat cx = self.bounds.size.width / 2;
        CGFloat tx = (newX < cx) ? bs/2 : self.bounds.size.width - bs/2;
        [UIView animateWithDuration:0.3 animations:^{ self.ballView.center = CGPointMake(tx, newY); }];
    }
}

#pragma mark - 控制面板

- (void)setupPanelView {
    CGFloat pw = 300;
    CGFloat ph = 460;
    self.panelView = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width-pw)/2, (self.bounds.size.height-ph)/2, pw, ph)];
    self.panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.panelView.layer.cornerRadius = 12;
    self.panelView.clipsToBounds = YES;
    self.panelView.hidden = YES;
    self.panelView.userInteractionEnabled = YES;
    
    // 标题
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, pw-20, 28)];
    self.titleLabel.text = @"🐼 熊猫云控 v1.1";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.panelView addSubview:self.titleLabel];
    
    // 启动/停止
    self.startStopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startStopBtn.frame = CGRectMake(15, 42, pw-30, 36);
    [self.startStopBtn setTitle:@"▶ 开始任务" forState:UIControlStateNormal];
    [self.startStopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startStopBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
    self.startStopBtn.layer.cornerRadius = 6;
    [self.startStopBtn addTarget:self action:@selector(onStartStopTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.panelView addSubview:self.startStopBtn];
    
    // 统计
    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 84, pw-30, 40)];
    self.statsLabel.textColor = [UIColor whiteColor];
    self.statsLabel.font = [UIFont systemFontOfSize:10];
    self.statsLabel.numberOfLines = 2;
    [self.panelView addSubview:self.statsLabel];
    
    // ---- 关注通道开关 ----
    CGFloat sy = 130;
    CGFloat lw = 160;
    CGFloat sw = 51;
    CGFloat rh = 32;
    
    // CH1
    [self addSwitchLabel:@"关注 CH1(followUser3)" x:15 y:sy pw:pw];
    self.ch1Switch = [self makeSwitchAt:CGPointMake(pw-70, sy)];
    self.ch1Switch.tag = 1;
    [self.ch1Switch addTarget:self action:@selector(onChSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:self.ch1Switch];
    
    // CH2
    [self addSwitchLabel:@"关注 CH2(followUserByLive2)" x:15 y:sy+rh pw:pw];
    self.ch2Switch = [self makeSwitchAt:CGPointMake(pw-70, sy+rh)];
    self.ch2Switch.tag = 2;
    [self.ch2Switch addTarget:self action:@selector(onChSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:self.ch2Switch];
    
    // CH3
    [self addSwitchLabel:@"关注 CH3(标准API)" x:15 y:sy+rh*2 pw:pw];
    self.ch3Switch = [self makeSwitchAt:CGPointMake(pw-70, sy+rh*2)];
    self.ch3Switch.tag = 3;
    [self.ch3Switch addTarget:self action:@selector(onChSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:self.ch3Switch];
    
    // Digg
    [self addSwitchLabel:@"点赞(预留)" x:15 y:sy+rh*3 pw:pw];
    self.diggSwitch = [self makeSwitchAt:CGPointMake(pw-70, sy+rh*3)];
    self.diggSwitch.tag = 10;
    [self.diggSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:self.diggSwitch];
    
    // ---- 间隔设置 ----
    CGFloat iy = sy + rh*4 + 8;
    UILabel *intervalTitle = [self makeLabel:@"⏱ 关注间隔(秒):" x:15 y:iy w:150 h:24 font:[UIFont boldSystemFontOfSize:12]];
    [self.panelView addSubview:intervalTitle];
    
    UILabel *minL = [self makeLabel:@"最小:" x:15 y:iy+26 w:35 h:28 font:[UIFont systemFontOfSize:12]];
    [self.panelView addSubview:minL];
    self.minIntervalField = [self makeTextFieldAt:CGRectMake(52, iy+26, 55, 28) placeholder:@"5"];
    [self.panelView addSubview:self.minIntervalField];
    
    UILabel *maxL = [self makeLabel:@"最大:" x:112 y:iy+26 w:35 h:28 font:[UIFont systemFontOfSize:12]];
    [self.panelView addSubview:maxL];
    self.maxIntervalField = [self makeTextFieldAt:CGRectMake(149, iy+26, 55, 28) placeholder:@"15"];
    [self.panelView addSubview:self.maxIntervalField];
    
    // ---- 本地服务器开关 ----
    CGFloat ly = iy + 60;
    UILabel *localL = [self makeLabel:@"🏠 优先本地服务器" x:15 y:ly w:160 h:28 font:[UIFont systemFontOfSize:12]];
    [self.panelView addSubview:localL];
    self.localSwitch = [self makeSwitchAt:CGPointMake(pw-70, ly)];
    [self.localSwitch addTarget:self action:@selector(onLocalSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:self.localSwitch];
    
    // ---- API Key ----
    CGFloat ay = ly + 34;
    self.apiKeyField = [self makeTextFieldAt:CGRectMake(15, ay, pw-30, 30) placeholder:@"API Key(本地模式无需填写)"];
    self.apiKeyField.font = [UIFont systemFontOfSize:10];
    [self.panelView addSubview:self.apiKeyField];
    
    // ---- 按钮 ----
    CGFloat by = ay + 38;
    self.configBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.configBtn.frame = CGRectMake(15, by, (pw-40)/2, 32);
    [self.configBtn setTitle:@"保存配置" forState:UIControlStateNormal];
    [self.configBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.configBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.configBtn.layer.cornerRadius = 5;
    [self.configBtn addTarget:self action:@selector(onSaveConfigTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.panelView addSubview:self.configBtn];
    
    self.closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeBtn.frame = CGRectMake(25+(pw-40)/2, by, (pw-40)/2, 32);
    [self.closeBtn setTitle:@"关闭面板" forState:UIControlStateNormal];
    [self.closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.closeBtn.layer.cornerRadius = 5;
    [self.closeBtn addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.panelView addSubview:self.closeBtn];
    
    [self addSubview:self.panelView];
}

#pragma mark - 辅助方法

- (UISwitch *)makeSwitchAt:(CGPoint)pt {
    UISwitch *sw = [[UISwitch alloc] init];
    sw.center = CGPointMake(pt.x + 25, pt.y + 16);
    return sw;
}

- (void)addSwitchLabel:(NSString *)text x:(CGFloat)x y:(CGFloat)y pw:(CGFloat)pw {
    UILabel *lbl = [self makeLabel:text x:x y:y w:pw-80 h:32 font:[UIFont systemFontOfSize:12]];
    [self.panelView addSubview:lbl];
}

- (UILabel *)makeLabel:(NSString *)text x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h font:(UIFont *)font {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, h)];
    l.text = text; l.textColor = [UIColor whiteColor]; l.font = font;
    return l;
}

- (UITextField *)makeTextFieldAt:(CGRect)frame placeholder:(NSString *)ph {
    UITextField *tf = [[UITextField alloc] initWithFrame:frame];
    tf.placeholder = ph;
    tf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    tf.textColor = [UIColor whiteColor];
    tf.font = [UIFont systemFontOfSize:12];
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.layer.cornerRadius = 4;
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, frame.size.height)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    return tf;
}

#pragma mark - 显示/隐藏

- (void)showPanel {
    self.panelView.hidden = NO;
    self.isPanelShowing = YES;
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    self.ch1Switch.on = gm.followCh1Enabled;
    self.ch2Switch.on = gm.followCh2Enabled;
    self.ch3Switch.on = gm.followCh3Enabled;
    self.diggSwitch.on = gm.diggEnabled;
    self.localSwitch.on = gm.useLocalServer;
    self.minIntervalField.text = [NSString stringWithFormat:@"%ld", (long)gm.minInterval];
    self.maxIntervalField.text = [NSString stringWithFormat:@"%ld", (long)gm.maxInterval];
    self.apiKeyField.text = gm.apiKey ?: @"";
    [self updateStats];
}

- (void)hidePanel { self.panelView.hidden = YES; self.isPanelShowing = NO; }

#pragma mark - 事件

- (void)onStartStopTapped {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    if (gm.isRunning) {
        [gm stopAllTasks];
        [self.startStopBtn setTitle:@"▶ 开始任务" forState:UIControlStateNormal];
        self.startStopBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
    } else {
        [self saveCurrentConfig];
        [[NSClassFromString(@"XMOperationEngine") sharedInstance] fetchCurrentUserInfo];
        [gm startAllTasks];
        [self.startStopBtn setTitle:@"■ 停止任务" forState:UIControlStateNormal];
        self.startStopBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    }
}

- (void)onChSwitchChanged:(UISwitch *)sw {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    switch (sw.tag) {
        case 1: gm.followCh1Enabled = sw.on; break;
        case 2: gm.followCh2Enabled = sw.on; break;
        case 3: gm.followCh3Enabled = sw.on; break;
    }
}

- (void)onSwitchChanged:(UISwitch *)sw {
    if (sw.tag == 10) [XMGlobalManager sharedInstance].diggEnabled = sw.on;
}

- (void)onLocalSwitchChanged:(UISwitch *)sw {
    [XMGlobalManager sharedInstance].useLocalServer = sw.on;
}

- (void)onSaveConfigTapped {
    [self saveCurrentConfig];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"配置已保存" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *rvc = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rvc presentViewController:alert animated:YES completion:nil];
}

- (void)saveCurrentConfig {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    gm.apiKey = self.apiKeyField.text;
    gm.followCh1Enabled = self.ch1Switch.isOn;
    gm.followCh2Enabled = self.ch2Switch.isOn;
    gm.followCh3Enabled = self.ch3Switch.isOn;
    gm.diggEnabled = self.diggSwitch.isOn;
    gm.minInterval = [self.minIntervalField.text integerValue] ?: 5;
    gm.maxInterval = [self.maxIntervalField.text integerValue] ?: 15;
    if (gm.minInterval < 1) gm.minInterval = 1;
    if (gm.maxInterval < gm.minInterval) gm.maxInterval = gm.minInterval;
    [gm saveConfig];
    NSLog(@"[熊猫] 配置已保存: CH1=%d CH2=%d CH3=%d 间隔=%ld-%lds",
          gm.followCh1Enabled, gm.followCh2Enabled, gm.followCh3Enabled,
          (long)gm.minInterval, (long)gm.maxInterval);
}

- (void)updateStats {
    XMOperationEngine *e = [NSClassFromString(@"XMOperationEngine") sharedInstance];
    self.statsLabel.text = [NSString stringWithFormat:
        @"总:%ld 关注:%ld 点赞:%ld | 收藏:%ld 分享:%ld 评论:%ld 播放:%ld",
        (long)e.totalTaskCount, (long)e.followSuccessCount, (long)e.diggSuccessCount,
        (long)e.collectSuccessCount, (long)e.shareSuccessCount,
        (long)e.commentSuccessCount, (long)e.playSuccessCount];
}

- (void)show { self.hidden = NO; }
- (void)hide { self.hidden = YES; }

@end
