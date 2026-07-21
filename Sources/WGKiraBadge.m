#import "WGKiraBadge.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const WGKiraTelegramUsername = @"iKiraPlus";
static NSString *const WGKiraBadgeCenterXKey = @"WGKiraBadgeCenterXRatio";
static NSString *const WGKiraBadgeCenterYKey = @"WGKiraBadgeCenterYRatio";

#pragma mark - Safe page detection

static NSString *WGKiraNormalizedText(NSString *text) {
    if (![text isKindOfClass:NSString.class]) {
        return @"";
    }

    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.lowercaseString;
}

static BOOL WGKiraIsFeaturesTitle(NSString *text) {
    NSString *normalized = WGKiraNormalizedText(text);
    if (normalized.length == 0) {
        return NO;
    }

    static NSSet<NSString *> *titles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        titles = [NSSet setWithArray:@[
            @"whitegram features",
            @"whitegram settings",
            @"مميزات وايت كرام",
            @"ميزات وايت كرام",
            @"إعدادات وايت كرام",
            @"اعدادات وايت كرام",
            @"funciones de whitegram",
            @"características de whitegram",
            @"fonctionnalités de whitegram",
            @"recursos do whitegram",
            @"قابلیت‌های وایت‌گرام",
            @"ویژگی‌های وایت‌گرام"
        ]];
    });
    return [titles containsObject:normalized];
}

static BOOL WGKiraClassLooksLikeFeaturesController(UIViewController *controller) {
    NSString *className = NSStringFromClass(controller.class).lowercaseString;
    if (className.length == 0 || [className rangeOfString:@"whitegram"].location == NSNotFound) {
        return NO;
    }

    return [className rangeOfString:@"feature"].location != NSNotFound ||
           [className rangeOfString:@"setting"].location != NSNotFound ||
           [className rangeOfString:@"preference"].location != NSNotFound;
}

/// Public-UIKit-only fallback. It is intentionally bounded and checks only the
/// top navigation area of the appeared controller. No Swift ivars/selectors.
static BOOL WGKiraViewContainsSafeTitle(UIView *view,
                                        UIView *rootView,
                                        NSUInteger depth,
                                        NSUInteger *visitedCount) {
    if (!view || !rootView || depth > 12 || !visitedCount || *visitedCount >= 300 ||
        view.hidden || view.alpha < 0.01) {
        return NO;
    }

    (*visitedCount)++;

    CGRect frame = [view convertRect:view.bounds toView:rootView];
    CGFloat maximumY = rootView.safeAreaInsets.top + 120.0;
    BOOL isNearTop = CGRectGetMinY(frame) <= maximumY;

    if (isNearTop) {
        NSString *candidate = nil;
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            candidate = label.attributedText.string ?: label.text;
        } else if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            candidate = [button attributedTitleForState:UIControlStateNormal].string ?:
                        [button titleForState:UIControlStateNormal];
        }

        if (WGKiraIsFeaturesTitle(candidate)) {
            return YES;
        }
    }

    for (UIView *subview in view.subviews) {
        CGRect subviewFrame = [subview convertRect:subview.bounds toView:rootView];
        if (CGRectGetMinY(subviewFrame) > maximumY) {
            continue;
        }
        if (WGKiraViewContainsSafeTitle(subview, rootView, depth + 1, visitedCount)) {
            return YES;
        }
    }

    return NO;
}

static BOOL WGKiraControllerIsFeaturesPage(UIViewController *controller) {
    if (!controller || controller.isBeingDismissed || controller.isMovingFromParentViewController) {
        return NO;
    }

    if (WGKiraIsFeaturesTitle(controller.title) ||
        WGKiraIsFeaturesTitle(controller.navigationItem.title) ||
        WGKiraClassLooksLikeFeaturesController(controller)) {
        return YES;
    }

    UIView *view = controller.viewIfLoaded;
    if (!view || !view.window) {
        return NO;
    }

    UIView *titleView = controller.navigationItem.titleView;
    if (titleView) {
        NSUInteger titleVisited = 0;
        if (WGKiraViewContainsSafeTitle(titleView, view, 0, &titleVisited)) {
            return YES;
        }
    }

    NSUInteger visited = 0;
    return WGKiraViewContainsSafeTitle(view, view, 0, &visited);
}

