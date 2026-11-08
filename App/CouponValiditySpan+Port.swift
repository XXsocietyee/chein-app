import SwiftUI

/// Port-2: span badge for the coupon validity range editor (mini-program `cdr__badge`).
struct CouponValiditySpanBadge: View {
    let span: CouponValiditySpan
    private var summary: Text {
        var parts: [Text] = []
        if span.days > 0 { parts.append(Text("couponManagement.span.days \(span.days)")) }
        if span.hours > 0 { parts.append(Text("couponManagement.span.hours \(span.hours)")) }
        if span.minutes > 0 { parts.append(Text("couponManagement.span.minutes \(span.minutes)")) }
        var result = Text("")
        for (index, part) in parts.enumerated() { result = index == 0 ? part : result + Text(" ") + part }
        return result
    }
    var body: some View {
        LabeledContent("couponManagement.span.title") { summary }
            .accessibilityIdentifier("couponManagement.range.span")
    }
}
