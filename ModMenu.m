// BSD Mod Menu for iOS - Objective-C dylib
// Inject into Brawl Stars IPA using insert_dylib (macOS only)
//
// Build on macOS:
//   clang -shared -o ModMenu.dylib ModMenu.m \
//     -framework UIKit -framework Foundation \
//     -install_name @rpath/ModMenu.dylib
//
// Inject:
//   insert_dylib --strip-codesig --inplace \
//     @rpath/ModMenu.dylib Payload/laser.app/laser
//
// Then copy ModMenu.dylib to Payload/laser.app/
// and re-sign the entire IPA.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ─── Config ──────────────────────────────────────────────────────────────────
#define MOD_NAME    @"BSD Mod"
#define MOD_VERSION @"1.0"
#define TRIGGER_TAP_COUNT 3   // Triple-tap anywhere to open menu

// ─── Forward declarations ────────────────────────────────────────────────────
@interface BSDModMenuViewController : UIViewController
@end

@interface BSDModMenuWindow : UIWindow
@end

// ─── Globals ─────────────────────────────────────────────────────────────────
static BSDModMenuWindow *g_menuWindow = nil;
static BOOL g_menuVisible = NO;

// ─── Menu Window ─────────────────────────────────────────────────────────────
@implementation BSDModMenuWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 100;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // Pass through taps outside the menu panel
    if (hit == self) return nil;
    return hit;
}

@end

// ─── Menu View Controller ────────────────────────────────────────────────────
@implementation BSDModMenuViewController {
    UIView       *_panel;
    UIScrollView *_scrollView;
    NSArray      *_mods;
    NSMutableDictionary *_modStates;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    // Mods list — add your own entries here
    _mods = @[
        @{@"name": @"BSDCsvPatches",    @"desc": @"Effects, music, themes patches",  @"key": @"BSDCsvPatches"},
        @{@"name": @"LeonCloneMod",     @"desc": @"Leon clone skin mod",              @"key": @"LeonCloneMod"},
        @{@"name": @"SecretPinsMod",    @"desc": @"Unlocks secret pins",              @"key": @"SecretPinsMod"},
        @{@"name": @"OldRankSystemMod", @"desc": @"Restores old rank system",         @"key": @"OldRankSystemMod"},
    ];

    _modStates = [NSMutableDictionary dictionary];
    // Load saved states
    for (NSDictionary *mod in _mods) {
        NSString *key = mod[@"key"];
        BOOL state = [[NSUserDefaults standardUserDefaults] boolForKey:[@"bsd_mod_" stringByAppendingString:key]];
        _modStates[key] = @(state);
    }

    [self buildUI];
}

- (void)buildUI {
    CGFloat panelW = 300;
    CGFloat panelH = MIN(500, self.view.bounds.size.height * 0.75);
    CGFloat panelX = (self.view.bounds.size.width - panelW) / 2;
    CGFloat panelY = (self.view.bounds.size.height - panelH) / 2;

    // Panel background
    _panel = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
    _panel.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:0.97];
    _panel.layer.cornerRadius = 16;
    _panel.layer.borderWidth = 1;
    _panel.layer.borderColor = [UIColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:0.8].CGColor;
    _panel.clipsToBounds = YES;

    // Shadow
    _panel.layer.shadowColor = [UIColor blackColor].CGColor;
    _panel.layer.shadowOpacity = 0.6;
    _panel.layer.shadowRadius = 12;
    _panel.layer.shadowOffset = CGSizeMake(0, 4);
    _panel.clipsToBounds = NO;

    [self.view addSubview:_panel];

    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 50)];
    header.backgroundColor = [UIColor colorWithRed:0.15 green:0.4 blue:0.9 alpha:1.0];
    [_panel addSubview:header];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, panelW - 60, 50)];
    titleLabel.text = [NSString stringWithFormat:@"%@ v%@", MOD_NAME, MOD_VERSION];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [header addSubview:titleLabel];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(panelW - 50, 0, 50, 50);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // Scroll view for mods
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, panelW, panelH - 50)];
    _scrollView.showsVerticalScrollIndicator = YES;
    [_panel addSubview:_scrollView];

    CGFloat y = 10;
    for (NSDictionary *mod in _mods) {
        UIView *row = [self buildModRow:mod atY:y width:panelW];
        [_scrollView addSubview:row];
        y += row.frame.size.height + 8;
    }
    _scrollView.contentSize = CGSizeMake(panelW, y + 10);

    // Tap outside to close
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeMenu)];
    bgTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:bgTap];
}

