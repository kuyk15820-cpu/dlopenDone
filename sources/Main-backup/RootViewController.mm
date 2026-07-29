#import "RootViewController.h"
#import "SettingsViewController.h"
#import <ffmpegkit/FFmpegKit.h>
#import <PhotosUI/PhotosUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "obfuscate.h"
#import "MBProgressHUD.h"
#import "FTNotificationIndicator.h"
#import "RRReachability.h"
#import "TOMSMorphingLabel.h"

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource, PHPickerViewControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *menuItems;
@property (nonatomic, assign) float currentScale;
@property (nonatomic, strong) MBProgressHUD *hud;

// สำหรับระบบเช็คและดาวน์โหลดอัปเดต
@property (nonatomic, assign) BOOL isUpdateAvailable;
@property (nonatomic, strong) NSString *latestVersionDownloadUrl;
@property (nonatomic, strong) NSTimer *updateCheckTimer;

@end

@implementation RootViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait; 
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ตั้งค่าพื้นหลังรวมเป็นสีดำสนิทสนมกับ Dark Mode 
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.currentScale = 2.0f; // ค่าเริ่มต้นของ itsscale
    
    if (self.navigationController) {
        self.navigationController.navigationBarHidden = NO;
        self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
        
        // --- เปลี่ยนเป็นสไตล์ Large Title ของระบบ iOS ---
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
        self.title = [NSString stringWithUTF8String:AY_OBFUSCATE("FXTool")];
        
        // --- เพิ่มปุ่ม Info ขวาบน ของระบบ ---
        UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
        [infoButton addTarget:self action:@selector(infoButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
        self.navigationItem.rightBarButtonItem = infoItem;
        // -------------------------------------------------------------------
    }

    [self setupData];
    [self setupTableView];
    [self setupSpinner];
    
    // --- สั่งอุ่นเครื่อง (Warm-up) หน้า SettingsView รอไว้เงียบ ๆ ทันทีเมื่อเข้าหน้านี้ ---
    // ลบการทำงานระบบเก่าที่อ้างอิงคลาสฝั่ง Swift ออกตามคำสั่งเรียกใช้ SettingsViewController

    // ตั้งค่าและเริ่มระบบตรวจจับการเปลี่ยนแปลงของอินเทอร์เน็ต
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNetworkChanged:)
                                                 name:kRRReachabilityChangedNotification
                                               object:nil];
    [[RRReachability sharedInstance] startNotifier];

    // เริ่มระบบตรวจสอบเวอร์ชันใหม่จาก GitHub
    [self checkAppUpdate];
    
    // สั่งให้ทำงานซ้ำทุกๆ 30 วินาที เพื่อเช็คค่าเรียลไทม์
    self.updateCheckTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                             target:self
                                                           selector:@selector(checkAppUpdate)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)dealloc {
    // ปิดระบบแจ้งเตือนและตัวตรวจจับอินเทอร์เน็ตเพื่อความปลอดภัยของหน่วยความจำ
    [[RRReachability sharedInstance] stopNotifier];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // ทำลายล้าง Timer เมื่อปิดหน้านี้
    if (self.updateCheckTimer) {
        [self.updateCheckTimer invalidate];
        self.updateCheckTimer = nil;
    }
}

- (void)handleNetworkChanged:(NSNotification *)notification {
    RRReachabilityStatus status = [RRReachability sharedInstance].currentStatus;
    if (status == RRReachabilityStatusReachable && !self.isUpdateAvailable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self checkAppUpdate];
        });
    }
}

// Action เมื่อผู้ใช้แตะปุ่ม Info ขวาบน
- (void)infoButtonTapped {
    // เปลี่ยนมาใช้งานและเปิดหน้า SettingsViewController ดั้งเดิมตามคำสั่ง
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    if (self.navigationController) {
        [self.navigationController pushViewController:settingsVC animated:YES];
    } else {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:navController animated:YES completion:nil];
    }
}

