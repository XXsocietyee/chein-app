import SwiftUI

/// Settings row 隐私与定位 (mini-program `pages/shezhi` privacy sheet), placed
/// after 我的收藏 as in the source. Nothing here writes: presence sharing has
/// no reviewed write path yet, and roam withdrawal reuses the existing flow.
@MainActor struct SettingsPrivacyLocationEntry: View {
    let session: AppSession
    var body: some View {
        if session.account != nil {
            Section {
                NavigationLink {
                    SettingsPrivacyLocationView(mediaReader: session.ownMediaReader,
                        compliance: session.accountComplianceCoordinator, market: session.operationalMarket, imagePreview: session.ownMediaImagePreviewAccess, approvedLink: session.ownMediaApprovedLinkAccess, audioPreview: session.ownMediaAudioPreviewAccess, modelPreview: session.ownMediaModelPreviewAccess, legalReader: session.legalReader)
                } label: {
                    Label { Text("member.privacy.title", tableName: "MemberProfile") } icon: { Image(systemName: "hand.raised") }
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
    @State private var showsRoam = false
    @State private var homeAutoLocationEnabled = !HomeCityLocationDeclineStore.read()

    var body: some View {
        Form {
            Section { CYHeroHeader("member.privacy.title", tableName: "MemberProfile").listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            // Mini-program privacy sheet: the location sentence, the guide, then home city, presence, roam and own media.
            Section {
                Text("member.privacy.sheetBody", tableName: "MemberProfile")
                    .font(.footnote)
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
                Text("member.privacy.presence.detail", tableName: "MemberProfile").font(.footnote).foregroundStyle(.secondary)
                Button {} label: { Text("member.privacy.presence.off", tableName: "MemberProfile") }
                    .disabled(true).accessibilityIdentifier("member.privacy.presence.off")
            } header: { Text("member.privacy.presence.title", tableName: "MemberProfile") } footer: { Text("member.privacy.presence.unavailable", tableName: "MemberProfile") }
            Section {
                Text("member.privacy.roam.detail", tableName: "MemberProfile").font(.footnote).foregroundStyle(.secondary)
                if compliance != nil {
                    CYPillButton("member.privacy.roam.withdraw", style: .secondary, tableName: "MemberProfile") { showsRoam = true }
                        .accessibilityIdentifier("member.privacy.roam.withdraw")
                }
            } header: { Text("member.privacy.roam.title", tableName: "MemberProfile") }
            SessionLocationHoldsSection()
            Section {
                NavigationLink { OwnMediaReviewView(reader: mediaReader, imagePreview: imagePreview, approvedLink: approvedLink, audioPreview: audioPreview, modelPreview: modelPreview) } label: {
                    Text("member.privacy.media.open", tableName: "MemberProfile")
                }.accessibilityIdentifier("member.privacy.media")
            } header: { Text("member.privacy.media.title", tableName: "MemberProfile") }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .cyHideTabBar()
        .sheet(isPresented: $showsRoam) {
            if let compliance {
                NavigationStack {
                    AccountComplianceSheet(coordinator: compliance, destination: .roam, market: market, legalReader: legalReader)
                }
                .cyDomainSheet(detents: [.half, .full])
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
            Section { CYHeroHeader("member.privacy.media.title", tableName: "MemberProfile").listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            switch controller.phase {
            case .idle, .loading: CYLoadingStateView(rows: 3).accessibilityIdentifier("member.media.loading")
            case .signedOut: CYEmptyState(systemImage: "person.crop.circle", "member.media.signedOut", tableName: "MemberProfile", messageIdentifier: "member.media.signedOut")
            case .unavailable: CYEmptyState(systemImage: "nosign", "member.media.unavailable", tableName: "MemberProfile", messageIdentifier: "member.media.unavailable")
            case .denied: CYEmptyState(systemImage: "lock", "member.media.denied", tableName: "MemberProfile", messageIdentifier: "member.media.denied")
            case .failed:
                VStack(alignment: .leading, spacing: 6) {
                    Text("member.media.failed", tableName: "MemberProfile")
                    CYPillButton("member.media.refresh", style: .secondary, tableName: "MemberProfile") { controller.retry() }
                        .disabled(!controller.canRetry).accessibilityIdentifier("member.media.retry")
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("member.media.failed")
            case .ready:
                if controller.rows.isEmpty {
                    CYEmptyState(systemImage: "photo.on.rectangle", "member.media.empty", tableName: "MemberProfile", messageIdentifier: "member.media.empty")
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
                        if controller.loadingMore { ProgressView() } else { Text("member.media.older", tableName: "MemberProfile") }
                    }.disabled(!controller.canLoadMore).accessibilityLabel(Text("member.media.older", tableName: "MemberProfile")).accessibilityIdentifier("member.media.older")
                }
            }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
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
}

struct OwnMediaRow: View {
    @Environment(\.cyPalette) private var palette
    let asset: OwnMediaAsset
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                type
                Text(verbatim: "#\(asset.id)").foregroundStyle(.secondary).font(.footnote.monospacedDigit())
                Spacer()
                state.font(.subheadline.weight(.semibold))
            }
            if !asset.reviewReason.isEmpty { Text(verbatim: asset.reviewReason).font(.footnote).foregroundStyle(.secondary) }
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
        case .hold: Text("member.media.state.hold", tableName: "MemberProfile").foregroundStyle(palette.warning)
        case .approved: Text("member.media.state.approved", tableName: "MemberProfile").foregroundStyle(palette.success)
        case .rejected: Text("member.media.state.rejected", tableName: "MemberProfile").foregroundStyle(palette.danger)
        case .unavailable: Text("member.media.state.unavailable", tableName: "MemberProfile").foregroundStyle(.secondary)
        }
    }
}

/// pages/privacy 「首页城市自动定位」. 开启 confirms, then records AGREE. 关闭 records REVOKE.
/// A missing coordinator leaves both buttons visible and reports that the setting was not saved.
@MainActor private struct SettingsHomeCityLocationControls: View {
    let compliance: AccountComplianceCoordinator?
    @State private var busy = false
    @State private var confirmEnable = false
    @State private var messageKey: String?

    var body: some View {
        Button { confirmEnable = true } label: {
            Text("member.privacy.homeCity.on", tableName: "MemberProfile")
        }
        .disabled(busy)
        .accessibilityIdentifier("member.privacy.homeCity.on")
        .accessibilityLabel(Text("member.privacy.homeCity.on", tableName: "MemberProfile"))
        .accessibilityValue(homeCitySpokenValue)
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
        Button { Task { await write(enabled: false) } } label: {
            Text("member.privacy.homeCity.off", tableName: "MemberProfile")
        }
        .disabled(busy)
        .accessibilityIdentifier("member.privacy.homeCity.off")
        .accessibilityLabel(Text("member.privacy.homeCity.off", tableName: "MemberProfile"))
        .accessibilityValue(homeCitySpokenValue)
        .accessibilityHint(Text("member.privacy.sheetBody", tableName: "MemberProfile"))
        if let shown = messageKey {
            Text(LocalizedStringKey(shown), tableName: "MemberProfile")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("member.privacy.homeCity.status")
        }
    }

    /// No saved setting yet is unknown, spoken as an em dash. A later status sentence is the copy already on the row.
    private var homeCitySpokenValue: Text {
        if let messageKey {
            return Text(LocalizedStringKey(messageKey), tableName: "MemberProfile")
        }
        return Text(verbatim: "—")
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
                messageKey = "member.privacy.homeCity.enabled"
            } else {
                _ = try await compliance.recordHomeCityLocationRevoke()
                messageKey = "member.privacy.homeCity.disabled"
            }
        } catch {
            messageKey = "member.privacy.homeCity.saveFailed"
        }
    }
}
