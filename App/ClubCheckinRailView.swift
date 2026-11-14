import SwiftUI

struct ClubCheckinRailView: View {
    let rail: ClubCheckinRail
    var stateKind: ClubCheckinRail.StateKind? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    var body: some View {
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
            if let stateKind {
                Text(verbatim: stateCopy(stateKind))
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.stateTitle")
            }
            if let sessionTime = rail.sessionTimeText {
                Text(verbatim: sessionTime)
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.sessionTime")
            }
            if let statusTime = rail.statusTimeText {
                Text(verbatim: statusTime)
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.statusTime")
            }
            if rail.refunded {
                Label("club.checkin.rail.refunded", systemImage: "arrow.uturn.backward")
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.checkin.rail.refundedNote")
            }
        } header: {
            Text("club.checkin.rail.title")
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stopView(_ stop: ClubCheckinRail.Stop, fills: Bool) -> some View {
        VStack(spacing: CYSpacing.xs) {
            Image(systemName: stop.reached ? "checkmark.circle.fill" : "circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(stop.reached ? palette.textPrimary : palette.textTertiary)
                .accessibilityHidden(true)
            Text(LocalizedStringKey("club.checkin.rail." + stop.step.rawValue))
                .font(stop.current ? CYTypography.label : CYTypography.meta)
                .foregroundStyle(stop.reached ? palette.textPrimary : palette.textSecondary)
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

    /// `titleKey` is not in the catalog yet. Use it once it resolves; otherwise the bilingual fallback, never the dotted key.
    private func stateCopy(_ kind: ClubCheckinRail.StateKind) -> String {
        let key = kind.titleKey
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key))
        if resolved != key { return resolved }
        let copy = CYKitCopy(locale: locale)
        switch kind {
        case .missing: return copy("This check-in record does not exist.", "核销记录不存在")
        case .denied: return copy("This check-in record is not visible", "核销记录不可见")
        case .error: return copy("Couldn't load this check-in.", "核销详情加载失败")
        }
    }
}

/// Mini-program club/checkin-detail (K3): customer + status head, ticket card, then the six right-aligned rows.
/// Values come straight from the server; a missing value shows —. A real 0 stays 0.
struct ClubCheckinDetailRows: View {
    let value: ClubGovernanceValue
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Section {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.md) { statusBlock; identityBlock }
            } else {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    statusBlock
                    Spacer(minLength: CYSpacing.sm)
                    identityBlock
                }
            }
        }
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: text("topicName") ?? "—")
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let order = text("orderNo") {
                    Text("club.checkin.orderNo \(order)")
                        .font(CYTypography.meta)
                        .foregroundStyle(palette.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            row("club.gov.field.ticketText", "ticketText")
            row("club.gov.field.orderTimeText", "orderTimeText")
            row("club.gov.field.paidAmountText", "paidAmountText")
            row("club.gov.field.verifyTimeText", "verifyTimeText")
            row("club.gov.field.storeName", "storeName")
            row("club.gov.field.operatorName", "operatorName")
            ClubGovernanceFactRows(value: value, fields: ["registrationId"])
        }
    }
    private var identityBlock: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            if let avatar = text("avatar") {
                SquareImage(source: avatar)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: text("displayName") ?? "—")
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.gov.fact.displayName")
                if let session = text("sessionTimeText") {
                    Text(verbatim: session)
                        .font(CYTypography.bodyCompact)
                        .foregroundStyle(palette.textSecondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let phone = text("phoneText") {
                    Text(verbatim: phone)
                        .font(CYTypography.bodyCompact)
                        .foregroundStyle(palette.textSecondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    @ViewBuilder private var statusBlock: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: CYSpacing.xs) {
            if let status = text("statusText") {
                CYStatusChip(verbatim: status, tone: statusTone, systemImage: statusSymbol)
            }
            if let time = text("statusTimeText") {
                Text(verbatim: time)
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var statusTone: CYStatusTone {
        switch value["statusCode"].string {
        case "VERIFIED": return .success
        case "REFUNDED", "CANCELLED": return .danger
        default: return .warning
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
        LabeledContent(title) { Text(verbatim: text(key) ?? "—").monospacedDigit() }
            .font(CYTypography.body)
            .foregroundStyle(palette.textPrimary)
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
        .cyDomainPageBackground()
    }
}
#endif