- (void)setupData {
    self.menuItems = @[
        @{
            @"title": [NSString stringWithUTF8String:AY_OBFUSCATE("เลือกวิดีโอจากคลังภาพ")], 
            @"subtitle": [NSString stringWithUTF8String:AY_OBFUSCATE("ระบบจะยืดเวลาวิดีโอให้เล่นช้าลง 2 เท่า")]
        }
    ];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.separatorColor = [UIColor separatorColor];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.view addSubview:self.tableView];
}

- (void)setupSpinner {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                window = windowScene.windows.firstObject;
                break;
            }
        }
    }
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }

    self.hud = [[MBProgressHUD alloc] initWithView:window];
    self.hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    self.hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.4f];
    [window addSubview:self.hud];
}

#pragma mark - UITableView Quick Setup (Dark Style)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // ถ้าระบบพบการอัปเดตใหม่ จะทำการขยายเป็น 2 เซกชัน เพื่อแสดงเมนูอัปเดตด้านล่างต่อจาก TableView เดิม
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isUpdateAvailable) {
        return 1; // ถูกแทนที่ด้วยตารางเมนูอัปเดตอย่างเดียวทันที
    }
    return self.menuItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        if (self.isUpdateAvailable) {
            return [NSString stringWithUTF8String:AY_OBFUSCATE("ติดตั้งเวอร์ชันล่าสุดเพื่อปลดล็อคฟีเจอร์")];
        }
        return [NSString stringWithUTF8String:AY_OBFUSCATE("เครื่องมือจัดการวิดีโอ")];
    }
    if (section == 1) {
        return [NSString stringWithUTF8String:AY_OBFUSCATE("มีอัปเดตใหม่")];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isUpdateAvailable) {
        static NSString *updateCellIdentifier = @"UpdateCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:updateCellIdentifier];
        
        TOMSMorphingLabel *morphLabel = nil;
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:updateCellIdentifier];
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            
            // ใช้ข้อความจำลองสั้นๆ เพื่อให้ระบบจัดตำแหน่งเลย์เอาต์ (layoutSubviews) พื้นฐานของ textLabel
            cell.textLabel.text = @" ";
            cell.textLabel.textColor = [UIColor systemPinkColor];
            [cell layoutIfNeeded];
            
            // สร้าง MorphingLabel ให้เกาะตามพิกัดและเฟรมจริงของ textLabel ดั้งเดิมของระบบเป๊ะๆ
            morphLabel = [[TOMSMorphingLabel alloc] initWithFrame:cell.textLabel.frame];
            morphLabel.font = cell.textLabel.font;
            morphLabel.textColor = cell.textLabel.textColor;
            morphLabel.tag = 999;
            
            // ซ่อนข้อความจำลองของระบบเดิมเพื่อเลี่ยงอักษรซ้อนกัน
            cell.textLabel.alpha = 0.0f;
            
            [cell.contentView addSubview:morphLabel];
        } else {
            morphLabel = (TOMSMorphingLabel *)[cell.contentView viewWithTag:999];
            // ทำการซิงค์เฟรมอีกครั้งเผื่อกรณีหน้าจอมีการเปลี่ยนแปลงขนาด
            if (morphLabel) {
                morphLabel.frame = cell.textLabel.frame;
            }
        }
        
        [morphLabel setTextWithoutMorphing:@""];
        cell.imageView.image = nil; // นำไอคอน SF ออก
        return cell;
    }

    static NSString *cellIdentifier = @"DarkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor]; // สีเทาเข้มหรูหรา
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        
        // เอฟเฟกต์การเลือกสีมืด
        cell.selectedBackgroundView = nil;
    }
    
    NSDictionary *item = self.menuItems[indexPath.row];
    cell.textLabel.text = item[[NSString stringWithUTF8String:AY_OBFUSCATE("title")]];
    cell.detailTextLabel.text = item[[NSString stringWithUTF8String:AY_OBFUSCATE("subtitle")] ? : item[@"subtitle"]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    // ใส่ไอคอน SF Symbols เข้าไปที่ด้านซ้ายของ Cell
    if (@available(iOS 13.0, *)) {
        cell.imageView.image = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("video.badge.plus")]];
        cell.imageView.tintColor = [UIColor whiteColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.isUpdateAvailable) {
        [self downloadAndShareUpdate];
        return;
    }

    if (indexPath.row == 0) {
        [self openSystemPicker];
    }
}

