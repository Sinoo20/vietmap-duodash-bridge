#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <notify.h>

static void DuoDash_SendUpdate(NSInteger currentSpeed, NSInteger speedLimit) {
    @autoreleasepool {
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"duodash_navprovider.plist"];
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"v"] = @(1);
        dict[@"provider"] = [[NSBundle mainBundle] bundleIdentifier] ?: @"vn.vietmap.live";
        dict[@"providerName"] = @"VietMap Live";
        dict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
        
        // currentSpeed: km/h
        if (currentSpeed >= 0) {
            dict[@"currentSpeed"] = @(currentSpeed);
        }
        
        // speedLimit: nếu chưa hook được giới hạn thì tạm để 0 (hoặc bỏ trống theo tài liệu)
        if (speedLimit > 0) {
            dict[@"speedLimit"] = @(speedLimit);
        }
        
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict 
                                                                  format:NSPropertyListXMLFormat_v1_0 
                                                                 options:0 
                                                                   error:&error];
        if (data && !error) {
            [data writeToFile:tmpPath atomically:YES];
            notify_post("com.sensetechlab.navprovider.update");
        }
    }
}

// Hook trực tiếp vào bộ phận nhận GPS của VietMap Live
%hook CLLocationManager

- (void)locationManager:(id)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    %orig;
    
    CLLocation *latestLocation = [locations lastObject];
    if (latestLocation) {
        // speed từ CLLocation trả về là m/s -> nhân 3.6 ra km/h
        double speedInKmh = latestLocation.speed * 3.6;
        NSInteger currentSpeed = (speedInKmh > 0) ? (NSInteger)round(speedInKmh) : 0;
        
        DuoDash_SendUpdate(currentSpeed, 0);
    }
}

%end

// Heartbeat gửi tín hiệu giữ kết nối mỗi 3 giây
@interface DuoDashHeartbeat : NSObject
+ (instancetype)sharedInstance;
- (void)startHeartbeat;
@end

@implementation DuoDashHeartbeat
+ (instancetype)sharedInstance {
    static DuoDashHeartbeat *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DuoDashHeartbeat alloc] init];
    });
    return instance;
}

- (void)startHeartbeat {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer * _Nonnull t) {
        DuoDash_SendUpdate(0, 0);
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}
@end

%ctor {
    NSLog(@"[VietMapDuoDash] Loaded into: %@", [[NSBundle mainBundle] bundleIdentifier]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DuoDashHeartbeat sharedInstance] startHeartbeat];
    });
}
