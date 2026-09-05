#import <Foundation/Foundation.h>
#import <notify.h>
#import <objc/runtime.h>

// Hàm gửi dữ liệu sang DuoDash theo đặc tả SDK DuoDash Navigation Provider
static void DuoDash_SendUpdate(NSInteger currentSpeed, NSInteger speedLimit, NSInteger cameraType, NSInteger cameraDist, NSString *cameraDesc) {
    @autoreleasepool {
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"duodash_navprovider.plist"];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"v"] = @(1);
        dict[@"provider"] = [[NSBundle mainBundle] bundleIdentifier] ?: @"vn.vietmap.live";
        dict[@"providerName"] = @"VietMap Live";
        dict[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
        
        if (currentSpeed >= 0) {
            dict[@"currentSpeed"] = @(currentSpeed);
        }
        if (speedLimit > 0) {
            dict[@"speedLimit"] = @(speedLimit);
        }
        if (cameraType > 0) {
            dict[@"cameraType"] = @(cameraType);
            dict[@"cameraDistance"] = @(cameraDist);
            if (cameraDesc && cameraDesc.length > 0) {
                dict[@"cameraDescription"] = cameraDesc;
            }
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

// Lớp timer đệm phát sóng định kỳ (Heartbeat 3s) để DuoDash không bị ngắt kết nối
@interface DuoDashHeartbeat : NSObject
+ (instancetype)sharedInstance;
- (void)startHeartbeat;
@property (nonatomic, assign) NSInteger lastSpeed;
@property (nonatomic, assign) NSInteger lastLimit;
@property (nonatomic, assign) NSInteger lastCamType;
@property (nonatomic, assign) NSInteger lastCamDist;
@end

@implementation DuoDashHeartbeat
+ (instancetype)sharedInstance {
    static DuoDashHeartbeat *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DuoDashHeartbeat alloc] init];
        instance.lastSpeed = 0;
        instance.lastLimit = 0;
        instance.lastCamType = 0;
        instance.lastCamDist = 0;
    });
    return instance;
}

- (void)startHeartbeat {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer * _Nonnull t) {
        DuoDash_SendUpdate(self.lastSpeed, self.lastLimit, self.lastCamType, self.lastCamDist, nil);
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}
@end

%ctor {
    NSLog(@"[VietMapDuoDash] Loaded into process: %@", [[NSBundle mainBundle] bundleIdentifier]);
    // Khởi tạo vòng lặp heartbeat
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DuoDashHeartbeat sharedInstance] startHeartbeat];
    });
}