#pragma mark - Core Action: ดึงไฟล์ดิบผ่าน PHPicker (เลี่ยง WebKit Auto-Compress)

- (void)openSystemPicker {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.filter = [PHPickerFilter videosFilter];
    config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent; // จุดสำคัญ: ดึงไฟล์ดิบ ไม่แปลงไฟล์!
    
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count == 0) return;
    
    [self.hud showAnimated:YES];
    
    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;
    
    // ดึง Type Identifier ของไฟล์วิดีโอต้นฉบับ
    NSString *typeIdentifier = [NSString stringWithUTF8String:AY_OBFUSCATE("public.mpeg-4")];
    if (![provider hasItemConformingToTypeIdentifier:typeIdentifier]) {
        if (provider.registeredTypeIdentifiers.count > 0) {
            typeIdentifier = provider.registeredTypeIdentifiers.firstObject;
        }
    }
    
    [provider loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (error || !url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.hud hideAnimated:YES];
                [self showStatusAlert:[NSString stringWithUTF8String:AY_OBFUSCATE("เกิดข้อผิดพลาดในการดึงไฟล์")]];
            });
            return;
        }
        
        // กำหนดเส้นทางไปยัง Documents/.F1X3R/
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *customDirPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithUTF8String:AY_OBFUSCATE(".F1X3R")]];
        [[NSFileManager defaultManager] createDirectoryAtPath:customDirPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        // สร้างชื่อไฟล์ตามวันที่และเวลา
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:[NSString stringWithUTF8String:AY_OBFUSCATE("dd-MM-yyyy-HH:mm")]];
        NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
        NSString *outputFileName = [NSString stringWithFormat:[NSString stringWithUTF8String:AY_OBFUSCATE("%@.MP4")], dateString];
        
        NSString *inputPath = [customDirPath stringByAppendingPathComponent:[NSString stringWithUTF8String:AY_OBFUSCATE("Input.MP4")]];
        NSString *outputPath = [customDirPath stringByAppendingPathComponent:outputFileName];
        
        [[NSFileManager defaultManager] removeItemAtPath:inputPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:inputPath error:nil];
        
        // ประกอบคำสั่งและเริ่มประมวลผลผ่านคลัง FFmpegKit โดยใช้ความเร็วคงที่ 2.0
        NSString *cmd = [NSString stringWithFormat:[NSString stringWithUTF8String:AY_OBFUSCATE("-itsscale 2.0 -i %@ -codec copy %@")], inputPath, outputPath];
        
        [FFmpegKit executeAsync:cmd withCompleteCallback:^(id<Session> session) {
            ReturnCode *code = [session getReturnCode];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.hud hideAnimated:YES];
                if ([ReturnCode isSuccess:code]) {
                    // ส่งวิดีโอผลลัพธ์กลับเข้าไปบันทึกไว้ในม้วนฟิล์มคลังภาพ
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:outputPath]];
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        
                        // ลบไฟล์ทิ้งทั้งหมดเมื่อทำการบันทึกลงคลังแล้ว
                        [[NSFileManager defaultManager] removeItemAtPath:inputPath error:nil];
                        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) {
                                [self showStatusAlert:[NSString stringWithUTF8String:AY_OBFUSCATE("วิดีโอของคุณถูกบันทึกไปยังคลังภาพเรียบร้อยแล้ว")]];
                            } else {
                                [self showStatusAlert:[NSString stringWithUTF8String:AY_OBFUSCATE("โปรดเปิดสิทธิ์เข้าถึงคลังภาพ เพื่อบันทึกวิดีโอไปยังคลังภาพของคุณ")]];
                            }
                        });
                    }];
                } else {
                    // ลบไฟล์ทิ้งกรณีประมวลผลล้มเหลว
                    [[NSFileManager defaultManager] removeItemAtPath:inputPath error:nil];
                    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
                    
                    [self showStatusAlert:[NSString stringWithUTF8String:AY_OBFUSCATE("คำสั่งทำงานล้มเหลว")]];
                }
            });
        }];
    }];
}

