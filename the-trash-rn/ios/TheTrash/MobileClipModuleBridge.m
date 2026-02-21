#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(MobileClipModule, NSObject)

RCT_EXTERN_METHOD(embedImage:(NSString *)imageUri
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end
