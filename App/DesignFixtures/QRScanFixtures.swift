#if DEBUG
import SwiftUI

/// QR scan fixtures (synthetic, DEBUG only): `--design-fixture qr-<name>`.
/// Names: qr-scanning, qr-detected, qr-success, qr-used, qr-expired, qr-offline.
/// The "camera" is a dark gradient with a code glyph; the state machine and choreography are the real kit.
enum QRScanFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "qr-scanning": return AnyView(QRScanFixture(script: .scanning))
        case "qr-detected": return AnyView(QRScanFixture(script: .detected))
        case "qr-success": return AnyView(QRScanFixture(script: .success))
        case "qr-used": return AnyView(QRScanFixture(script: .failure(.used(at: "19:42"))))
        case "qr-expired": return AnyView(QRScanFixture(script: .failure(.expired(until: "2026-11-01"))))
        case "qr-offline": return AnyView(QRScanFixture(script: .failure(.offline)))
        default: return nil
        }
    }
}

struct QRScanFixture: View {
    enum Script: Equatable { case scanning, detected, success, failure(CYScanFailure) }
    let script: Script
    @State private var machine = CYScanMachine(kind: .ticket)
    @State private var shown: CYScanState = .idle

    private func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    var body: some View {
        ZStack {
            CYColor.bgPage.ignoresSafeArea()
            VStack(spacing: CYSpacing.xl) {
                Spacer(minLength: CYSpacing.xxl)
                CYScanStage(state: shown, card: card, onDone: {}) {
                    LinearGradient(colors: [Color.black.opacity(0.9), CYColor.bgSurface], startPoint: .top, endPoint: .bottom)
                        .overlay { Image(systemName: "qrcode").resizable().accessibilityHidden(true).scaledToFit().padding(56).foregroundStyle(CYColor.textTertiary) }
                }
                .frame(minHeight: 260)
                if case .failure(let failure) = shown {
                    CYScanFailureBanner(failure: failure, onRetry: {}, onManual: {}, onSettings: {}, onViewPass: {})
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                }
                Spacer()
            }
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
        .task { await play() }
    }

    private var card: CYScanCardContent {
        CYScanCardContent(
            title: Text(verbatim: tt("Checked in", "核验成功")),
            subtitle: Text(verbatim: tt("Night Market · 2 tickets", "夜市 · 2 张票")),
            counter: (from: 1660, to: 1760, label: Text(verbatim: tt("pts", "积分"))),
            announcement: tt("Verified. Checked in.", "已核验，签到成功"))
    }

    private func apply(_ event: CYScanEvent, online: Bool = true) {
        machine.send(event, online: online)
        withAnimation { shown = machine.state }
    }

    private func play() async {
        apply(.cameraGranted)
        try? await Task.sleep(for: .milliseconds(500))
        switch script {
        case .scanning:
            return
        case .detected:
            apply(.codeFound("chein://ticket/demo"))
        case .success:
            apply(.codeFound("chein://ticket/demo"))
            try? await Task.sleep(for: .milliseconds(120)); apply(.detectSettled)
            try? await Task.sleep(for: .milliseconds(380)); apply(.verifyOK(.checkedIn(title: "Night Market")))
        case .failure(let failure):
            apply(.codeFound("chein://ticket/demo"))
            try? await Task.sleep(for: .milliseconds(120)); apply(.detectSettled, online: failure != .offline)
            if failure != .offline { try? await Task.sleep(for: .milliseconds(200)); apply(.verifyFailed(failure)) }
        }
    }
}
#endif
