#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <notify.h>

#define SHARED_PLIST @"/var/jb/var/mobile/Library/Preferences/duodash_navprovider.plist"
#define FALLBACK_PLIST @"/var/mobile/Library/Preferences/duodash_navprovider.plist"

static void WriteData(NSDictionary *dict) {
    @autoreleasepool {
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict 
                                                                  format:NSPropertyListXMLFormat_v1_0 
                                                                 options:0 
                                                                   error:&error];
        if (!data || error) return;

        // 1. Ghi vào container tmp của VietMap Live
        NSString *tmpDir = NSTemporaryDirectory();
        if (tmpDir) {
            NSString *appTmp = [tmpDir stringByAppendingPathComponent:@"duodash_navprovider.plist"];
            [data writeToFile:appTmp atomically:YES];
            NSDictionary *attrs = @{NSFilePosixPermissions: @(0666)};
            [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:appTmp error:nil];
        }

        // 2. Ghi ra thư mục ngoài Sandbox để DuoDash đọc được
        [data writeToFile:SHARED_PLIST atomically:YES];
        [data writeToFile:FALLBACK_PLIST atomically:YES];
        
        NSDictionary *attrs = @{NSFilePosixPermissions: @(0666)};
        [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:SHARED_PLIST error:nil];
        [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:FALLBACK_PLIST error:nil];

        // 3. Đánh thức DuoDash
        notify_post("com.sensetechlab.navprovider.update");
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.sensetechlab.navprovider.update"),
            NULL,
            NULL,
            YES
        );
    }
}

static void SendCurrentStatus(NSInteger speed, NSInteger limit) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"v"] = @(1);
    dict[@"provider"] = @"vn.vietmap.live";
    dict[@"providerName"] = @"VietMap Live";
    dict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    dict[@"currentSpeed"] = @(speed >= 0 ? speed : 0);
    if (limit > 0) dict[@"speedLimit"] = @(limit);

    WriteData(dict);
}

// ==========================================
// 1. PHÍA ỨNG DỤNG VIETMAP LIVE: LẤY TỐC ĐỘ
// ==========================================
%group VietMapProcess

%hook CLLocationManager
- (void)locationManager:(id)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    %orig;
    CLLocation *loc = [locations lastObject];
    if (loc) {
        double kmh = loc.speed * 3.6;
        NSInteger curSpeed = (kmh > 0) ? (NSInteger)round(kmh) : 0;
        SendCurrentStatus(curSpeed, 0);
    }
}
%end

%end

// ==========================================
// 2. KHỞI TẠO TIẾN TRÌNH THEO TỪNG BUNDLE
// ==========================================
%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if ([bundleID isEqualToString:@"vn.vietmap.live"]) {
        NSLog(@"[VietMapDuoDash] Running in VietMap Live");
        %init(VietMapProcess);
        
        // Phát tín hiệu lặp lại liên tục mỗi 1 giây
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SendCurrentStatus(0, 0);
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                SendCurrentStatus(0, 0);
            }];
        });
    }
}