- (void)showStatusAlert:(NSString *)message {
    UIImage *statusIcon = nil;
    NSString *statusTitle = nil;
    
    if (@available(iOS 13.0, *)) {
        if ([message isEqualToString:[NSString stringWithUTF8String:AY_OBFUSCATE("วิดีโอของคุณถูกบันทึกไปยังคลังภาพเรียบร้อยแล้ว")]]) {
            statusTitle = [NSString stringWithUTF8String:AY_OBFUSCATE("บันทึกวิดีโอสำเร็จแล้ว")];
            statusIcon = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("checkmark.circle")]];
            statusIcon = [statusIcon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        } else if ([message isEqualToString:[NSString stringWithUTF8String:AY_OBFUSCATE("เกิดข้อผิดพลาดในการดึงไฟล์")]] || 
                   [message isEqualToString:[NSString stringWithUTF8String:AY_OBFUSCATE("คำสั่งทำงานล้มเหลว")]] || 
                   [message isEqualToString:[NSString stringWithUTF8String:AY_OBFUSCATE("โปรดเปิดสิทธิ์เข้าถึงคลังภาพ เพื่อบันทึกวิดีโอไปยังคลังภาพของคุณ")]]) {
            statusTitle = [NSString stringWithUTF8String:AY_OBFUSCATE("บันทึกวิดีโอไม่สำเร็จ")];
            statusIcon = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("exclamationmark.triangle")]];
            statusIcon = [statusIcon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        } else {
            statusTitle = [NSString stringWithUTF8String:AY_OBFUSCATE("แจ้งเตือน")];
            statusIcon = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("info.circle")]];
            statusIcon = [statusIcon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }
    
    [FTNotificationIndicator setNotificationIndicatorStyle:UIBlurEffectStyleDark];
    [FTNotificationIndicator showNotificationWithImage:statusIcon
                                                  title:statusTitle
                                                message:message];
}

#pragma mark - GitHub Update Checker Systems