#pragma mark - Movable credit badge

@interface WGKiraBadgeView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, assign) CGPoint panStartCenter;
@property (nonatomic, strong) UILabel *markLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *usernameLabel;
@end

@implementation WGKiraBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    self.layer.cornerRadius = 18.0;
    self.layer.borderWidth = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.22;
    self.layer.shadowRadius = 10.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    self.clipsToBounds = NO;

    _markLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _markLabel.text = @"K+";
    _markLabel.textAlignment = NSTextAlignmentCenter;
    _markLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightHeavy];
    _markLabel.textColor = UIColor.whiteColor;
    _markLabel.backgroundColor = [UIColor colorWithRed:0.20 green:0.55 blue:1.0 alpha:1.0];
    _markLabel.layer.cornerRadius = 16.0;
    _markLabel.clipsToBounds = YES;
    [self addSubview:_markLabel];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.text = @"كيرا بلس";
    _nameLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    _nameLabel.textColor = UIColor.whiteColor;
    _nameLabel.textAlignment = NSTextAlignmentNatural;
    _nameLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self addSubview:_nameLabel];

    _usernameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _usernameLabel.text = @"@iKiraPlus";
    _usernameLabel.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightMedium];
    _usernameLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    _usernameLabel.textAlignment = NSTextAlignmentLeft;
    [self addSubview:_usernameLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(wg_openTelegram:)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(wg_handlePan:)];
    pan.maximumNumberOfTouches = 1;
    pan.delegate = self;
    [self addGestureRecognizer:pan];

    [tap requireGestureRecognizerToFail:pan];

    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"كيرا بلس، @iKiraPlus";
    self.accessibilityHint = @"اضغط لفتح حساب تيليغرام، أو اسحب لتحريك الشعار";
    self.accessibilityTraits = UIAccessibilityTraitButton;

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat height = CGRectGetHeight(self.bounds);
    self.markLabel.frame = CGRectMake(10.0, (height - 32.0) * 0.5, 32.0, 32.0);
    CGFloat textX = 50.0;
    CGFloat textWidth = MAX(0.0, CGRectGetWidth(self.bounds) - textX - 12.0);
    self.nameLabel.frame = CGRectMake(textX, 8.0, textWidth, 19.0);
    self.usernameLabel.frame = CGRectMake(textX, 27.0, textWidth, 16.0);
}

- (void)wg_openTelegram:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }

    UIApplication *application = UIApplication.sharedApplication;
    NSURL *telegramURL = [NSURL URLWithString:[NSString stringWithFormat:@"tg://resolve?domain=%@",
                                               WGKiraTelegramUsername]];
    NSURL *webURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://t.me/%@",
                                          WGKiraTelegramUsername]];

    if (!telegramURL || !webURL) {
        return;
    }

    [application openURL:telegramURL options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            [application openURL:webURL options:@{} completionHandler:nil];
        }
    }];
}

- (void)wg_handlePan:(UIPanGestureRecognizer *)recognizer {
    UIView *container = self.superview;
    if (!container) {
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.panStartCenter = self.center;
        [UIView animateWithDuration:0.12 animations:^{
            self.transform = CGAffineTransformMakeScale(1.04, 1.04);
        }];
    }

    if (recognizer.state == UIGestureRecognizerStateChanged ||
        recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled) {
        CGPoint translation = [recognizer translationInView:container];
        CGPoint proposed = CGPointMake(self.panStartCenter.x + translation.x,
                                       self.panStartCenter.y + translation.y);
        self.center = [self wg_clampedCenter:proposed inView:container];
    }

    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.16 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
        [self wg_savePositionInView:container];
    }
}

