#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <notify.h>

static void DuoDash_SetPerms(NSString *path) {
    if (!path) return;
    NSDictionary *attrs = @{NSFilePosixPermissions: @(0666)};
    [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:path error:nil];
}

static void DuoDash_WriteAndNotify(NSDictionary *dict) {
    @autoreleasepool {
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict 
                                                                  format:NSPropertyListXMLFormat_v1_0 
                                                                 options:0 
                                                                   error:&error];
        if (!data || error) return;

        // 1. Ghi vào tmp của app VietMap Live
        NSString *tmpDir = NSTemporaryDirectory();
        if (tmpDir) {
            NSString *tmpPath = [tmpDir stringByAppendingPathComponent:@"duodash_navprovider.plist"];
            [data writeToFile:tmpPath atomically:YES];
            DuoDash_SetPerms(tmpPath);
        }

        // 2. Ghi dự phòng vào thư mục dùng chung Preferences
        NSString *sharedPath = @"/var/mobile/Library/Preferences/duodash_navprovider.plist";
        [data writeToFile:sharedPath atomically:YES];
        DuoDash_SetPerms(sharedPath);

        // 3. Phát thông báo hệ thống
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

// Hook lấy tốc độ thực tế từ GPS
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
    NSLog(@"[VietMapDuoDash] Loaded successfully!");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DuoDash_SendPayload(0, 0);

        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            DuoDash_SendPayload(0, 0);
        }];
    });
}