- (void)checkAppUpdate {
    // วิธีที่ 2: ล็อกเวอร์ชันปัจจุบันตายตัวไว้ใน Binary ห้ามแก้ไขจากภายนอก
    NSString *currentVersion = [NSString stringWithUTF8String:AY_OBFUSCATE("1.0.1")];

    // URL สำหรับเรียกเช็ค Releases ล่าสุดผ่านทาง GitHub API พร้อมเพิ่มตัวแปรเวลาเพื่อเลี่ยง Cache แบบ 100%
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *apiURLString = [NSString stringWithFormat:@"https://api.github.com/repos/smart-brain333/333/releases/latest?t=%f", timestamp];
    NSURL *url = [NSURL URLWithString:apiURLString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:15.0];
    [request setValue:[NSString stringWithUTF8String:AY_OBFUSCATE("FXTool-Updater")] forHTTPHeaderField:[NSString stringWithUTF8String:AY_OBFUSCATE("User-Agent")]];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) return;
        
        NSError *jsonError = nil;
        NSDictionary *releaseInfo = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        if (jsonError || ![releaseInfo isKindOfClass:[NSDictionary class]]) return;
        
        NSString *latestTag = releaseInfo[[NSString stringWithUTF8String:AY_OBFUSCATE("tag_name")]];
        if ([latestTag hasPrefix:[NSString stringWithUTF8String:AY_OBFUSCATE("v")]]) {
            latestTag = [latestTag substringFromIndex:1];
        }
        
        // วิธีที่ 1: ตรวจสอบเปรียบเทียบว่าเวอร์ชันของ GitHub ไม่ตรงกับเครื่องปัจจุบันหรือไม่ (ถ้าไม่เท่ากันให้เด้งอัปเดตทันที)
        if (![latestTag isEqualToString:currentVersion]) {
            NSArray *assets = releaseInfo[[NSString stringWithUTF8String:AY_OBFUSCATE("assets")]];
            if (assets && assets.count > 0) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // ป้องกันการยิง Animation โหลดซ้ำซากหากกำลังอยู่ในสถานะตรวจเจอตัวเวอร์ชันล่าสุดนี้ไปแล้ว
                    if (self.isUpdateAvailable && [self.latestVersionDownloadUrl isEqualToString:assets[0][[NSString stringWithUTF8String:AY_OBFUSCATE("browser_download_url")]]]) {
                        return;
                    }
                    
                    // เก็บลิงก์ URL สำหรับใช้โหลดไฟล์ตรงของตัวแรกสุดในรายการทรัพย์สิน
                    self.latestVersionDownloadUrl = assets[0][[NSString stringWithUTF8String:AY_OBFUSCATE("browser_download_url")]];
                    self.isUpdateAvailable = YES;
                    
                    // --- เพิ่ม Animation พลิกหน้าตารางตรงนี้ ---
                    [UIView transitionWithView:self.tableView
                                      duration:0.5f // ความเร็วในการพลิก (หน่วยเป็นวินาที)
                                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction
                                    animations:^{
                        // ทุกอย่างที่เปลี่ยนแปลงภายในบล็อกนี้จะโดนเอฟเฟกต์พลิกหน้าพร้อมกัน
                        [self.tableView reloadData];
                    } completion:^(BOOL finished) {
                        if (finished) {
                            NSIndexPath *updateIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
                            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:updateIndexPath];
                            if (cell) {
                                TOMSMorphingLabel *morphLabel = (TOMSMorphingLabel *)[cell.contentView viewWithTag:999];
                                if (morphLabel) {
                                    // บังคับอัปเดตตำแหน่งเฟรมให้ตรงกับ textLabel ล่าสุดหลังจากการพลิกและเรนเดอร์ตารางเสร็จ
                                    morphLabel.frame = cell.textLabel.frame;
                                    morphLabel.animationDuration = 0.50;
                                    NSString *newText = [NSString stringWithFormat:[NSString stringWithUTF8String:AY_OBFUSCATE("ดาวน์โหลด FXTool เวอร์ชัน %@")], latestTag];
                                    [morphLabel setText:newText withCompletionBlock:nil];
                                }
                            }
                        }
                    }];
                    
                    // แสดงแจ้งเตือน FTNotificationIndicator ว่าพบเวอร์ชันใหม่ (โค้ดเดิมของคุณ)
                    UIImage *updateIcon = nil;
                    if (@available(iOS 13.0, *)) {
                        updateIcon = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("arrow.down.circle")]];
                        updateIcon = [updateIcon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                    }
                    [FTNotificationIndicator setNotificationIndicatorStyle:UIBlurEffectStyleDark];
                    [FTNotificationIndicator showNotificationWithImage:updateIcon
                                                                  title:[NSString stringWithUTF8String:AY_OBFUSCATE("มีอัปเดตใหม่")]
                                                                message:[NSString stringWithFormat:[NSString stringWithUTF8String:AY_OBFUSCATE("FXTool เวอร์ชัน %@ พร้อมให้ดาวน์โหลดแล้ว")], latestTag]];
                });
            }
        }
    }];
    [task resume];
}

