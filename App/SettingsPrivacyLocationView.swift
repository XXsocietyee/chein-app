import SwiftUI

/// Settings row 隐私与定位 (mini-program `pages/shezhi` privacy sheet), placed
/// after 我的收藏 as in the source.
@MainActor struct SettingsPrivacyLocationEntry: View {
    let session: AppSession
    /// mp-settings r3: shared by this row and MP pages/privacy (城市定位与更多隐私设置) so both open the same controls.
    static func destination(session: AppSession) -> SettingsPrivacyLocationView {
        SettingsPrivacyLocationView(
            mediaReader: session.ownMediaReader,
            compliance: session.accountComplianceCoordinator,
            market: session.operationalMarket,
            imagePreview: session.ownMediaImagePreviewAccess,
            approvedLink: session.ownMediaApprovedLinkAccess,
            audioPreview: session.ownMediaAudioPreviewAccess,
            modelPreview: session.ownMediaModelPreviewAccess,
            legalReader: session.legalReader,
            disablePresence: (session.isSignedIn && session.isConfigured) ? {
                await session.disableRoamPresenceVisibility()
            } : nil,
            readPresence: (session.isSignedIn && session.isConfigured) ? {
                await session.readRoamPresenceVisibility()
            } : nil
        )
    }
    var body: some View {
        if session.account != nil {
            SettingsEntrySection {
                NavigationLink {
                    Self.destination(session: session)
                } label: {
                    Label { Text("member.privacy.title", tableName: "MemberProfile") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcLockKeyhole) }
                }.accessibilityIdentifier("settings.privacyLocation")
            }
        }
    }
}

@MainActor struct SettingsPrivacyLocationView: View {
    let mediaReader: any OwnMediaReading
    var compliance: AccountComplianceCoordinator? = nil
    var market: RegionalMarket? = nil
    var imagePreview: OwnMediaImagePreviewAccess? = nil
    var approvedLink: OwnMediaApprovedLinkAccess? = nil
    var audioPreview: OwnMediaAudioPreviewAccess? = nil
    var modelPreview: OwnMediaModelPreviewAccess? = nil
    var legalReader: any SettingsLegalReading = SettingsBundledLegalReader()
    var disablePresence: (() async -> RoamPresenceDisableOutcome)? = nil
    /// Nil means the read did not answer. `false` means sharing is already off, so the off control stays hidden.
    var readPresence: (() async -> Bool?)? = nil
    @Environment(\.locale) private var locale
    @State private var showsRoam = false
    @State private var disablingPresence = false
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info
    @State private var lastRoamCleanup: ComplianceRoamCleanup = .idle
    @State private var presenceSharing: Bool?

