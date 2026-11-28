import SwiftUI

private struct CityNodeReceiptFactoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> CityNodeRedemptionReceiptReader?)? = nil
}
extension EnvironmentValues {
    var cityNodeReceiptFactory: (@MainActor () -> CityNodeRedemptionReceiptReader?)? {
        get { self[CityNodeReceiptFactoryKey.self] }
        set { self[CityNodeReceiptFactoryKey.self] = newValue }
    }
}

@MainActor private final class CityNodeRedeemModel: ObservableObject {
    let coordinator: CityNodeRedemptionCoordinator
    private let reader: any MerchantBusinessReading
    private var receipt: CityNodeRedemptionReceiptReader?
    private var receiptResolved = false
    var canRecover: Bool { receipt?.isCurrent == true }
    private struct Authorization: Equatable {
        let scope: MerchantBusinessScope?
        let generation: UUID?
    }
    private var preparedAuthorization: Authorization?
    private var authorization: Authorization { .init(scope: reader.scope, generation: reader.authorizationGeneration) }
    var authorizationGeneration: UUID? { reader.authorizationGeneration }
    var isAvailable: Bool { coordinator.isAvailable && reader.canExecuteVerificationMutation }
    var blocksAllTargets: Bool { coordinator.pendingScope == .legacy || coordinator.pendingScope == .storage }
    @Published private(set) var revision = 0
    init(reader: any MerchantBusinessReading, journal: any MerchantBusinessIntentStore, receipt: CityNodeRedemptionReceiptReader? = nil) {
        self.reader = reader; self.receipt = receipt; coordinator = reader.cityNodeRedemption(journal: journal)
    }
    /// Resolve once per view owner. A replacement identity or grant cannot be silently adopted.
    func resolveReceipt(_ factory: (@MainActor () -> CityNodeRedemptionReceiptReader?)?) {
        guard !receiptResolved else { return }; receiptResolved = true
        if receipt == nil { receipt = factory?() }
        revision += 1
    }
    func prepare(_ raw: String) async {
        let captured = authorization; preparedAuthorization = nil; revision += 1
        await coordinator.prepare(raw, isCurrent: { self.authorization == captured && self.isAvailable })
        if coordinator.review != nil { preparedAuthorization = captured }
        revision += 1
    }
    func confirm(_ id: UUID) async {
        guard let captured = preparedAuthorization else { cancel(); return }
        preparedAuthorization = nil; revision += 1
        await coordinator.confirm(id, isCurrent: { self.authorization == captured && self.isAvailable })
        revision += 1
    }
    func recover(_ raw: String) async {
        let captured = authorization; preparedAuthorization = nil; revision += 1
        await coordinator.recover(raw, reader: receipt, isCurrent: { self.authorization == captured })
        revision += 1
    }
    func cancel() { preparedAuthorization = nil; coordinator.cancelReview(); revision += 1 }
    func next() { preparedAuthorization = nil; coordinator.next(); revision += 1 }
    func restore() { coordinator.restoreLocalPending(); revision += 1 }
    func invalidate() { preparedAuthorization = nil; coordinator.invalidate(); revision += 1 }
}