- (void)downloadAndShareUpdate {
    if (!self.latestVersionDownloadUrl) return;
    
    self.hud.label.text = [NSString stringWithUTF8String:AY_OBFUSCATE("กำลังดาวน์โหลดไฟล์...")];
    
    self.hud.label.textColor = [UIColor lightGrayColor];
    
    self.hud.progress = 0.0f;
    self.hud.mode = MBProgressHUDModeDeterminate;
    [self.hud showAnimated:YES];
    
    NSURL *downloadURL = [NSURL URLWithString:self.latestVersionDownloadUrl];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:(id<NSURLSessionDownloadDelegate>)self delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:downloadURL];
    [downloadTask resume];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (totalBytesExpectedToWrite > 0) {
        float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hud.progress = progress;
        });
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSString *fileName = downloadTask.originalRequest.URL.lastPathComponent;
    if (!fileName || fileName.length == 0) {
        fileName = [NSString stringWithUTF8String:AY_OBFUSCATE("FXTool.ipa")];
    }
    
    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *destinationPath = [tmpDirectory stringByAppendingPathComponent:fileName];
    NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:destinationPath]) {
        [fileManager removeItemAtPath:destinationPath error:nil];
    }
    
    NSError *moveError = nil;
    BOOL success = [fileManager moveItemAtURL:location toURL:destinationURL error:&moveError];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hud hideAnimated:YES];
        // คืนค่าหน้าตาสปินเนอร์ให้เป็นสไตล์เดิมของระบบจัดการวิดีโอ
        self.hud.mode = MBProgressHUDModeIndeterminate;
        self.hud.label.text = nil;
        
        if (success) {
            // แสดงสถานะผ่าน FTNotification Indicator ว่าโหลดเสร็จสิ้น
            UIImage *successIcon = nil;
            if (@available(iOS 13.0, *)) {
                successIcon = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("arrow.down.doc")]];
                successIcon = [successIcon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            [FTNotificationIndicator setNotificationIndicatorStyle:UIBlurEffectStyleDark];
            [FTNotificationIndicator showNotificationWithImage:successIcon
                                                          title:[NSString stringWithUTF8String:AY_OBFUSCATE("ดาวน์โหลดเสร็จสิ้น")]

message:[NSString stringWithUTF8String:AY_OBFUSCATE("กรุณาบันทึกไฟล์ .ipa เพื่อติดตั้งเวอร์ชันล่าสุด")]];
            
            // เรียกแชร์เปิดไฟล์ผ่านระบบ Share Sheet ทันที เพื่อให้ผู้ใช้เลือก Save to Files หรือติดตั้งเอง
            NSArray *itemsToShare = @[destinationURL];
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
            
            // ตั้งค่า Handler เพื่อลบไฟล์ขยะที่โหลดมาออกทันทีเมื่อปิดหน้า PopUp ทั้งกรณีที่กดบันทึกสำเร็จหรือกดยกเลิก
            activityVC.completionWithItemsHandler = ^(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                NSFileManager *fm = [NSFileManager defaultManager];
                if ([fm fileExistsAtPath:destinationPath]) {
                    [fm removeItemAtPath:destinationPath error:nil];
                }
            };
            
            // ป้องกันแอปพลิเคชันเกิดความเสียหายเมื่อเปิด in อุปกรณ์กลุ่ม iPad
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                activityVC.popoverPresentationController.sourceView = self.tableView;
                activityVC.popoverPresentationController.sourceRect = [self.tableView rectForSection:0];
            }
            
            [self presentViewController:activityVC animated:YES completion:nil];
        } else {
            [self showStatusAlert:[NSString stringWithUTF8String:AY_OBFUSCATE("เกิดข้อผิดพลาดในการดึงไฟล์")]];
        }
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.hud hideAnimated:YES];
            self.hud.mode = MBProgressHUDModeIndeterminate;
            self.hud.label.text = nil;
            
            // เพิ่มการแจ้งเตือนแบบแยกสถานะ FT เฉพาะสำหรับการดาวน์โหลดไม่สำเร็จ/เน็ตหลุด
            UIImage *errorIcon = nil;
            if (@available(iOS 13.0, *)) {
                errorIcon = [UIImage systemImageNamed:[NSString stringWithUTF8String:AY_OBFUSCATE("xmark.circle")]];
                errorIcon = [errorIcon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            [FTNotificationIndicator setNotificationIndicatorStyle:UIBlurEffectStyleDark];
            [FTNotificationIndicator showNotificationWithImage:errorIcon
                                                          title:[NSString stringWithUTF8String:AY_OBFUSCATE("ดาวน์โหลดไม่สำเร็จ")]
                                                        message:[NSString stringWithUTF8String:AY_OBFUSCATE("ไม่สามารถดาวน์โหลดไฟล์ได้ในขณะนี้ กรุณาลองใหม่อีกครั้งในภายหลัง")]];
        });
    }
}

@end