    var body: some View {
        Form {
            // Mini-program privacy sheet (privacy-sheet/index.wxml): the location sentence, the guide, 更多隐私设置 (home city + own media), presence, roam.
            Section {
                Text("member.privacy.sheetBody", tableName: "MemberProfile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("member.privacy.sheetBody")
            }
            Section {
                NavigationLink {
                    SettingsLegalDocumentView(type: .privacyPolicy, market: market, reader: legalReader)
                } label: { Text(LocalizedStringKey(SettingsLegalType.privacyPolicy.titleKey)) }
            }
            Section {
                SettingsHomeCityLocationControls(compliance: compliance)
            } header: { Text("member.privacy.homeCity.title", tableName: "MemberProfile") }
            Section {
                NavigationLink { OwnMediaReviewView(reader: mediaReader, imagePreview: imagePreview, approvedLink: approvedLink, audioPreview: audioPreview, modelPreview: modelPreview) } label: {
                    Text("member.privacy.media.open", tableName: "MemberProfile")
                }.accessibilityIdentifier("member.privacy.media")
            } header: { Text("member.privacy.media.title", tableName: "MemberProfile") }
            Section {
                Text("member.privacy.presence.detail", tableName: "MemberProfile").font(.subheadline).foregroundStyle(.secondary)
                if presenceSharing != false {
                Button {
                    guard let disablePresence, !disablingPresence else { return }
                    disablingPresence = true
                    Task {
                        let outcome = await disablePresence()
                        disablingPresence = false
                        switch outcome {
                        case .disabled:
                            toastTone = .success
                            toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                                "已关闭附近的人位置分享",
                                "Nearby presence sharing turned off",
                                locale: locale))
                        case .rejected(let msg):
                            toastTone = .warning
                            toastMessage = LocalizedStringKey(msg ?? MemberPopupCopy.text(
                                "关闭位置分享失败，请稍后重试",
                                "Failed to turn off presence sharing",
                                locale: locale))
                        case .unavailable, .failed:
                            toastTone = .warning
                            toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                                "关闭位置分享失败，请稍后重试",
                                "Failed to turn off presence sharing",
                                locale: locale))
                        }
                    }
                } label: { Text("member.privacy.presence.off", tableName: "MemberProfile") }
                    .disabled(disablePresence == nil || disablingPresence)
                    .accessibilityIdentifier("member.privacy.presence.off")
                }
            } header: { Text("member.privacy.presence.title", tableName: "MemberProfile") } footer: {
                if disablePresence == nil {
                    Text("member.privacy.presence.unavailable", tableName: "MemberProfile")
                }
            }
            Section {
                Text("member.privacy.roam.detail", tableName: "MemberProfile").font(.subheadline).foregroundStyle(.secondary)
                if compliance != nil {
                    // B-PV-02 (native iOS): a plain system button row opens the withdrawal sheet; no pill inside a Form.
                    Button { showsRoam = true } label: {
                        Text("member.privacy.roam.withdraw", tableName: "MemberProfile")
                    }
                    .accessibilityIdentifier("member.privacy.roam.withdraw")
                }
            } header: { Text("member.privacy.roam.title", tableName: "MemberProfile") }
            SessionLocationHoldsSection()
        }
        // B-PV-03 (T&C §2): pushed page → one inline system title, no in-content hero title.
        .navigationTitle(Text("member.privacy.title", tableName: "MemberProfile")).navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .cyToast(message: $toastMessage, tone: toastTone)
        .onAppear {
            if let compliance { lastRoamCleanup = compliance.state.roamCleanup }
        }
        .task { presenceSharing = await readPresence?() }
        .cySheet(isPresented: $showsRoam, onDismiss: {
            guard let compliance else { return }
            let feedback = RoamConsentWithdrawalFeedback.evaluate(
                previous: lastRoamCleanup,
                current: compliance.state.roamCleanup,
                error: compliance.state.error)
            lastRoamCleanup = compliance.state.roamCleanup
            if feedback == .withdrawn {
                toastTone = .success
                toastMessage = LocalizedStringKey(MemberPopupCopy.text(
                    "已撤回漫游定位同意",
                    "Roam location consent withdrawn",
                    locale: locale))
            }
        }) {
            if let compliance {
                NavigationStack {
                    AccountComplianceSheet(coordinator: compliance, destination: .roam, market: market, legalReader: legalReader)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .cyDomainScreen(.player)
    }
}

/// 我的待审媒体: newest first, 50 per page, older pages by `beforeId`.
/// The controller, not unstructured button tasks, owns each visible read lifetime.
@MainActor struct OwnMediaReviewView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: OwnMediaReviewController
    private let statusReader: (any OwnMediaStatusReading)?
    private let imagePreview: OwnMediaImagePreviewAccess?
    private let approvedLink: OwnMediaApprovedLinkAccess?
    private let audioPreview: OwnMediaAudioPreviewAccess?
    private let modelPreview: OwnMediaModelPreviewAccess?
    init(reader: any OwnMediaReading, imagePreview: OwnMediaImagePreviewAccess? = nil, approvedLink: OwnMediaApprovedLinkAccess? = nil, audioPreview: OwnMediaAudioPreviewAccess? = nil, modelPreview: OwnMediaModelPreviewAccess? = nil) {
        self.modelPreview = modelPreview
        self.audioPreview = audioPreview
        self.approvedLink = approvedLink
        self.imagePreview = imagePreview
        _controller = State(initialValue: OwnMediaReviewController(reader: reader))
        statusReader = reader as? any OwnMediaStatusReading
    }
    var body: some View {
        List {
            switch controller.phase {
            case .idle, .loading:
                ProgressView("mpd.common.loading").frame(maxWidth: .infinity).accessibilityIdentifier("member.media.loading") // P10
            case .signedOut: mediaState("member.media.signedOut", systemImage: "person.crop.circle")
            case .unavailable: mediaState("member.media.unavailable", systemImage: "nosign")
            case .denied: mediaState("member.media.denied", systemImage: "lock")
            case .failed:
                VStack(alignment: .leading, spacing: 6) {
                    Text("member.media.failed", tableName: "MemberProfile")
                    Button { controller.retry() } label: { Text("member.media.refresh", tableName: "MemberProfile") }
                        .buttonStyle(.bordered)
                        .disabled(!controller.canRetry).accessibilityIdentifier("member.media.retry")
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("member.media.failed")
            case .ready:
                if controller.rows.isEmpty {
                    mediaState("member.media.empty", systemImage: "photo.on.rectangle")
                }
                ForEach(controller.rows) { row in
                    OwnMediaRow(asset: row).accessibilityIdentifier("member.media.row.\(row.id)")
                    OwnMediaImagePreviewButton(asset: row, access: imagePreview,
                        currentAsset: { controller.rows.first { $0.id == row.id } })
                    OwnMediaApprovedLinkCopyButton(asset: row, access: approvedLink,
                        currentAsset: { controller.rows.first { $0.id == row.id } })
                    OwnMediaAudioPreviewButton(asset: row, access: audioPreview,
                        currentAsset: { controller.rows.first { $0.id == row.id } })
                    OwnMediaModelPreviewButton(asset: row, access: modelPreview,
                        currentAsset: { controller.rows.first { $0.id == row.id } })
                    if let statusReader, statusReader.isStatusAvailable {
                        OwnMediaStatusButton(reader: statusReader, assetID: row.id) { _ = controller.refresh() }
                    }
                    if let retryReader = statusReader as? any OwnMediaRetryWriting {
                        OwnMediaRetryButton(reader: retryReader, asset: row) { _ = controller.refresh() }
                    }
                }
                if controller.moreFailed {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("member.media.failed", tableName: "MemberProfile").foregroundStyle(.secondary)
                        Button { controller.retry() } label: { Text("member.media.older", tableName: "MemberProfile") }
                            .disabled(!controller.canRetry).accessibilityIdentifier("member.media.retryOlder")
                    }.accessibilityElement(children: .contain)
                        .accessibilityIdentifier("member.media.moreFailed")
                } else if controller.nextCursor != nil {
                    Button { controller.more() } label: {
                        CYBusyLabel(busy: controller.loadingMore) { Text("member.media.older", tableName: "MemberProfile") }
                    }.disabled(!controller.canLoadMore).accessibilityLabel(Text("member.media.older", tableName: "MemberProfile")).accessibilityIdentifier("member.media.older")
                }
            }
        }
        .navigationTitle(Text("member.privacy.media.title", tableName: "MemberProfile")).navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .privacySensitive()
        .toolbar {
            if controller.phase == .ready || controller.phase == .failed || controller.phase == .denied {
                Button { _ = controller.refresh() } label: { Text("member.media.refresh", tableName: "MemberProfile") }
                    .disabled(controller.isLoading && !controller.loadingMore)
                    .accessibilityIdentifier("member.media.refresh")
            }
        }
        .onAppear { controller.appear(foreground: scenePhase == .active) }
        .onDisappear { controller.disappear() }
        .onChange(of: scenePhase) { _, phase in controller.setForeground(phase == .active) }
        .onChange(of: controller.access) { _, _ in controller.synchronizeAccess() }
    }
    /// Native r2: the system empty / gated state, its title carrying the old message identifier.
    private func mediaState(_ key: String, systemImage: String) -> some View {
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(key), tableName: "MemberProfile")
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .accessibilityIdentifier(key)
    }
}