@MainActor struct CityNodeRedeemView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cityNodeReceiptFactory) private var receiptFactory
    /// verify-r2 N-01: this page applies the merchant domain to itself, so its own palette is that domain's.
    /// Reading `cyPalette` here gave the pushing NavigationStack's palette (the dark player shell).
    private var palette: CYDomainPalette { CYDomainPalette(.merchant) }
    @Environment(\.locale) private var locale
    @StateObject private var model: CityNodeRedeemModel
    @State private var raw = ""
    @State private var showsScanner = false
    @State private var preparing = false
    @State private var confirming = false
    @State private var scannedCode: String?
    @State private var visible = false
    @State private var lifetime = UUID()
    @FocusState private var codeFocused: Bool
    init(reader: any MerchantBusinessReading, journal: any MerchantBusinessIntentStore, receipt: CityNodeRedemptionReceiptReader? = nil) {
        _model = StateObject(wrappedValue: CityNodeRedeemModel(reader: reader, journal: journal, receipt: receipt))
    }
    private var busy: Bool { preparing || confirming || model.coordinator.busy }
    private var showsNext: Bool { model.coordinator.result != nil && !model.blocksAllTargets }
    private var rowInsets: EdgeInsets {
        EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal)
    }

    var body: some View {
        Form {
            Section {
                CYHeroHeader("merchant.cityRedeem.title", subtitle: "merchant.cityRedeem.instructions") {
                    Cloud07Cover(seed: "city-node-redeem", symbol: "qrcode.viewfinder")
                }
            }
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if !model.isAvailable {
                Section {
                    CYNoteBanner(text: Text("merchant.cityRedeem.disabled"), symbol: "lock.fill", tone: .warning)
                }
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Text("merchant.cityRedeem.code")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecureField("merchant.cityRedeem.code", text: $raw)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                    .focused($codeFocused).privacySensitive().disabled(!model.isAvailable || model.blocksAllTargets || busy || model.coordinator.review != nil)
                    .accessibilityIdentifier("merchant.cityRedeem.code")
                Text("merchant.cityRedeem.cameraConsent")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowInsets(rowInsets)

            Section {
                if showsNext {
                    reviewButton(style: .secondary)
                }
                CYPillButton("merchant.cityRedeem.scan", style: .secondary, systemImage: "qrcode.viewfinder") { showsScanner = true }
                    .disabled(!model.isAvailable || model.blocksAllTargets || busy || model.coordinator.review != nil)
                    .accessibilityLabel(Text("merchant.cityRedeem.scan"))
                    .accessibilityIdentifier("merchant.cityRedeem.scan")
                if model.canRecover {
                    CYPillButton("回读原核销结果", style: .tertiary) { recover(raw) }
                        .disabled(raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy || model.coordinator.review != nil)
                        .accessibilityLabel(Text("回读原核销结果"))
                        .accessibilityIdentifier("merchant.cityRedeem.recoverOriginal")
                }
            }
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if busy {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("merchant.cityRedeem.processing")
                            .cyText(.body)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        CYSkeleton().accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let result = model.coordinator.result {
                Section {
                    if result.isUnknown {
                        CYNoteBanner(text: Text(verbatim: CityNodeRedemptionResult.unknownMessage), symbol: "questionmark.circle", tone: .warning)
                    } else {
                        CYStatusChip(
                            LocalizedStringKey(result.redeemed ? "merchant.cityRedeem.success" : "merchant.cityRedeem.rejected"),
                            tone: result.redeemed ? .success : .danger,
                            systemImage: result.redeemed ? "checkmark.circle" : "exclamationmark.circle"
                        )
                        Text(verbatim: shown(result.message))
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("merchant.cityRedeem.serverMessage")
                    }
                    if let unverified = result.unverifiedServerMessage, !unverified.isEmpty {
                        Text(verbatim: "服务返回（尚未确认为本次回执）")
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: unverified)
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("merchant.cityRedeem.unverifiedMessage")
                    }
                }
                .listRowInsets(rowInsets)
            }

            if let pending = model.coordinator.pendingScope {
                Section {
                    if let result = model.coordinator.result, !result.isUnknown {
                        Text(verbatim: "服务已返回明确结果，但本机待办未能清除，仍保持原有阻断范围。不要重复核销；请联系平台处理。")
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if pending == .legacy {
                        Text(verbatim: CityNodeRedemptionResult.legacyGuidance)
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if pending == .storage {
                        Text(verbatim: "本机核销待办无法读取或保存，本次未提交。请检查本机存储并联系平台处理；不会自动清除已有待办。")
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(verbatim: CityNodeRedemptionResult.unknownGuidance)
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: "可以核销其他玩家或节点；刷新短码、重新扫码或重新登录都不会重发同一目标。")
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .listRowInsets(rowInsets)
                .accessibilityIdentifier("merchant.cityRedeem.pendingGuidance")
            }

            if let failure = model.coordinator.failure {
                Section {
                    CYNoteBanner(text: Text(LocalizedStringKey(failure)), symbol: "exclamationmark.triangle", tone: .danger)
                        .accessibilityIdentifier("merchant.cityRedeem.failure")
                }
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyDomainScreen(.merchant)
        .cyHideTabBar(true)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { primaryBar }
        .cyHaptic(.impactMedium, trigger: preparing, where: CYHapticTransition.turnedOn)
        .cyHaptic(.impactMedium, trigger: confirming, where: CYHapticTransition.turnedOn)
        .cyModalConfirm(
            isPresented: model.coordinator.review != nil,
            title: appLocalized("merchant.cityRedeem.confirmTitle", locale: locale),
            message: appLocalized("merchant.cityRedeem.confirmHint", locale: locale),
            cancelTitle: appLocalized("action.cancel", locale: locale),
            confirmTitle: appLocalized("merchant.cityRedeem.confirm", locale: locale),
            isConfirmLoading: confirming,
            confirmIdentifier: "merchant.cityRedeem.confirm",
            onCancel: { if !confirming { model.cancel() } },
            onConfirm: {
                guard let review = model.coordinator.review,
                      !busy, visible, model.isAvailable, !model.blocksAllTargets, scenePhase == .active else { return }
                confirming = true
                Task { await model.confirm(review.id); confirming = false }
            }
        )
        .cySheet(isPresented: $showsScanner, onDismiss: {
            // Wait for scanner dismissal before presenting the short confirmation dialog.
            guard let payload = scannedCode else { return }
            scannedCode = nil
            prepare(payload)
        }) {
            // No automatic camera grant, payload URL navigation or redeem-on-detection.
            NativeQRScanner { payload in
                guard visible, model.isAvailable, !model.blocksAllTargets, scenePhase == .active, !busy else { return }
                scannedCode = payload
            }
            .cyDomainSheet(detents: [.half, .full])
            .themeDomain(.merchant)
        }
        .onAppear { visible = true; model.resolveReceipt(receiptFactory); model.restore() }
        .onChange(of: model.coordinator.scope) { _, _ in clear() }
        .onChange(of: model.authorizationGeneration) { _, _ in clear() }
        .onChange(of: model.isAvailable) { _, available in if !available { clear() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { clear() } }
        .onDisappear { visible = false; clear() }
    }

    private var primaryBar: some View {
        Group {
            if showsNext { nextButton } else { reviewButton(style: .primary) }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.vertical, CYSpacing.md)
        .background(palette.bgPage)
    }

    private func reviewButton(style: CYPillStyle) -> some View {
        CYPillButton("merchant.cityRedeem.review", style: style, systemImage: "checkmark.circle") { prepare(raw) }
            .disabled(!model.isAvailable || model.blocksAllTargets || raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy || model.coordinator.review != nil)
            .accessibilityLabel(Text("merchant.cityRedeem.review"))
            .accessibilityIdentifier("merchant.cityRedeem.review")
    }

    private var nextButton: some View {
        Group {
            if model.coordinator.pendingScope != nil {
                CYPillButton(verbatim: "核销其他玩家或节点", systemImage: "arrow.right") { raw = ""; model.next() }
                    .accessibilityLabel(Text(verbatim: "核销其他玩家或节点"))
            } else {
                CYPillButton("merchant.cityRedeem.next", systemImage: "arrow.right") { raw = ""; model.next() }
                    .accessibilityLabel(Text("merchant.cityRedeem.next"))
            }
        }
        .accessibilityIdentifier("merchant.cityRedeem.next")
    }

    /// Blank server copy is unknown. A real message, including a literal zero, stays as sent.
    private func shown(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : message
    }

    private func recover(_ code: String) {
        guard visible, !busy, scenePhase == .active, model.canRecover else { return }
        codeFocused = false; raw = ""; preparing = true
        let captured = lifetime
        Task {
            guard visible, lifetime == captured, scenePhase == .active else { preparing = false; return }
            await model.recover(code); preparing = false
        }
    }
    private func prepare(_ code: String) {
        guard visible, model.isAvailable, !model.blocksAllTargets, !busy, scenePhase == .active else { return }
        codeFocused = false; raw = ""; preparing = true
        let captured = lifetime
        Task {
            guard visible, lifetime == captured, scenePhase == .active else { preparing = false; return }
            await model.prepare(code); preparing = false
        }
    }
    private func clear() { lifetime = UUID(); codeFocused = false; raw = ""; scannedCode = nil; showsScanner = false; model.invalidate() }
}
