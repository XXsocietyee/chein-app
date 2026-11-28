#import "QFAlipayPaymentBridge.h"

// Alipay payment has its own compile-time opt-in, like WeChat Pay (QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED).
// Without it (or without the AlipaySDK framework) the Swift driver uses the alipay:// URL hand-off instead.
#if defined(QUESTIFY_ALIPAY_SDK_APPROVED) && QUESTIFY_ALIPAY_SDK_APPROVED == 1 && __has_include(<AlipaySDK/AlipaySDK.h>)
#import <AlipaySDK/AlipaySDK.h>
#define QF_HAS_ALIPAY_PAYMENT 1
#else
#define QF_HAS_ALIPAY_PAYMENT 0
#endif

@implementation QFAlipayPaymentBridge
- (BOOL)sdkLinked { return QF_HAS_ALIPAY_PAYMENT; }

- (void)payOrder:(NSString *)orderString fromScheme:(NSString *)scheme result:(void (^)(NSString *))result {
    NSAssert([NSThread isMainThread], @"Alipay bridge must run on main thread");
#if QF_HAS_ALIPAY_PAYMENT
    [[AlipaySDK defaultService] payOrder:orderString fromScheme:scheme callback:^(NSDictionary *resultDic) {
        NSString *status = [resultDic[@"resultStatus"] isKindOfClass:[NSString class]] ? resultDic[@"resultStatus"] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{ result(status); });
    }];
#else
    result(@"");
#endif
}

- (BOOL)handleURL:(NSURL *)url result:(void (^)(NSString *))result {
    NSAssert([NSThread isMainThread], @"Alipay bridge must run on main thread");
#if QF_HAS_ALIPAY_PAYMENT
    if (![url.host isEqualToString:@"safepay"]) { return NO; }
    [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
        NSString *status = [resultDic[@"resultStatus"] isKindOfClass:[NSString class]] ? resultDic[@"resultStatus"] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{ result(status); });
    }];
    return YES;
#else
    return NO;
#endif
}
@end
