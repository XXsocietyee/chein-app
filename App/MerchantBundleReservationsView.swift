import SwiftUI

/// Source pages/merchant/bundle-reservations: 套票预约 for the next days (now−2d … +9d), rows "M月D日 HH:mm" +
/// status, and 记未到店 on BOOKED rows whose start has passed. The no-show consumes the entitlement without a
/// redemption or payout; it is a merchant write and opens only where `ReviewedAreaSwitch.merchantWrites` is open.
struct MerchantBundleReservationsView: View {
    let reader: any MerchantBusinessReading
    private enum Phase: Equatable { case loading, failed(String?), denied, ready([MerchantBundleReservation]) }
    @State private var phase: Phase = .loading
    @State private var pendingNoShow: MerchantBundleReservation?
    @State private var busyID: Int64?
    @State private var notice: LocalizedStringKey?
    @State private var refreshFailed = false

    private var writesOpen: Bool {
        ReviewedAreaSwitch.merchantWrites(apiHost: reader.scope.flatMap { URL(string: $0.realm)?.host })
    }

    var body: some View {
        content
            .navigationTitle(Text("merchant.bundleReservations.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task(id: reader.scope) { await load(pull: false) }
            .confirmationDialog(Text("merchant.bundleReservations.noShow.confirmTitle"),
                                isPresented: Binding(get: { pendingNoShow != nil }, set: { if !$0 { pendingNoShow = nil } }),
                                titleVisibility: .visible, presenting: pendingNoShow) { row in
                Button("merchant.bundleReservations.noShow.confirm", role: .destructive) { Task { await markNoShow(row) } }
                Button("merchant.bundleReservations.noShow.cancel", role: .cancel) { pendingNoShow = nil }
            } message: { row in
                Text("merchant.bundleReservations.noShow.message \(Self.timeText(row.start))")
            }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            List { ForEach(0..<4, id: \.self) { _ in CYSkeleton().frame(height: 44) } }
        case .failed:
            CYErrorState("merchant.bundleReservations.loadFailed", retryTitle: "merchant.bundleReservations.retry") { Task { await load(pull: false) } }
        case .denied:
            // MC7-05-1 (bundle-reservations/index.wxml:10-11): 申请入驻 without a merchant identity, otherwise 返回.
            MerchantDeniedState(title: "merchant.bundleReservations.denied", identifier: "merchant.bundleReservations.denied")
        case .ready(let rows) where rows.isEmpty:
            ScrollView { CYEmptyState(systemImage: "tray", "merchant.bundleReservations.empty").padding(.top, CYSpacing.xl) }
                .refreshable { await load(pull: true) }
        case .ready(let rows):
            List {
                if let notice {
                    Text(notice).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("merchant.bundleReservations.notice")
                }
                Section {
                    ForEach(rows) { row in rowView(row) }
                } footer: {
                    if !writesOpen { Text("merchant.bundleReservations.writesGated").cyText(.meta) }
                }
            }
            .refreshable { await load(pull: true) }
        }
    }

    private func rowView(_ row: MerchantBundleReservation) -> some View {
        HStack(spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: Self.timeText(row.start)).cyText(.bodyMedium).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                CYStatusChip(LocalizedStringKey("merchant.bundleReservations.status." + row.status.rawValue), tone: Self.tone(row.status))
            }
            Spacer(minLength: CYSpacing.sm)
            if row.canMarkNoShow(now: Date()) {
                CYPillButton("merchant.bundleReservations.noShow", style: .secondary) { pendingNoShow = row }
                    .disabled(busyID != nil || !writesOpen)
                    .accessibilityIdentifier("merchant.bundleReservations.noShow.\(row.id)")
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("merchant.bundleReservations.row.\(row.id)")
    }

    private func load(pull: Bool) async {
        if !pull { phase = .loading }
        do {
            let access = try await reader.access()
            guard access.allows("merchant:verify") else { phase = .denied; return }
            let rows = try await reader.bundleReservations(now: Date())
            phase = .ready(rows)
        } catch MerchantBusinessFailure.denied {
            phase = .denied
        } catch {
            if pull, case .ready = phase { notice = "merchant.bundleReservations.refreshFailed"; return }
            if case MerchantBusinessFailure.rejected(_, let message) = error { phase = .failed(message) } else { phase = .failed(nil) }
        }
    }

    private func markNoShow(_ row: MerchantBundleReservation) async {
        pendingNoShow = nil
        guard writesOpen, busyID == nil else { return }
        busyID = row.id; notice = nil
        defer { busyID = nil }
        do {
            try await reader.markBundleNoShow(row.id)
            notice = "merchant.bundleReservations.noShow.done"
        } catch MerchantBusinessFailure.unknown {
            notice = "merchant.bundleReservations.noShow.unknown"
        } catch {
            notice = "merchant.bundleReservations.noShow.failed"
        }
        await load(pull: true)
    }

    static func timeText(_ date: Date) -> String {
        let parts = MerchantBundleReservation.chinaCalendar.dateComponents([.month, .day, .hour, .minute], from: date)
        return String(format: "%d月%d日 %02d:%02d", parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }
    static func tone(_ status: MerchantBundleReservation.Status) -> CYStatusTone {
        switch status {
        case .booked: return .warning
        case .fulfilled: return .success
        case .noShow, .lateCancelled: return .danger
        case .cancelled, .waived, .merchantExited: return .neutral
        }
    }
}
