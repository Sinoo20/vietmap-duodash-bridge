#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <notify.h>

static void DuoDash_SendPayload(NSInteger currentSpeed, NSInteger speedLimit) {
    @autoreleasepool {
        NSString *tmpDir = NSTemporaryDirectory();
        if (!tmpDir) return;
        
        NSString *plistPath = [tmpDir stringByAppendingPathComponent:@"duodash_navprovider.plist"];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"v"] = @(1);
        dict[@"provider"] = @"vn.vietmap.live";
        dict[@"providerName"] = @"VietMap Live";
        dict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
        
        if (currentSpeed >= 0) {
            dict[@"currentSpeed"] = @(currentSpeed);
        }
        if (speedLimit > 0) {
            dict[@"speedLimit"] = @(speedLimit);
        }
        
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict 
                                                                  format:NSPropertyListXMLFormat_v1_0 
                                                                 options:0 
                                                                   error:&error];
        if (data && !error) {
            [data writeToFile:plistPath atomically:YES];
            notify_post("com.sensetechlab.navprovider.update");
        }
    }
}

// Hook vào Location Manager nhận tốc độ di chuyển thực tế từ GPS
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

// Khởi chạy ngay khi VietMap Live vừa bật lên
%ctor {
    NSLog(@"[VietMapDuoDash] Injected into VietMap Live successfully!");
    
    // Ghi file định danh ngay lập tức sau 1 giây mở app
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DuoDash_SendPayload(0, 0);
        
        // Tạo timer định kỳ phát sóng mỗi 2 giây
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            DuoDash_SendPayload(-1, 0);
        }];
    });
}
