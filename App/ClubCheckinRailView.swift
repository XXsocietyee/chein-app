import SwiftUI

struct ClubCheckinRailView: View {
    let rail: ClubCheckinRail
    var stateKind: ClubCheckinRail.StateKind? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md))
            : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        Section("club.checkin.rail.title") {
            layout {
                ForEach(rail.stops) { stop in
                    VStack(spacing: CYSpacing.xs) {
                        Image(systemName: stop.reached ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(stop.reached ? palette.success : palette.textTertiary)
                        Text(LocalizedStringKey("club.checkin.rail." + stop.step.rawValue))
                            .font(CYTypography.caption.weight(stop.current ? .semibold : .regular))
                            .foregroundStyle(stop.reached ? palette.textPrimary : palette.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(stop.current ? .isSelected : [])
                    .accessibilityValue(Text(stop.reached ? "club.checkin.rail.reached" : "club.checkin.rail.notReached"))
                    .accessibilityIdentifier("club.checkin.rail." + stop.step.rawValue)
                }
            }
            if let stateKind {
                CYStatusChip(verbatim: stateKind.title, tone: .info, systemImage: "location.circle")
                    .accessibilityIdentifier("club.checkin.rail.stateTitle")
            }
            if let sessionTime = rail.sessionTimeText {
                Text(verbatim: sessionTime).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                    .accessibilityIdentifier("club.checkin.rail.sessionTime")
            }
            if let statusTime = rail.statusTimeText {
                Text(verbatim: statusTime).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                    .accessibilityIdentifier("club.checkin.rail.statusTime")
            }
            if rail.refunded {
                CYStatusChip("club.checkin.rail.refunded", tone: .warning, systemImage: "arrow.uturn.backward.circle")
                    .accessibilityIdentifier("club.checkin.rail.refundedNote")
            }
        }
    }
}

/// Mini-program club/checkin-detail (K3): customer + status head, ticket card, then the six right-aligned rows.
/// Values come straight from the server; a missing value shows —.
struct ClubCheckinDetailRows: View {
    let value: ClubGovernanceValue
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Section {
            let head = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s3))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Space.s3))
            head {
                if let avatar = text("avatar") {
                    SquareImage(source: avatar).frame(width: 48, height: 48).clipShape(Circle()).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: text("displayName") ?? "—").font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("club.gov.fact.displayName")
                    if let session = text("sessionTimeText") { Text(verbatim: session).font(CYTypography.bodyCompact).foregroundStyle(palette.textSecondary) }
                    if let phone = text("phoneText") { Text(verbatim: phone).font(CYTypography.bodyCompact).foregroundStyle(palette.textSecondary) }
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: Theme.Space.s2) }
                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: CYSpacing.xs) {
                    if let status = text("statusText") {
                        CYStatusChip(verbatim: status, tone: statusTone)
                    }
                    if let time = text("statusTimeText") { Text(verbatim: time).font(CYTypography.meta).foregroundStyle(palette.textTertiary) }
                }
            }
        }
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: text("topicName") ?? "—").font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                if let order = text("orderNo") { Text("club.checkin.orderNo \(order)").font(CYTypography.meta).foregroundStyle(palette.textTertiary).textSelection(.enabled) }
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
    private var statusTone: CYStatusTone {
        switch value["statusCode"].string {
        case "VERIFIED": return .success
        case "REFUNDED", "CANCELLED": return .danger
        default: return .warning
        }
    }
    private func text(_ key: String) -> String? {
        guard let raw = value[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }
    private func row(_ title: LocalizedStringKey, _ key: String) -> some View {
        LabeledContent(title) { Text(verbatim: text(key) ?? "—").monospacedDigit() }
    }
}
