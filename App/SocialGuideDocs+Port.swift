import SwiftUI

/// Mini-program `subpackageA/pages/infomation`: a CMS document whose title/body is unusable renders as a
/// disabled, arrow-less cell ("未命名条目" / "内容待完善，暂不可查看") instead of a dead link.
struct SocialGuideUnusableDocRow: View {
    let title: String
    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if trimmed.isEmpty { Text("guideXcx.docUntitled") } else { Text(verbatim: trimmed) }
            Text("guideXcx.docUnavailable").font(.footnote).foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("social.information.unusable")
    }
}