- (CGPoint)wg_clampedCenter:(CGPoint)center inView:(UIView *)container {
    UIEdgeInsets safe = container.safeAreaInsets;
    CGFloat margin = 10.0;
    CGFloat halfWidth = CGRectGetWidth(self.bounds) * 0.5;
    CGFloat halfHeight = CGRectGetHeight(self.bounds) * 0.5;

    CGFloat minimumX = safe.left + margin + halfWidth;
    CGFloat maximumX = CGRectGetWidth(container.bounds) - safe.right - margin - halfWidth;
    CGFloat minimumY = safe.top + margin + halfHeight;
    CGFloat maximumY = CGRectGetHeight(container.bounds) - safe.bottom - margin - halfHeight;

    if (maximumX < minimumX) {
        maximumX = minimumX;
    }
    if (maximumY < minimumY) {
        maximumY = minimumY;
    }

    return CGPointMake(MIN(MAX(center.x, minimumX), maximumX),
                       MIN(MAX(center.y, minimumY), maximumY));
}

- (void)wg_restoreOrSetDefaultPositionInView:(UIView *)container {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id savedX = [defaults objectForKey:WGKiraBadgeCenterXKey];
    id savedY = [defaults objectForKey:WGKiraBadgeCenterYKey];

    CGPoint center;
    if ([savedX respondsToSelector:@selector(doubleValue)] &&
        [savedY respondsToSelector:@selector(doubleValue)]) {
        CGFloat xRatio = MIN(MAX([savedX doubleValue], 0.0), 1.0);
        CGFloat yRatio = MIN(MAX([savedY doubleValue], 0.0), 1.0);
        center = CGPointMake(CGRectGetWidth(container.bounds) * xRatio,
                             CGRectGetHeight(container.bounds) * yRatio);
    } else {
        UIEdgeInsets safe = container.safeAreaInsets;
        center = CGPointMake(CGRectGetWidth(container.bounds) - safe.right -
                             CGRectGetWidth(self.bounds) * 0.5 - 12.0,
                             safe.top + CGRectGetHeight(self.bounds) * 0.5 + 62.0);
    }

    self.center = [self wg_clampedCenter:center inView:container];
}

- (void)wg_savePositionInView:(UIView *)container {
    CGFloat width = MAX(CGRectGetWidth(container.bounds), 1.0);
    CGFloat height = MAX(CGRectGetHeight(container.bounds), 1.0);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:self.center.x / width forKey:WGKiraBadgeCenterXKey];
    [defaults setDouble:self.center.y / height forKey:WGKiraBadgeCenterYKey];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return NO;
}

@end

static WGKiraBadgeView *WGKiraBadge = nil;

void WGUpdateKiraBadgeForViewController(UIViewController *controller) {
    if (!controller) {
        return;
    }

    if (!NSThread.isMainThread) {
        __weak UIViewController *weakController = controller;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *strongController = weakController;
            if (strongController) {
                WGUpdateKiraBadgeForViewController(strongController);
            }
        });
        return;
    }

    BOOL shouldShow = WGKiraControllerIsFeaturesPage(controller);
    UIView *container = controller.viewIfLoaded;

    // The badge is attached to the features controller's own view. When the
    // user leaves that page, UIKit removes that view from the visible hierarchy,
    // so unrelated child controllers do not need to hide or move the badge.
    if (!shouldShow || !container || !container.window) {
        return;
    }

    if (!WGKiraBadge) {
        WGKiraBadge = [[WGKiraBadgeView alloc] initWithFrame:CGRectMake(0.0, 0.0, 154.0, 50.0)];
    }

    if (WGKiraBadge.superview != container) {
        [WGKiraBadge removeFromSuperview];
        [container addSubview:WGKiraBadge];
        [WGKiraBadge wg_restoreOrSetDefaultPositionInView:container];
    } else {
        WGKiraBadge.center = [WGKiraBadge wg_clampedCenter:WGKiraBadge.center inView:container];
    }

    WGKiraBadge.hidden = NO;
    [container bringSubviewToFront:WGKiraBadge];
}
