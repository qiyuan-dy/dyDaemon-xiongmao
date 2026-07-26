//
//  XMFloatingView.m
//  dyDaemon - 熊猫平台版
//
//  悬浮窗控制面板实现
//

#import "XMFloatingView.h"
#import "XMGlobalManager.h"
#import "XMOperationEngine.h"

@interface XMFloatingView ()

@property (nonatomic, strong) UIView *ballView;           // 悬浮球
@property (nonatomic, strong) UIView *panelView;          // 控制面板
@property (nonatomic, assign) BOOL isPanelShowing;        // 面板是否展开
@property (nonatomic, assign) CGPoint startPoint;         // 拖动起点

// 控制面板元素
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *startStopBtn;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UISwitch *diggSwitch;
@property (nonatomic, strong) UISwitch *followSwitch;
@property (nonatomic, strong) UISwitch *collectSwitch;
@property (nonatomic, strong) UISwitch *shareSwitch;
@property (nonatomic, strong) UISwitch *commentSwitch;
@property (nonatomic, strong) UISwitch *playSwitch;
@property (nonatomic, strong) UISwitch *localSwitch;
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
        
        // 监听统计更新
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateStats)
                                                     name:@"XMStatsUpdated"
                                                   object:nil];
    }
    return self;
}

// Pass through touches outside ball/panel to underlying Douyin UI
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) {
        return nil;  // let touches pass through to Douyin
    }
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
    
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:self.ballView.bounds];
    iconLabel.text = @"🐼";
    iconLabel.font = [UIFont systemFontOfSize:24];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    [self.ballView addSubview:iconLabel];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBallTapped)];
    [self.ballView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onBallPanned:)];
    [self.ballView addGestureRecognizer:pan];
    
    [self addSubview:self.ballView];
}

- (void)onBallTapped {
    if (self.isPanelShowing) {
        [self hidePanel];
    } else {
        [self showPanel];
    }
}

- (void)onBallPanned:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan translationInView:self];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.startPoint = self.ballView.center;
    }
    
    CGFloat newX = self.startPoint.x + point.x;
    CGFloat newY = self.startPoint.y + point.y;
    
    // 边界限制
    CGFloat ballSize = self.ballView.frame.size.width;
    newX = MAX(ballSize/2, MIN(newX, self.bounds.size.width - ballSize/2));
    newY = MAX(ballSize/2, MIN(newY, self.bounds.size.height - ballSize/2));
    
    self.ballView.center = CGPointMake(newX, newY);
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        // 吸附到左右边缘
        CGFloat centerX = self.bounds.size.width / 2;
        CGFloat targetX = (newX < centerX) ? ballSize/2 : self.bounds.size.width - ballSize/2;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.ballView.center = CGPointMake(targetX, newY);
        }];
    }
}

#pragma mark - 控制面板

