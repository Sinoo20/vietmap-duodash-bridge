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
        
        dict[@"currentSpeed"] = @(currentSpeed >= 0 ? currentSpeed : 0);
        
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
            
            // 1. Gửi bằng notify_post chuẩn C
            notify_post("com.sensetechlab.navprovider.update");
            
            // 2. Gửi thêm bằng Darwin Notify Center để xuyên qua Sandbox iOS 16
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFSTR("com.sensetechlab.navprovider.update"),
                NULL,
                NULL,
                YES
            );
        }
    }
}

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
    NSLog(@"[VietMapDuoDash] Running...");
    
    // Gửi liên tục mỗi 1.5 giây để DuoDash luôn nhận diện nguồn sống
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DuoDash_SendPayload(0, 0);
        
        [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            DuoDash_SendPayload(0, 0);
        }];
    });
}
