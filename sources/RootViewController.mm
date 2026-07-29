#import "RootViewController.h"
#import "AppUtil.h"
#import <dlfcn.h>
#import <sys/stat.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface RootViewController ()

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIButton *selectFileButton;
@property (nonatomic, strong) UIButton *injectButton;
@property (nonatomic, strong) NSString *selectedDylibPath;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DylibTester";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    [self setupUI];
    [self checkAndDownloadLdid];
}

#pragma mark - Helper Logging

- (void)appendLog:(NSString *)log {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logTextView.text stringByAppendingFormat:@"%@\n", log];
        [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
    });
}

#pragma mark - Ldid Auto Download Helper

- (NSString *)ldidSavePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:@"ldid"];
}

/*- (void)checkAndDownloadLdid {
    NSString *ldidPath = [self ldidSavePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:ldidPath]) {
        [self appendLog:@"✅ Found cached ldid binary in Documents."];
        return;
    }
    
    [self appendLog:@"🔍 Checking latest ldid version from GitHub..."];
    
    fetchLatestLdidVersion(^(NSString *latestVersion) {
        if (!latestVersion) {
            [self appendLog:@"⚠️ Failed to check version, downloading default ldid..."];
        } else {
            [self appendLog:[NSString stringWithFormat:@"🌐 Latest ldid version: %@", latestVersion]];
        }
        
        NSURL *downloadURL = [NSURL URLWithString:@"https://github.com/opa334/ldid/releases/latest/download/ldid"];
        
        NSURLSessionDownloadTask *task = [[NSURLSession sharedURLSession] downloadTaskWithURL:downloadURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) {
                [self appendLog:[NSString stringWithFormat:@"❌ Download ldid failed: %@", error.localizedDescription]];
                return;
            }
            
            NSError *fileError = nil;
            [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:ldidPath error:&fileError];
            
            if (fileError) {
                [self appendLog:[NSString stringWithFormat:@"❌ Save ldid failed: %@", fileError.localizedDescription]];
                return;
            }
            
            chmod([ldidPath UTF8String], 0755);
            [self appendLog:@"✅ ldid downloaded & ready to use! (chmod +x)"];
        }];
        
        [task resume];
    });
}*/

- (void)checkAndDownloadLdid {
    NSString *ldidPath = [self ldidSavePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:ldidPath]) {
        [self appendLog:@"✅ Found cached ldid binary in Documents."];
        return;
    }
    
    [self appendLog:@"🔍 Checking latest ldid version from GitHub..."];
    
    fetchLatestLdidVersion(^(NSString *latestVersion) {
        if (!latestVersion) {
            [self appendLog:@"⚠️ Failed to check version, downloading default ldid..."];
        } else {
            [self appendLog:[NSString stringWithFormat:@"🌐 Latest ldid version: %@", latestVersion]];
        }
        
        NSURL *downloadURL = [NSURL URLWithString:@"https://github.com/opa334/ldid/releases/latest/download/ldid"];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:downloadURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                [self appendLog:[NSString stringWithFormat:@"❌ Download ldid failed: %@", error.localizedDescription]];
                return;
            }
            
            if (!data || data.length == 0) {
                [self appendLog:@"❌ Download ldid failed: Empty response data."];
                return;
            }
            
            NSError *fileError = nil;
            [data writeToFile:ldidPath options:NSDataWritingAtomic error:&fileError];
            
            if (fileError) {
                [self appendLog:[NSString stringWithFormat:@"❌ Save ldid failed: %@", fileError.localizedDescription]];
                return;
            }
            
            chmod([ldidPath UTF8String], 0755);
            [self appendLog:@"✅ ldid downloaded & ready to use! (chmod +x)"];
        }];
        
        [task resume];
    });
}

#pragma mark - UI Setup

