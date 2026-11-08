import SwiftUI

/// Port-2: span badge for the coupon validity range editor (mini-program `cdr__badge`).
struct CouponValiditySpanBadge: View {
    let span: CouponValiditySpan
    var body: some View {
        var parts: [Text] = []
        if span.days > 0 { parts.append(Text("couponManagement.span.days \(span.days)")) }
        if span.hours > 0 { parts.append(Text("couponManagement.span.hours \(span.hours)")) }
        if span.minutes > 0 { parts.append(Text("couponManagement.span.minutes \(span.minutes)")) }
        let body = parts.enumerated().reduce(Text("")) { partial, item in
            item.offset == 0 ? item.element : partial + Text(" ") + item.element
        }
        return LabeledContent("couponManagement.span.title") { body }
            .accessibilityIdentifier("couponManagement.range.span")
    }
}
