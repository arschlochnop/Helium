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

/**
 * 处理截图事件
 * @param notification 截图通知对象
 */
- (void)handleScreenshot:(NSNotification *)notification;
@end

NS_ASSUME_NONNULL_END