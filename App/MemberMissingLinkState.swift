import SwiftUI

/// MP `cy-empty kind="missing-param"` with 返回 (fix-r3 member-a: R7-MEM-2-1, R7-MEM-5-1, R7-MEM-12-1).
/// A member page opened without the id it needs lands here instead of the generic 暂不可用 placeholder or a
/// network read with an empty id. 返回 pops the pushed page, or closes the deep-link sheet.
struct MemberMissingLinkState: View {
    /// MP copy for this page: 商品不存在或已下架 (market/pass), 链接已失效 (pass-order, invoice-detail).
    var title: LocalizedStringKey = "mp.common.linkExpired"
    let identifier: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CYStateLayout(kind: .generic, title: Text(title),
                      primary: (title: "action.back", action: { dismiss() }),
                      primaryIdentifier: "\(identifier).back")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(identifier)
    }
}
