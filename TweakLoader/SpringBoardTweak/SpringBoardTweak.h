@import UIKit;

static void showAlert(NSString *title, NSString *message);

@interface SpringBoard : UIApplication
- (UIView *)statusBarForEmbeddedDisplay;
@end
