import SwiftUI

// HANDOVER 36, WP-07. Group/school quote, coupon usability, and first-play activation.
// The quote shows the server tier and the server total. Create and activate stay behind MPCommerceGate.
// Coupon usability is read-only and does not change couponDeductYuan.

struct GroupCheckoutPanel: View {
    let phase: MPLoad<GroupCheckoutDisplay>
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("wp07.group.title", tableName: "WP07Commerce")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 2)
                    .accessibilityLabel(Text("wp07.group.loading", tableName: "WP07Commerce"))
                    .accessibilityIdentifier("wp07.group.loading")
            case .failed:
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("wp07.group.error", tableName: "WP07Commerce")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                    Button(action: onRetry) {
                        Text("wp07.group.retry", tableName: "WP07Commerce")
                    }
                    .buttonStyle(CYPillButtonStyle(style: .secondary))
                    .accessibilityIdentifier("wp07.group.retry")
                }
                .accessibilityIdentifier("wp07.group.error")
            case .ready(let display):
                if display.isEmpty {
                    Text("wp07.group.empty", tableName: "WP07Commerce")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("wp07.group.empty")
                } else {
                    ready(display)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("wp07.group")
    }

    private func ready(_ display: GroupCheckoutDisplay) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            labeled(Text("wp07.group.kind", tableName: "WP07Commerce"), value: kind(display.productKind), identifier: "wp07.group.kind")
            labeled(Text("wp07.group.tier", tableName: "WP07Commerce"), value: Text(verbatim: display.tierLabel ?? "—"), identifier: "wp07.group.tier")
            labeled(Text("wp07.group.total", tableName: "WP07Commerce"), value: Text(verbatim: display.totalText ?? "—"), identifier: "wp07.group.total")
            if display.totalText != nil {
                Text("registration.form.currencyUnknown")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
            if MPCommerceGate.purchasesEnabled {
                Text("wp07.group.createClosed", tableName: "WP07Commerce")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            } else {
                MPGatedNote(text: Text("wp07.group.createClosed", tableName: "WP07Commerce"), identifier: "wp07.group.createOff")
            }
        }
    }

    private func kind(_ kind: Int?) -> Text {
        switch kind {
        case 5: return Text("wp07.group.kind.group", tableName: "WP07Commerce")
        case 6: return Text("wp07.group.kind.school", tableName: "WP07Commerce")
        default: return Text(verbatim: "—")
        }
    }

    private func labeled(_ title: Text, value: Text, identifier: String) -> some View {
        LabeledContent { value.foregroundStyle(CYColor.textPrimary).monospacedDigit() } label: { title }
            .cyText(.bodyCompact)
            .accessibilityIdentifier(identifier)
    }
}

struct PassActivatePanel: View {
    let topicID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("wp07.activate.title", tableName: "WP07Commerce")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            if let topicID, !topicID.isEmpty {
                LabeledContent {
                    Text(verbatim: topicID).foregroundStyle(CYColor.textPrimary).monospacedDigit()
                } label: {
                    Text("wp07.activate.topic", tableName: "WP07Commerce")
                }
                .cyText(.bodyCompact)
                .accessibilityIdentifier("wp07.activate.topic")
                if MPCommerceGate.purchasesEnabled && ReviewedAreaSwitch.moneyPayments {
                    Text("wp07.activate.closed", tableName: "WP07Commerce")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                } else {
                    MPGatedNote(text: Text("wp07.activate.closed", tableName: "WP07Commerce"), identifier: "wp07.activate.off")
                }
            } else {
                Text("wp07.activate.empty", tableName: "WP07Commerce")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("wp07.activate.empty")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("wp07.activate")
    }
}

enum WP07CommerceSession {
    @MainActor static func client(_ session: AppSession) -> WP07CommerceClient? {
        guard let context = session.currentRuntimeDependencyContext,
              let configuration = try? APIConfiguration(baseURL: context.baseURL),
              let token = session.passReadToken(), AuthRequestBuilder.isValidToken(token) else { return nil }
        let transport = ChinaReviewedProductionTransport(underlying: session.composition.makeTransport())
        let host = context.baseURL.host
        return WP07CommerceClient(configuration: configuration, transport: transport, token: token, apiHost: host,
                                  writesOpen: { MPCommerceGate.purchasesEnabled && ReviewedAreaSwitch.moneyPayments(host: host) })
    }
}

enum CouponUsabilityPhase: Equatable {
    case loading
    case empty
    case failed
    case ready([CouponUsabilityRow])
}

struct CouponUsabilitySection: View {
    let phase: CouponUsabilityPhase
    let onRetry: () -> Void

    var body: some View {
        Section {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 1)
                    .accessibilityLabel(Text("wp07.coupon.loading", tableName: "WP07Commerce"))
                    .accessibilityIdentifier("wp07.coupon.loading")
            case .empty:
                ContentUnavailableView { Label { Text("wp07.coupon.empty", tableName: "WP07Commerce") } icon: { Image(systemName: "ticket") } }
                    .accessibilityIdentifier("wp07.coupon.empty")
            case .failed:
                Text("wp07.coupon.error", tableName: "WP07Commerce")
                    .foregroundStyle(CYColor.textSecondary)
                Button(action: onRetry) {
                    Text("wp07.coupon.retry", tableName: "WP07Commerce")
                }
                .accessibilityIdentifier("wp07.coupon.retry")
            case .ready(let rows):
                if rows.isEmpty {
                    ContentUnavailableView { Label { Text("wp07.coupon.empty", tableName: "WP07Commerce") } icon: { Image(systemName: "ticket") } }
                        .accessibilityIdentifier("wp07.coupon.empty")
                } else {
                    ForEach(rows) { row in
                        LabeledContent {
                            reason(row)
                                .foregroundStyle(CYColor.textPrimary)
                        } label: {
                            Text(verbatim: row.name ?? "—")
                        }
                        .accessibilityIdentifier("wp07.coupon.row." + row.id)
                    }
                }
            }
            LabeledContent {
                Text(verbatim: "0").monospacedDigit().foregroundStyle(CYColor.textPrimary)
            } label: {
                Text("wp07.coupon.deduct", tableName: "WP07Commerce")
            }
            .accessibilityIdentifier("wp07.coupon.deduct")
            Text("wp07.coupon.readOnly", tableName: "WP07Commerce")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
        } header: {
            Text("wp07.coupon.title", tableName: "WP07Commerce")
        }
    }

    private func reason(_ row: CouponUsabilityRow) -> Text {
        guard let reason = row.reason, CouponUsabilityRow.knownReasons.contains(reason) else {
            return Text(verbatim: "—")
        }
        switch reason {
        case "AVAILABLE": return Text("wp07.coupon.reason.available", tableName: "WP07Commerce")
        case "USED": return Text("wp07.coupon.reason.used", tableName: "WP07Commerce")
        case "EXPIRED": return Text("wp07.coupon.reason.expired", tableName: "WP07Commerce")
        case "DISABLED": return Text("wp07.coupon.reason.disabled", tableName: "WP07Commerce")
        case "NOT_STARTED": return Text("wp07.coupon.reason.notStarted", tableName: "WP07Commerce")
        case "COUPON_MISSING": return Text("wp07.coupon.reason.missing", tableName: "WP07Commerce")
        default: return Text(verbatim: "—")
        }
    }
}
