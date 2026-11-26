import SwiftUI

struct ClubCheckinRailView: View {
    let rail: ClubCheckinRail
    var stateKind: ClubCheckinRail.StateKind? = nil
    /// CLB-checkin-detail-03 (fix-r3-club-b): MP 重新加载 for a load failure; denied and missing only go back.
    var onReload: (() -> Void)? = nil
    /// Round 4: MP `errorText`, the server sentence. Missing uses it as the title; denied and error show it as the
    /// sub line, and denied falls back to 当前身份不能查看核销记录 (index.js:82).
    var reason: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    var body: some View {
        if let stateKind {
            // CLB-checkin-detail-03 (fix-r3-club-b): denied / missing / error are full-page states (MP cy-error /
            // cy-empty fill), not a meta line under the rail.
            Section {
                let detail: String? = stateKind == .missing ? nil
                    : (shownReason ?? (stateKind == .denied ? appLocalized("clubR3b.checkin.deniedReason", locale: locale) : nil))
                ContentUnavailableView {
                    Label {
                        Text(LocalizedStringKey(stateKind == .missing ? (shownReason ?? stateCopy(stateKind)) : stateCopy(stateKind)))
                            .accessibilityIdentifier("club.checkin.rail.stateTitle")
                    } icon: {
                        Image(systemName: stateKind == .error ? "exclamationmark.triangle" : (stateKind == .denied ? "lock" : "doc.text"))
                    }
                } description: {
                    if let detail { Text(verbatim: detail) }
                } actions: {
                    Button {
                        if stateKind == .error, let onReload { onReload() } else { dismiss() }
                    } label: {
                        Text(LocalizedStringKey(stateKind == .error && onReload != nil ? "clubR3b.checkin.reload" : "clubR3b.checkin.back"))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("club.checkin.state.action")
                }
            }
        } else {
            railSection
        }
    }

    /// CLB-checkin-detail-04 (fix-r3-club-b): the MP rail sits under the order card with no section title.
    private var railSection: some View {
        Section {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    ForEach(rail.stops) { stopView($0, fills: false) }
                }
            } else {
                HStack(alignment: .top, spacing: CYSpacing.sm) {
                    ForEach(rail.stops) { stopView($0, fills: true) }
                }
            }
            if let sessionTime = rail.sessionTimeText {
                Text(verbatim: sessionTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.sessionTime")
            }
            if let statusTime = rail.statusTimeText {
                Text(verbatim: statusTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.statusTime")
            }
            if rail.refunded {
                Label("club.checkin.rail.refunded", systemImage: "arrow.uturn.backward")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.refundedNote")
            }
        }
    }

    private func stopView(_ stop: ClubCheckinRail.Stop, fills: Bool) -> some View {
        VStack(spacing: CYSpacing.xs) {
            // CLB-checkin-detail-08 (fix-r3-club-b): MP success dots for reached stops, warning for 已接洽; the shape stays.
            Image(systemName: stop.reached ? "checkmark.circle.fill" : "circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(stopTint(stop))
                .accessibilityHidden(true)
            Text(LocalizedStringKey("club.checkin.rail." + stop.step.rawValue))
                .font(.footnote)
                .fontWeight(stop.current ? .bold : .regular)
                .foregroundStyle(stop.reached ? Color.primary : Color.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: fills ? .infinity : nil, alignment: .center)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(stop.current ? .isSelected : [])
        .accessibilityValue(Text(stop.reached ? "club.checkin.rail.reached" : "club.checkin.rail.notReached"))
        .accessibilityIdentifier("club.checkin.rail." + stop.step.rawValue)
    }

    private func stopTint(_ stop: ClubCheckinRail.Stop) -> Color {
        guard stop.reached else { return Color(uiColor: .tertiaryLabel) }
        return stop.step == .contacted ? .orange : .green
    }

    /// `titleKey` is not in the catalog yet. Use it once it resolves; otherwise the bilingual fallback, never the dotted key.
    private var shownReason: String? {
        guard let text = reason?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private func stateCopy(_ kind: ClubCheckinRail.StateKind) -> String {
        let key = kind.titleKey
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key))
        if resolved != key { return resolved }
        let copy = CYKitCopy(locale: locale)
        switch kind {
        case .missing: return copy("This check-in record does not exist.", "核销记录不存在")
        case .denied: return copy("This check-in record is not visible", "核销记录不可见")
        case .error: return copy("Couldn't load this check-in voucher", "核销凭证加载失败")
        }
    }
}

/// Mini-program club/checkin-detail (K3): customer + status head, ticket card, then the six right-aligned rows.
/// Values come straight from the server; a missing value shows —. A real 0 stays 0.
struct ClubCheckinDetailRows: View {
    let value: ClubGovernanceValue
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Section {
            // CLB-checkin-detail-05 (parity r2): person first (leading), status on the trailing side, as the MP head.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.md) { identityBlock; statusBlock }
            } else {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    identityBlock
                    Spacer(minLength: CYSpacing.sm)
                    statusBlock
                }
            }
        }
        Section {
            // CLB-checkin-detail-04 (fix-r3-club-b): MP order card — topic cover, session time, name, 单号.
            HStack(alignment: .top, spacing: CYSpacing.md) {
                if let cover = text("topicCover") {
                    SquareImage(source: cover)
                        .frame(width: 59, height: 40)
                        .clipped()
                        .accessibilityHidden(true)
                } else {
                    // MP wxml:45 `ckd-cover--empty`. CLB-r10-nat-checkin-01: an SF Symbol in the same footprint (no drawn
                    // placeholder plate), so the text column never jumps.
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                        .frame(width: 59, height: 40)
                        .accessibilityHidden(true)
                }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let session = text("sessionTimeText") {
                    Text(verbatim: session)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                // CLB-checkin-detail-07: MP topic is label-bold; body-medium is the closest step on the scale.
                Text(verbatim: text("topicName") ?? appLocalized("clubR3b.checkin.untitledTopic", locale: locale))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let order = text("orderNo") {
                    Text("club.checkin.orderNo \(order)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            // The internal 报名编号 row is gone (MP shows none); the UI-test arrival anchor stays as an identifier.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(value["registrationId"].text != nil ? "club.gov.fact.registrationId" : "club.checkin.order")
            row("club.gov.field.ticketText", "ticketText")
            row("club.gov.field.orderTimeText", "orderTimeText")
            row("club.gov.field.paidAmountText", "paidAmountText")
            row("club.gov.field.verifyTimeText", "verifyTimeText")
            row("club.gov.field.storeName", "storeName")
            row("club.gov.field.operatorName", "operatorName")
        }
    }
    private var identityBlock: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            // MP `detail.avatar || '/images/d_profile.png'`: the default face, never an empty slot (round 2 MP asset).
            Group {
                if let avatar = text("avatar") {
                    SquareImage(source: avatar)
                } else {
                    MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: text("displayName") ?? "—")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.gov.fact.displayName")
                if let session = text("sessionTimeText") {
                    Text(verbatim: session)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let phone = text("phoneText") {
                    HStack(spacing: CYSpacing.sm) {
                        Text(verbatim: phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        // CLB-checkin-detail-02: MP checkin-detail wxml:29 (phoneCallable from the server).
                        if let url = ClubPhoneCall.url(phoneText: phone, callable: value["phoneCallable"] == .bool(true)) {
                            ClubPhoneCallButton(url: url, name: text("displayName"))
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder private var statusBlock: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: CYSpacing.xs) {
            if let status = text("statusText") {
                Label(status, systemImage: statusSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            if let time = text("statusTimeText") {
                Text(verbatim: time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var statusColor: Color {
        switch value["statusCode"].string {
        case "VERIFIED": return .green
        case "REFUNDED", "CANCELLED": return .red
        default: return .orange
        }
    }
    private var statusSymbol: String {
        switch value["statusCode"].string {
        case "VERIFIED": return "checkmark"
        case "REFUNDED", "CANCELLED": return "xmark"
        default: return "clock"
        }
    }
    private func text(_ key: String) -> String? {
        guard let raw = value[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }
    private func row(_ title: LocalizedStringKey, _ key: String) -> some View {
        // Owner decision 9: amounts read ¥12.50 through `MoneyDisplay` (via `ClubMoneyText`).
        LabeledContent(title) { Text(verbatim: text(key).map { ClubMoneyText.amountKeys.contains(key) ? ClubMoneyText.display($0) : $0 } ?? "—").monospacedDigit() }
    }
}

#if DEBUG
#Preview("Check-in · player") {
    ClubCheckinPreview().themeDomain(.player)
}
#Preview("Check-in · merchant") {
    ClubCheckinPreview().themeDomain(.merchant)
}

private struct ClubCheckinPreview: View {
    var body: some View {
        List {
            ClubCheckinRailView(
                rail: ClubCheckinRail(
                    railStep: .integer(2),
                    statusCode: .string("VERIFIED"),
                    sessionTime: .string("2026-11-09 10:00"),
                    statusTime: .string("2026-11-09 10:30")
                ),
                stateKind: .missing
            )
            ClubCheckinDetailRows(value: .object([
                "displayName": .string("Fixture attendee"),
                "registrationId": .integer(0),
                "topicName": .string("Night market"),
                "statusText": .string("Verified"),
                "statusCode": .string("VERIFIED"),
                "paidAmountText": .string("0"),
                "ticketText": .null,
                "orderNo": .string("SAMPLE-0")
            ]))
        }
    }
}
#endif
