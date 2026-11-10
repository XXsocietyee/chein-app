import SwiftUI

/// Mini-program scene-settings-deregister: executeAfter is shown as a time, or 执行时间待确认.
/// Reform plan v9 U03: display follows the phone's zone; the Beijing wall time is added when
/// the zones differ, and the cooling-off deadline itself is decided by the server.
struct DeregistrationExecuteAfterRow: View {
    let raw: String?
    var phoneTimeZone: TimeZone = .current
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.xs) { label; value }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                    label
                    Spacer(minLength: CYSpacing.sm)
                    value
                }
            }
            if let beijing = BeijingServerTime(raw).display(phoneTimeZone: phoneTimeZone)?.beijing {
                HStack(spacing: CYSpacing.xs) {
                    Text("authEntry.deregister.beijingTime", tableName: "AuthEntry")
                    Text(verbatim: beijing).monospacedDigit()
                }
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
            Label {
                Text("authEntry.deregister.serverDecides", tableName: "AuthEntry")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "clock.badge.checkmark").accessibilityHidden(true)
            }
            .font(CYTypography.meta)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var label: some View {
        Text("authEntry.deregister.executeAfter", tableName: "AuthEntry")
            .font(CYTypography.cardTitle)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var value: some View {
        if let display = BeijingServerTime(raw).display(phoneTimeZone: phoneTimeZone) {
            Text(verbatim: display.phone + (display.phoneZoneAbbreviation.map { " (" + $0 + ")" } ?? ""))
                .font(CYTypography.numericBody)
                .foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("authEntry.deregister.executeAfter")
        } else {
            CYStatusChip(verbatim: pendingCopy, tone: .warning, systemImage: "clock")
                .accessibilityIdentifier("authEntry.deregister.timePending")
        }
    }

    private var pendingCopy: String {
        String(localized: LocalizedStringResource("authEntry.deregister.timePending", table: "AuthEntry", locale: locale))
    }
}

/// WECHAT reconfirmation needs a mini-program wx.login code; UNAVAILABLE has no method at all.
/// Neither records the cancellation-notice consent nor offers SMS.
struct DeregistrationVerificationUnavailableSection: View {
    let method: String?
    let recheck: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                CYRowIcon(systemImage: method == "WECHAT" ? "bubble.left" : "lock")
                Group {
                    if method == "WECHAT" {
                        Text("authEntry.deregister.wechatUnavailable", tableName: "AuthEntry")
                            .accessibilityIdentifier("authEntry.deregister.wechatUnavailable")
                    } else {
                        Text("authEntry.deregister.verificationUnavailable", tableName: "AuthEntry")
                            .accessibilityIdentifier("authEntry.deregister.verificationUnavailable")
                    }
                }
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            }
            CYPillButton("authEntry.deregister.recheck", style: .secondary, tableName: "AuthEntry", action: recheck)
                .accessibilityIdentifier("authEntry.deregister.recheck")
                .accessibilityLabel(Text("authEntry.deregister.recheck", tableName: "AuthEntry"))
        }
    }
}
