#import "RootViewController.h"
#import "SettingsViewController.h"
#import <ffmpegkit/FFmpegKit.h>
#import <PhotosUI/PhotosUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "obfuscate.h"
#import "MBProgressHUD.h"
#import "FTNotificationIndicator.h"

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource, PHPickerViewControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *menuItems;
@property (nonatomic, assign) float currentScale;
@property (nonatomic, strong) MBProgressHUD *hud;

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
        self.title = [NSString stringWithUTF8String:AY_OBFUSCATE("TikTokTool")];
        
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [NSString stringWithUTF8String:AY_OBFUSCATE("เครื่องมือจัดการวิดีโอ")];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
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

@end