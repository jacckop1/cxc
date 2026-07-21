#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Updates the Kira Plus credit badge for the controller that has just appeared.
/// The implementation uses public UIKit APIs only and never walks Telegram's
/// private Swift/Texture object graph.
FOUNDATION_EXPORT void WGUpdateKiraBadgeForViewController(UIViewController *controller);

NS_ASSUME_NONNULL_END