- (UIView *)buildModRow:(NSDictionary *)mod atY:(CGFloat)y width:(CGFloat)w {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(10, y, w - 20, 64)];
    row.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.25 alpha:1.0];
    row.layer.cornerRadius = 10;

    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 90, 22)];
    nameLabel.text = mod[@"name"];
    nameLabel.textColor = [UIColor whiteColor];
    nameLabel.font = [UIFont boldSystemFontOfSize:14];
    [row addSubview:nameLabel];

    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 30, w - 90, 26)];
    descLabel.text = mod[@"desc"];
    descLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    descLabel.font = [UIFont systemFontOfSize:11];
    descLabel.numberOfLines = 2;
    [row addSubview:descLabel];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.frame = CGRectMake(w - 80, 18, 51, 31);
    toggle.on = [_modStates[mod[@"key"]] boolValue];
    toggle.onTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    toggle.tag = [_mods indexOfObject:mod];
    [toggle addTarget:self action:@selector(toggleMod:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];

    return row;
}

- (void)toggleMod:(UISwitch *)sender {
    NSDictionary *mod = _mods[sender.tag];
    NSString *key = mod[@"key"];
    _modStates[key] = @(sender.on);
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:[@"bsd_mod_" stringByAppendingString:key]];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"[BSD] Mod '%@' -> %@", key, sender.on ? @"ON" : @"OFF");
}

- (void)closeMenu {
    [UIView animateWithDuration:0.25 animations:^{
        self->_panel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        self->_panel.alpha = 0;
    } completion:^(BOOL finished) {
        g_menuWindow.hidden = YES;
        g_menuVisible = NO;
        self->_panel.transform = CGAffineTransformIdentity;
        self->_panel.alpha = 1;
    }];
}

@end

// ─── Show / Hide ─────────────────────────────────────────────────────────────
static void BSDShowMenu(void) {
    if (!g_menuWindow) {
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (scene) {
            g_menuWindow = [[BSDModMenuWindow alloc] initWithWindowScene:scene];
        } else {
            g_menuWindow = [[BSDModMenuWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        g_menuWindow.rootViewController = [BSDModMenuViewController new];
    }

    g_menuWindow.frame = [UIScreen mainScreen].bounds;
    g_menuWindow.hidden = NO;
    g_menuVisible = YES;

    BSDModMenuViewController *vc = (BSDModMenuViewController *)g_menuWindow.rootViewController;
    vc.view.frame = g_menuWindow.bounds;
    [vc.view layoutIfNeeded];

    // Animate in
    UIView *panel = [vc.view.subviews firstObject];
    panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    panel.alpha = 0;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        panel.transform = CGAffineTransformIdentity;
        panel.alpha = 1;
    } completion:nil];
}

// ─── Triple-tap gesture hook ─────────────────────────────────────────────────
@interface BSDGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@end
@implementation BSDGestureDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
@end

static BSDGestureDelegate *g_gestureDelegate = nil;

static void BSDTryInstallGesture(int attempt) {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { keyWindow = w; break; }
    }
    if (!keyWindow) {
        if (attempt < 10) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BSDTryInstallGesture(attempt + 1);
            });
        }
        return;
    }
    g_gestureDelegate = [BSDGestureDelegate new];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[NSBlockOperation blockOperationWithBlock:^{
        if (g_menuVisible) return;
        BSDShowMenu();
    }] action:@selector(main)];
    tap.numberOfTapsRequired = TRIGGER_TAP_COUNT;
    tap.numberOfTouchesRequired = 2;
    tap.delegate = g_gestureDelegate;
    [keyWindow addGestureRecognizer:tap];
    NSLog(@"[BSD] Mod menu installed (attempt %d). Triple-tap with 2 fingers to open.", attempt);
}

static void BSDInstallGesture(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BSDTryInstallGesture(0);
    });
}

// ─── Constructor ─────────────────────────────────────────────────────────────
__attribute__((constructor))
static void BSDModInit(void) {
    @try {
        NSLog(@"[BSD] iOS Mod loaded - %@ v%@", MOD_NAME, MOD_VERSION);
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                BSDInstallGesture();
            } @catch (NSException *e) {
                NSLog(@"[BSD] Gesture install error: %@", e);
            }
        });
    } @catch (NSException *e) {
        NSLog(@"[BSD] Init error: %@", e);
    }
}