struct OwnMediaRow: View {
    let asset: OwnMediaAsset
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                type
                Text(verbatim: "#\(asset.id)").foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                state.font(.subheadline.weight(.medium))
            }
            if !asset.reviewReason.isEmpty { Text(verbatim: asset.reviewReason).font(.subheadline).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
    @ViewBuilder private var type: some View {
        switch asset.mediaType {
        case .image: Text("member.media.type.image", tableName: "MemberProfile")
        case .audio: Text("member.media.type.audio", tableName: "MemberProfile")
        case .model3D: Text("member.media.type.model", tableName: "MemberProfile")
        case .other: Text("member.media.type.other", tableName: "MemberProfile")
        }
    }
    @ViewBuilder private var state: some View {
        switch asset.reviewState {
        case .hold: Text("member.media.state.hold", tableName: "MemberProfile").foregroundStyle(CYColor.warningText)
        case .approved: Text("member.media.state.approved", tableName: "MemberProfile").foregroundStyle(CYColor.successText)
        case .rejected: Text("member.media.state.rejected", tableName: "MemberProfile").foregroundStyle(CYColor.dangerText)
        case .unavailable: Text("member.media.state.unavailable", tableName: "MemberProfile").foregroundStyle(.secondary)
        }
    }
}

/// pages/privacy 「首页城市自动定位」. B-PV-02 (native iOS, hand-off MR-40): one system `Toggle`.
/// Turning it on confirms first, then records AGREE; turning it off records REVOKE. The initial
/// position is the latest `privacy_policy` / `home_city_location` row; no row reads as off.
/// A missing coordinator keeps the toggle visible and reports that the setting was not saved.
@MainActor private struct SettingsHomeCityLocationControls: View {
    let compliance: AccountComplianceCoordinator?
    @State private var busy = false
    @State private var confirmEnable = false
    @State private var isOn = false
    @State private var loaded = false
    @State private var messageKey: String?

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { requested in
            guard !busy else { return }
            if requested { confirmEnable = true } else { Task { await write(enabled: false) } }
        })) {
            Text("member.privacy.homeCity.title", tableName: "MemberProfile")
        }
        .disabled(busy)
        .accessibilityIdentifier("member.privacy.homeCity.toggle")
        .accessibilityHint(Text("member.privacy.sheetBody", tableName: "MemberProfile"))
        .confirmationDialog(Text("homeCityConsent.title"), isPresented: $confirmEnable, titleVisibility: .visible) {
            Button("homeCityConsent.agree") { Task { await write(enabled: true) } }
                .accessibilityLabel(Text("homeCityConsent.agree"))
                .accessibilityValue(Text("member.privacy.homeCity.on", tableName: "MemberProfile"))
                .accessibilityHint(Text("homeCityConsent.body"))
            Button("homeCityConsent.decline", role: .cancel) {}
                .accessibilityLabel(Text("homeCityConsent.decline"))
                .accessibilityValue(Text("member.privacy.homeCity.off", tableName: "MemberProfile"))
                .accessibilityHint(Text("homeCityConsent.body"))
        } message: {
            Text("homeCityConsent.body")
        }
        .task {
            guard !loaded, let compliance else { return }
            loaded = true
            if let baseline = try? await compliance.latestHomeCityLocationConsent() {
                isOn = baseline.consent?.matches(.homeCityLocation, event: .agree) ?? false
            }
        }
        if let shown = messageKey {
            Text(LocalizedStringKey(shown), tableName: "MemberProfile")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("member.privacy.homeCity.status")
        }
    }

    private func write(enabled: Bool) async {
        guard !busy else { return }
        guard let compliance else {
            messageKey = "member.privacy.homeCity.saveFailed"
            return
        }
        busy = true
        defer { busy = false }
        do {
            if enabled {
                _ = try await compliance.recordHomeCityLocationAgree()
                isOn = true
                messageKey = "member.privacy.homeCity.enabled"
            } else {
                _ = try await compliance.recordHomeCityLocationRevoke()
                isOn = false
                messageKey = "member.privacy.homeCity.disabled"
            }
        } catch {
            messageKey = "member.privacy.homeCity.saveFailed"
        }
    }
}
