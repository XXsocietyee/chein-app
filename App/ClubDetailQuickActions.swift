import SwiftUI

/// MP `pages/club/detail` 管理 quick action (CLB-G02): 扫码核销 for the owner, an admin, or
/// `club:activity:manage`. `scan=1` starts the camera once the page has loaded.
@MainActor struct ClubManageQuickActions: View {
    let canScan: Bool
    let canGovern: Bool
    let canManageActivities: Bool
    var autoStartScan = false
    let submitScan: ((_ raw: String, _ canGovern: Bool, _ canManageActivities: Bool) async throws -> Bool)?
    var onConsumeAutoStart: () -> Void = {}

    @State private var scanning = false
    @State private var busy = false
    @State private var wrongEntry: LocalizedStringKey?
    @State private var resultTitle: LocalizedStringKey?
    @State private var resultMessage: String?
    @State private var showsResult = false

    private var scanOffered: Bool { canScan && submitScan != nil }

    var body: some View {
        if scanOffered {
            Section {
                Button {
                    scanning = true
                } label: {
                    Label("club.quick.scan", systemImage: "qrcode.viewfinder")
                }
                .disabled(busy)
                .accessibilityLabel(Text("club.quick.scan.a11y"))
                .accessibilityIdentifier("club.quick.scan")
            }
            .task {
                guard autoStartScan else { return }
                scanning = true
                onConsumeAutoStart()
            }
            .sheet(isPresented: $scanning) {
                NativeQRScanner { raw in
                    scanning = false
                    Task { await handle(raw) }
                }
            }
            .alert(Text("club.scan.wrongEntry"), isPresented: Binding(get: { wrongEntry != nil }, set: { if !$0 { wrongEntry = nil } })) {
                Button("club.scan.gotIt", role: .cancel) {}
            } message: {
                if let wrongEntry { Text(wrongEntry) }
            }
            .alert(resultTitle.map { Text($0) } ?? Text(verbatim: ""), isPresented: $showsResult) {
                Button("club.scan.ok", role: .cancel) {}
            } message: {
                if let resultMessage { Text(verbatim: resultMessage) }
            }
        }
    }

    /// `ClubScanRoute` explains a bad code in Chinese. The alert uses the matching catalog key.
    static func invalidKey(_ message: String) -> LocalizedStringKey {
        switch message {
        case "这是主题席位码，请由本场带队者从带队核销入口扫码": return "club.scan.invalid.topicSeat"
        case "这是节点核销码，请从「城市节点」页扫码核销": return "club.scan.invalid.cityNode"
        case "暂不支持此动态码": return "club.scan.invalid.unsupported"
        default: return "club.scan.invalid.format"
        }
    }

    static func successKey(kind: String) -> LocalizedStringKey {
        switch kind {
        case "group": return "club.scan.success.group"
        case "dynamic-ticket", "legacy-ticket": return "club.scan.success.ticket"
        default: return "club.scan.success.coupon"
        }
    }

    private func handle(_ raw: String) async {
        switch ClubScanRoute.resolve(raw) {
        case let .invalid(message, _, _):
            wrongEntry = Self.invalidKey(message)
        case let .ready(matched):
            guard let submitScan, !busy else {
                resultTitle = "club.scan.busy"; resultMessage = nil; showsResult = true; return
            }
            busy = true
            defer { busy = false }
            do {
                if try await submitScan(raw, canGovern, canManageActivities) {
                    resultTitle = Self.successKey(kind: matched.kind); resultMessage = nil
                } else {
                    resultTitle = "club.scan.failed"; resultMessage = nil
                }
            } catch let refusal as MPGapServerRefusal {
                resultTitle = "club.scan.failed"; resultMessage = refusal.message
            } catch {
                resultTitle = "club.scan.unknown"; resultMessage = nil
            }
            showsResult = true
        }
    }
}
