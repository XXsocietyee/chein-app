#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// fix-1128-alipay: locally authored payment-only Alipay bridge. No order string or result is persisted or logged.
@interface QFAlipayPaymentBridge : NSObject
@property(nonatomic, readonly) BOOL sdkLinked;
- (void)payOrder:(NSString *)orderString fromScheme:(NSString *)scheme result:(void (^)(NSString *))result
    NS_SWIFT_NAME(pay(orderString:fromScheme:result:));
- (BOOL)handleURL:(NSURL *)url result:(void (^)(NSString *))result NS_SWIFT_NAME(handle(url:result:));
@end
NS_ASSUME_NONNULL_END
