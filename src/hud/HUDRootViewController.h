#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDRootViewController: UIViewController
- (void)resetLoopTimer;
- (void)pauseLoopTimer;
- (void)resumeLoopTimer;
- (void)reloadUserDefaults;

/**
 * 获取截图时是否隐藏小部件的设置
 * @return BOOL 是否在截图时隐藏小部件
 */
- (BOOL)hideWidgetsInScreenshot;
@end

NS_ASSUME_NONNULL_END