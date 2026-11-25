import SwiftUI

/// MP `pages/club/detail/index.wxml:367-395` quick-acts on 管理: round buttons under the workbench head.
/// - CLB-G06: 设置 for every 管理 viewer (owner, admin or a delegated manager).
/// - CLB-G02: 扫码 for the owner, an admin or `club:activity:manage`; it opens the camera and posts the matched
///   verify route (`index.js:964-1060`). `scan=1` on the link starts it once the page has loaded (`index.js:754-755`).
@MainActor struct ClubManageQuickActions: View {
    let canScan: Bool
    let canGovern: Bool
    let canManageActivities: Bool
    var autoStartScan = false
    let submitScan: ((_ raw: String, _ canGovern: Bool, _ canManageActivities: Bool) async throws -> Bool)?
    /// CLB-G06: 设置 opens the 俱乐部设置 sheet (MP wxml:390-394, `onSettings` js:3571-3575). Nil hides it.
    var onSettings: (() -> Void)? = nil
    /// CLB-detail-35: 出示二维码 for the owner, an admin or `club:event:checkin` (MP wxml:375-380, js:1078-1101).
    var onGroupCode: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var scanning = false
    @State private var autoStarted = false
    @State private var busy = false
    @State private var wrongEntry: String?
    @State private var resultTitle: LocalizedStringKey?
    @State private var resultMessage: String?
    @State private var showsResult = false

    private var scanOffered: Bool { canScan && submitScan != nil }

    var body: some View {
        if scanOffered || onSettings != nil || onGroupCode != nil {
            Section {
                layout {
                    if scanOffered {
                        quickAction("club.quick.scan", systemImage: "qrcode.viewfinder", identifier: "club.quick.scan") { scanning = true }
                            .disabled(busy)
                            .accessibilityLabel(Text("club.quick.scan.a11y"))
                    }
                    if let onGroupCode {
                        quickAction("club.quick.groupCode", systemImage: "qrcode", identifier: "club.quick.groupCode", action: onGroupCode)
                    }
                    if let onSettings {
                        quickAction("club.quick.settings", systemImage: "ellipsis", identifier: "club.quick.settings", action: onSettings)
                            .accessibilityLabel(Text("clubR8.settings.open"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .task {
                guard autoStartScan, !autoStarted, scanOffered else { return }
                autoStarted = true
                scanning = true
            }
            .fullScreenCover(isPresented: $scanning) {
                NativeQRScanner { raw in
                    scanning = false
                    Task { await handle(raw) }
                }
            }
            .alert(Text("club.scan.wrongEntry"), isPresented: Binding(get: { wrongEntry != nil }, set: { if !$0 { wrongEntry = nil } })) {
                Button("club.scan.gotIt", role: .cancel) {}
            } message: {
                Text(verbatim: wrongEntry ?? "")
            }
            .alert(resultTitle.map { Text($0) } ?? Text(verbatim: ""), isPresented: $showsResult) {
                Button("club.scan.ok", role: .cancel) {}
            } message: {
                if let resultMessage { Text(verbatim: resultMessage) }
            }
        }
    }

    @ViewBuilder private func layout<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.md, content: content)
        } else {
            HStack(alignment: .top, spacing: CYSpacing.xl, content: content)
        }
    }

    private func quickAction(_ title: LocalizedStringKey, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CYSpacing.xs) {
                Image(systemName: systemImage)
                    .imageScale(.large)
                    .foregroundStyle(CYColor.brand)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .background(CYColor.brand.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Text(title).cyText(.meta).foregroundStyle(CYColor.textPrimary)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(identifier)
    }

    /// `ClubScanReady.successTitle` per route kind (MP `utils/verification-scan.js`).
    static func successKey(kind: String) -> LocalizedStringKey {
        switch kind {
        case "group": return "club.scan.success.group"
        case "dynamic-ticket", "legacy-ticket": return "club.scan.success.ticket"
        default: return "club.scan.success.coupon"
        }
    }

    /// MP `startClubScan` success / `submitClubScan`: invalid codes send nothing and explain; a busy write is not
    /// sent twice; an unknown result says so instead of inviting a duplicate verify.
    private func handle(_ raw: String) async {
        switch ClubScanRoute.resolve(raw) {
        case let .invalid(message, _, _):
            wrongEntry = message
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
