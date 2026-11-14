import SwiftUI

/// FP-H3 (App Store 1.2). A general Settings entry for contacting support and for how reports are handled.
/// The contact itself comes from the same reviewed server-side contact the withdrawal screen reads; this view
/// invents no address, SLA or endpoint. The clause below is draft copy pending the owner's legal text (FP-O7).
/// Titles are catalog keys (`settings.supportSafety.*`). The clause stays an inline draft until the owner's legal text lands.
enum SettingsSupportSafetyCopy {
    static func clause(chinese: Bool) -> String {
        chinese
            ? "平台不容忍违规、骚扰或令人反感的内容与用户。你可以在内容旁的菜单中举报或屏蔽，也可以联系客服。违规内容与账号将被审核并处理。"
            : "We do not tolerate objectionable content or abusive users. Report or block from the menu next to content, or contact support. Reported content and accounts are reviewed and acted on."
    }
}

@MainActor struct SettingsSupportSafetyEntry: View {
    var body: some View {
        Section {
            NavigationLink {
                SettingsSupportSafetyView()
            } label: {
                Label("settings.supportSafety.title", systemImage: "lifepreserver")
            }
            .accessibilityIdentifier("settings.supportSafety")
        }
    }
}

@MainActor struct SettingsSupportSafetyView: View {
    @Environment(\.locale) private var locale
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        Form {
            Section("settings.supportSafety.rules") {
                Text(verbatim: SettingsSupportSafetyCopy.clause(chinese: chinese))
                    .accessibilityIdentifier("settings.supportSafety.clause")
            }
            Section("settings.supportSafety.contactSection") {
                NavigationLink {
                    WithdrawalSupportContactView()
                } label: {
                    Label("settings.supportSafety.showContact", systemImage: "bubble.left.and.bubble.right")
                }
                .accessibilityIdentifier("settings.supportSafety.contact")
            }
        }
        .navigationTitle(Text("settings.supportSafety.title"))
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.player)
    }
}