- (void)setupUI {
    // 1. Path Status Label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"No .dylib selected";
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 2. Select File Button
    self.selectFileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.selectFileButton setTitle:@"📁 Select .dylib File" forState:UIControlStateNormal];
    self.selectFileButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.selectFileButton.backgroundColor = [UIColor systemBlueColor];
    [self.selectFileButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.selectFileButton.layer.cornerRadius = 12;
    self.selectFileButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.selectFileButton addTarget:self action:@selector(selectDylibTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 3. Inject Button
    self.injectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.injectButton setTitle:@"🚀 Sign & Inject (dlopen)" forState:UIControlStateNormal];
    self.injectButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    self.injectButton.backgroundColor = [UIColor systemGreenColor];
    [self.injectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.injectButton.layer.cornerRadius = 12;
    self.injectButton.enabled = NO;
    self.injectButton.alpha = 0.5;
    self.injectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.injectButton addTarget:self action:@selector(injectDylibTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 4. Console Log Area
    self.logTextView = [[UITextView alloc] init];
    self.logTextView.editable = NO;
    self.logTextView.backgroundColor = [UIColor blackColor];
    self.logTextView.textColor = [UIColor greenColor];
    self.logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.logTextView.layer.cornerRadius = 8;
    self.logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logTextView.text = @"--- Log Console ---\nReady.\n";
    
    // Add Views
    [self.view addSubview:self.selectFileButton];
    [self.view addSubview:self.statusLabel];
    [self.view addSubview:self.injectButton];
    [self.view addSubview:self.logTextView];
    
    // AutoLayout Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.selectFileButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.selectFileButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.selectFileButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.selectFileButton.heightAnchor constraintEqualToConstant:50],
        
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.selectFileButton.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        [self.injectButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:16],
        [self.injectButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.injectButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.injectButton.heightAnchor constraintEqualToConstant:50],
        
        [self.logTextView.topAnchor constraintEqualToAnchor:self.injectButton.bottomAnchor constant:20],
        [self.logTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.logTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.logTextView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - Actions

- (void)selectDylibTapped {
    UIDocumentPickerViewController *picker = nil;
    
    if (@available(iOS 14.0, *)) {
        UTType *dylibType = [UTType typeWithFilenameExtension:@"dylib" conformingToType:UTTypeData];
        UTType *binType = [UTType typeWithFilenameExtension:@"dylib" conformingToType:UTTypeItem];
        
        NSMutableArray *types = [NSMutableArray array];
        if (dylibType) [types addObject:dylibType];
        if (binType) [types addObject:binType];
        [types addObject:UTTypeData];
        [types addObject:UTTypeItem];
        
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.item", @"com.apple.mach-o-binary"] inMode:UIDocumentPickerModeImport];
    }
    
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationPageSheet;
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)injectDylibTapped {
    if (!self.selectedDylibPath || ![[NSFileManager defaultManager] fileExistsAtPath:self.selectedDylibPath]) {
        [self appendLog:@"❌ Error: Selected file does not exist."];
        return;
    }

    [self appendLog:[NSString stringWithFormat:@"[1/2] Signing dylib using ldid: %@", self.selectedDylibPath.lastPathComponent]];
    
    // 1. เรียกใช้งาน spawnRoot เพื่อรัน ldid -S บนไฟล์ .dylib
    // ตรวจสอบ ldid ที่ดาวน์โหลดมาจาก GitHub ใน Documents ก่อน
    NSString *ldidBin = [self ldidSavePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:ldidBin]) {
        ldidBin = [[NSBundle mainBundle] pathForResource:@"ldid" ofType:@""];
        if (!ldidBin) ldidBin = @"/var/jb/usr/bin/ldid"; // Fallback สำหรับเครื่องที่ใช้ Jailbreak Rootless
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:ldidBin]) {
        [self appendLog:@"❌ Error: ldid binary not found. Please wait for download or check connection."];
        return;
    }
    
    NSString *stdOut = @"";
    NSString *stdErr = @"";
    
    // เรียก spawnRoot (ฟังก์ชันจาก AppUtil.m)
    int exitCode = spawnRoot(ldidBin, @[@"-S", self.selectedDylibPath], &stdOut, &stdErr);
    
    if (exitCode != 0) {
        [self appendLog:[NSString stringWithFormat:@"❌ ldid failed (Exit Code: %d)", exitCode]];
        if (stdErr.length > 0) [self appendLog:[NSString stringWithFormat:@"STDERR: %@", stdErr]];
        return;
    }
    
    [self appendLog:@"✅ CoreTrust CodeSign Success!"];
    [self appendLog:@"[2/2] Calling dlopen()..."];
    
    // 2. เรียก dlopen() เพื่อฉีดเข้าแอปตัวเอง
    void *handle = dlopen([self.selectedDylibPath UTF8String], RTLD_NOW);
    if (!handle) {
        char *error = dlerror();
        [self appendLog:[NSString stringWithFormat:@"❌ dlopen Error: %s", error ? error : "Unknown error"]];
    } else {
        [self appendLog:@"🎉 SUCCESS! .dylib loaded successfully into process."];
    }
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    
    // บันทึก Path ของไฟล์ .dylib
    self.selectedDylibPath = url.path;
    self.statusLabel.text = [NSString stringWithFormat:@"File: %@", url.lastPathComponent];
    self.statusLabel.textColor = [UIColor labelColor];
    
    self.injectButton.enabled = YES;
    self.injectButton.alpha = 1.0;
    
    [self appendLog:[NSString stringWithFormat:@"Selected: %@", url.path]];
}

@end
