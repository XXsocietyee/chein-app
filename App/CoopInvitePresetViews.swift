import SwiftUI

/// MC8-31-3: MP coop/invite `goCreateTopic` → `pages/publish/fabu/index` (`?scope=MERCHANT` on the merchant surface).
/// The host injects the publish page; nil hides 先发布主题 and keeps only the empty copy.
private struct CoopTopicPublishDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor (String?) -> AnyView)? = nil
}
extension EnvironmentValues {
    var coopTopicPublishDestination: (@MainActor (String?) -> AnyView)? {
        get { self[CoopTopicPublishDestinationKey.self] }
        set { self[CoopTopicPublishDestinationKey.self] = newValue }
    }
}

/// MC8-31-2 / MC8-31-4 (coop/invite index.wxml:35-39, 82-88): a route-fixed topic or target is shown as one locked
/// row (已锁定) instead of a picker.
struct CoopInviteLockedRow: View {
    let title: String
    let detail: LocalizedStringKey?
    let identifier: String
    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: title).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail { Text(detail).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
            }
            Spacer(minLength: CYSpacing.sm)
            CYStatusChip("merchantCoop.invite.locked", tone: .neutral, systemImage: "lock")
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
