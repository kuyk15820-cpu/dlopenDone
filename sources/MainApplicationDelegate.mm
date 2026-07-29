#import "MainApplicationDelegate.h"
#import "RootViewController.h"
#import "SplashAnimation.h"
#import "RRReachability.h"
#import "MBProgressHUD.h"
#import "obfuscate.h"

@implementation MainApplicationDelegate {
    RootViewController *_rootViewController;
    UIViewController *_mainContainer; 
    MBProgressHUD *_networkHUD;
    BOOL _splashFinished; 
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkStatusChanged:)
                                                 name:kRRReachabilityChangedNotification
                                               object:nil];
    
    [[RRReachability sharedInstance] startNotifier];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    self.window.windowLevel = UIWindowLevelNormal;
    
    if (@available(iOS 13.0, *)) {
        self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    _mainContainer = [[UIViewController alloc] init];
    _mainContainer.view.backgroundColor = [UIColor blackColor];
    [self.window setRootViewController:_mainContainer];
    
    UIViewController *launchVC = [[UIViewController alloc] init];
    launchVC.view.backgroundColor = [UIColor blackColor];
    [_mainContainer addChildViewController:launchVC];
    [_mainContainer.view addSubview:launchVC.view];
    [launchVC didMoveToParentViewController:_mainContainer];
    
    [self.window makeKeyAndVisible];

    [SplashAnimation sharedInstance].targetWindow = self.window;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[SplashAnimation sharedInstance] showWithRepeatCount:1 completion:^{
            
            self->_rootViewController = [[RootViewController alloc] init];
            
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self->_rootViewController];
            navController.navigationBar.prefersLargeTitles = NO;
            navController.navigationBar.translucent = YES;
            
            [UIView transitionWithView:self->_mainContainer.view
                              duration:0.5
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                
                for (UIViewController *child in self->_mainContainer.childViewControllers) {
                    [child willMoveToParentViewController:nil];
                    [child.view removeFromSuperview];
                    [child removeFromParentViewController];
                }
                
                [self->_mainContainer addChildViewController:navController];
                navController.view.frame = self->_mainContainer.view.bounds;
                [self->_mainContainer.view addSubview:navController.view];
                [navController didMoveToParentViewController:self->_mainContainer];
                
            } completion:^(BOOL finished) {                 
                self->_splashFinished = YES;
                
                [self checkCurrentNetworkStatus];
            }];
            
        }];
    });

    return YES;
}

- (void)checkCurrentNetworkStatus {
    RRReachabilityStatus status = [[RRReachability sharedInstance] currentStatus];
    
    if (status == RRReachabilityStatusNotReachable) {
        if (!self->_networkHUD) {
            self->_networkHUD = [MBProgressHUD showHUDAddedTo:self.window animated:YES];
            self->_networkHUD.mode = MBProgressHUDModeIndeterminate;
            
            self->_networkHUD.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
            self->_networkHUD.backgroundView.color = [UIColor colorWithWhite:0.0f alpha:0.4f];
            self->_networkHUD.bezelView.blurEffectStyle = UIBlurEffectStyleDark;
            self->_networkHUD.contentColor = [UIColor whiteColor]; 
            self->_networkHUD.label.text = [NSString stringWithUTF8String:AY_OBFUSCATE("กำลังรอเครือข่าย...")];            
            self->_networkHUD.label.textColor = [UIColor lightGrayColor]; 
        }
    } else {
        if (self->_networkHUD) {
            [self->_networkHUD hideAnimated:YES];
            self->_networkHUD = nil;
        }
    }
}

- (void)networkStatusChanged:(NSNotification *)notification {
    if (!_splashFinished) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkCurrentNetworkStatus];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
