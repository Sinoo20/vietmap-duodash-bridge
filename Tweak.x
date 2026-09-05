#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <notify.h>

static void DuoDash_WriteAndNotify(NSDictionary *dict) {
    @autoreleasepool {
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict 
                                                                  format:NSPropertyListXMLFormat_v1_0 
                                                                 options:0 
                                                                   error:&error];
        if (!data || error) return;

        // 1. Ghi vào thư mục tmp của app theo tài liệu DuoDash
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"duodash_navprovider.plist"];
        [data writeToFile:tmpPath atomically:YES];
        chmod([tmpPath UTF8String], 0666);

        // 2. Ghi thêm một bản sao dùng chung để SpringBoard / DuoDash luôn đọc được
        NSString *sharedPath = @"/var/mobile/Library/Preferences/duodash_navprovider.plist";
        [data writeToFile:sharedPath atomically:YES];
        chmod([sharedPath UTF8String], 0666);

        // 3. Phát thông báo hệ thống để DuoDash nạp dữ liệu
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

static void DuoDash_SendPayload(NSInteger currentSpeed, NSInteger speedLimit) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"v"] = @(1);
    dict[@"provider"] = @"vn.vietmap.live";
    dict[@"providerName"] = @"VietMap Live";
    dict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    dict[@"currentSpeed"] = @(currentSpeed >= 0 ? currentSpeed : 0);
    
    if (speedLimit > 0) {
        dict[@"speedLimit"] = @(speedLimit);
    }

    DuoDash_WriteAndNotify(dict);
}

// Lấy tốc độ xe chạy thực tế từ GPS
%hook CLLocationManager

- (void)locationManager:(id)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    %orig;
    CLLocation *loc = [locations lastObject];
    if (loc) {
        double speedKmh = loc.speed * 3.6;
        NSInteger curSpeed = (speedKmh > 0) ? (NSInteger)round(speedKmh) : 0;
        DuoDash_SendPayload(curSpeed, 0);
    }
}

%end

%ctor {
    NSLog(@"[VietMapDuoDash] Loaded!");
    // Phát ngay khi VietMap vừa mở và lập lịch lặp lại mỗi 2 giây
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DuoDash_SendPayload(0, 0);

        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            DuoDash_SendPayload(0, 0);
        }];
    });
}