- (void)setupPanelView {
    CGFloat panelWidth = 280;
    CGFloat panelHeight = 430;
    CGFloat panelX = (self.bounds.size.width - panelWidth) / 2;
    CGFloat panelY = (self.bounds.size.height - panelHeight) / 2;
    
    self.panelView = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelWidth, panelHeight)];
    self.panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.panelView.layer.cornerRadius = 12;
    self.panelView.clipsToBounds = YES;
    self.panelView.hidden = YES;
    self.panelView.userInteractionEnabled = YES;
    
    // 标题
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, panelWidth - 20, 30)];
    self.titleLabel.text = @"🐼 熊猫云控 v1.0";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.panelView addSubview:self.titleLabel];
    
    // 启动/停止按钮
    self.startStopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startStopBtn.frame = CGRectMake(20, 50, panelWidth - 40, 40);
    [self.startStopBtn setTitle:@"▶ 开始任务" forState:UIControlStateNormal];
    [self.startStopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startStopBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
    self.startStopBtn.layer.cornerRadius = 6;
    [self.startStopBtn addTarget:self action:@selector(onStartStopTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.panelView addSubview:self.startStopBtn];
    
    // 统计显示
    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, panelWidth - 40, 60)];
    self.statsLabel.textColor = [UIColor whiteColor];
    self.statsLabel.font = [UIFont systemFontOfSize:12];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.text = @"总任务: 0 | 点赞: 0 | 关注: 0\n收藏: 0 | 分享: 0 | 评论: 0 | 播放: 0";
    [self.panelView addSubview:self.statsLabel];
    
    // 任务开关
    CGFloat switchY = 170;
    CGFloat labelWidth = 80;
    CGFloat switchWidth = 50;
    CGFloat rowHeight = 30;
    
    NSArray *taskTypes = @[
        @{@"name": @"点赞", @"key": @"digg", @"tag": @1},
        @{@"name": @"关注", @"key": @"follow", @"tag": @2},
        @{@"name": @"收藏", @"key": @"collect", @"tag": @3},
        @{@"name": @"分享", @"key": @"share", @"tag": @4},
        @{@"name": @"评论", @"key": @"comment", @"tag": @5},
        @{@"name": @"播放", @"key": @"play", @"tag": @6},
    ];
    
    // 两列布局
    for (NSInteger i = 0; i < taskTypes.count; i++) {
        NSInteger col = i % 2;
        NSInteger row = i / 2;
        CGFloat x = 20 + col * (panelWidth / 2);
        CGFloat y = switchY + row * rowHeight;
        
        NSDictionary *task = taskTypes[i];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, labelWidth, rowHeight)];
        label.text = task[@"name"];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:13];
        [self.panelView addSubview:label];
        
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(x + labelWidth + 5, y, switchWidth, rowHeight)];
        sw.tag = [task[@"tag"] integerValue];
        [sw addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.panelView addSubview:sw];
        
        if (i == 0) self.diggSwitch = sw;
        else if (i == 1) self.followSwitch = sw;
        else if (i == 2) self.collectSwitch = sw;
        else if (i == 3) self.shareSwitch = sw;
        else if (i == 4) self.commentSwitch = sw;
        else if (i == 5) self.playSwitch = sw;
    }
    
    // API Key 输入框
    self.apiKeyField = [[UITextField alloc] initWithFrame:CGRectMake(20, 280, panelWidth - 40, 35)];
    self.apiKeyField.placeholder = @"熊猫平台 API Key（本地模式不需要）";
    self.apiKeyField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.apiKeyField.textColor = [UIColor whiteColor];
    self.apiKeyField.font = [UIFont systemFontOfSize:12];
    self.apiKeyField.layer.cornerRadius = 4;
    self.apiKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 35)];
    self.apiKeyField.leftViewMode = UITextFieldViewModeAlways;
    [self.panelView addSubview:self.apiKeyField];
    
    // 本地服务器开关
    UILabel *localLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 320, 160, 30)];
    localLabel.text = @"🏠 优先本地服务器";
    localLabel.textColor = [UIColor whiteColor];
    localLabel.font = [UIFont systemFontOfSize:13];
    [self.panelView addSubview:localLabel];
    
    self.localSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(panelWidth - 70, 320, 50, 30)];
    [self.localSwitch addTarget:self action:@selector(onLocalSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:self.localSwitch];
    
    // 保存配置按钮
    self.configBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.configBtn.frame = CGRectMake(20, 360, (panelWidth - 50) / 2, 35);
    [self.configBtn setTitle:@"保存配置" forState:UIControlStateNormal];
    [self.configBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.configBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.configBtn.layer.cornerRadius = 6;
    [self.configBtn addTarget:self action:@selector(onSaveConfigTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.panelView addSubview:self.configBtn];
    
    // 关闭按钮
    self.closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeBtn.frame = CGRectMake(20 + (panelWidth - 50) / 2 + 10, 360, (panelWidth - 50) / 2, 35);
    [self.closeBtn setTitle:@"关闭面板" forState:UIControlStateNormal];
    [self.closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.closeBtn.layer.cornerRadius = 6;
    [self.closeBtn addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.panelView addSubview:self.closeBtn];
    
    [self addSubview:self.panelView];
}

- (void)showPanel {
    self.panelView.hidden = NO;
    self.isPanelShowing = YES;
    
    // 加载当前配置
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    self.diggSwitch.on = gm.diggEnabled;
    self.followSwitch.on = gm.followEnabled;
    self.collectSwitch.on = gm.collectEnabled;
    self.shareSwitch.on = gm.shareEnabled;
    self.commentSwitch.on = gm.commentEnabled;
    self.playSwitch.on = gm.playEnabled;
    self.localSwitch.on = gm.useLocalServer;
    self.apiKeyField.text = gm.apiKey;
    
    [self updateStats];
}

- (void)hidePanel {
    self.panelView.hidden = YES;
    self.isPanelShowing = NO;
}

#pragma mark - 按钮事件

- (void)onStartStopTapped {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    if (gm.isRunning) {
        [gm stopAllTasks];
        [self.startStopBtn setTitle:@"▶ 开始任务" forState:UIControlStateNormal];
        self.startStopBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0];
    } else {
        // 先保存配置再启动
        [self saveCurrentConfig];
        
        // 获取用户信息
        [[NSClassFromString(@"XMOperationEngine") sharedInstance] fetchCurrentUserInfo];
        
        [gm startAllTasks];
        [self.startStopBtn setTitle:@"■ 停止任务" forState:UIControlStateNormal];
        self.startStopBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    }
}

- (void)onSwitchChanged:(UISwitch *)sw {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    switch (sw.tag) {
        case 1: gm.diggEnabled = sw.on; break;
        case 2: gm.followEnabled = sw.on; break;
        case 3: gm.collectEnabled = sw.on; break;
        case 4: gm.shareEnabled = sw.on; break;
        case 5: gm.commentEnabled = sw.on; break;
        case 6: gm.playEnabled = sw.on; break;
        default: break;
    }
}

- (void)onLocalSwitchChanged:(UISwitch *)sw {
    [XMGlobalManager sharedInstance].useLocalServer = sw.on;
}

- (void)onSaveConfigTapped {
    [self saveCurrentConfig];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"配置已保存" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    
    // 在最顶层控制器显示
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)saveCurrentConfig {
    XMGlobalManager *gm = [XMGlobalManager sharedInstance];
    
    gm.apiKey = self.apiKeyField.text;
    gm.diggEnabled = self.diggSwitch.isOn;
    gm.followEnabled = self.followSwitch.isOn;
    gm.collectEnabled = self.collectSwitch.isOn;
    gm.shareEnabled = self.shareSwitch.isOn;
    gm.commentEnabled = self.commentSwitch.isOn;
    gm.playEnabled = self.playSwitch.isOn;
    
    [gm saveConfig];
    
    NSLog(@"[熊猫] 配置已保存");
}

#pragma mark - 统计更新

- (void)updateStats {
    XMOperationEngine *engine = [NSClassFromString(@"XMOperationEngine") sharedInstance];
    
    NSString *statsText = [NSString stringWithFormat:
        @"总任务: %ld | 点赞: %ld | 关注: %ld\n收藏: %ld | 分享: %ld | 评论: %ld | 播放: %ld",
        (long)engine.totalTaskCount,
        (long)engine.diggSuccessCount,
        (long)engine.followSuccessCount,
        (long)engine.collectSuccessCount,
        (long)engine.shareSuccessCount,
        (long)engine.commentSuccessCount,
        (long)engine.playSuccessCount
    ];
    
    self.statsLabel.text = statsText;
}

#pragma mark - 显示/隐藏

- (void)show {
    self.hidden = NO;
}

- (void)hide {
    self.hidden = YES;
}

@end
