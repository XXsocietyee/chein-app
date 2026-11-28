import SwiftUI

/// CLB-G05: 「带上一次游玩记录」 in the club composer (MP `pages/square/components/cy/post-compose/index.wxml:63-92`
/// chip + tool, picker sheet `pages/club/detail/index.wxml:669-686`, load `index.js:1975-2004`).
/// The picker reads lazily the first time it opens, like `openPostRefPicker`.
struct ClubGapPlayRecordPickerRow: View {
    @Binding var selected: ClubPostRefOption?
    let load: () async throws -> [ClubPostRefOption]

    private enum LoadState: Equatable { case idle, loading, ready([ClubPostRefOption]), failed(String?) }
    @State private var showPicker = false
    @State private var state: LoadState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected {
                // MP cmp-chip: the picked record with an ✕ that clears it.
                HStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(verbatim: selected.title)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button { self.selected = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text("club.postRef.clear"))
                }
                .accessibilityElement(children: .combine)
            }
            Button {
                showPicker = true
                if case .ready = state { return }
                Task { await reload() }
            } label: {
                Label("club.postRef.pick", systemImage: "flag")
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
            .accessibilityIdentifier("club.community.postRef")
        }
        .cySheet(isPresented: $showPicker) {
            NavigationStack {
                List { pickerContent }
                    .navigationTitle(Text("club.postRef.pick"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.close") { showPicker = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        switch state {
        case .idle, .loading:
            ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
        case let .failed(message):
            ContentUnavailableView {
                Label("club.postRef.loadFailed", systemImage: "exclamationmark.triangle")
            } description: {
                if let message, !message.isEmpty { Text(verbatim: message) } else { Text("club.postRef.readFailed") }
            } actions: {
                Button("action.reload") { Task { await reload() } }
            }
        case let .ready(options):
            if options.isEmpty {
                ContentUnavailableView { Label("club.postRef.empty", systemImage: "tray") }
            } else {
                ForEach(options) { option in
                    Button {
                        selected = option
                        showPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: option.title).foregroundStyle(.primary)
                                Text(LocalizedStringKey(option.refType == 1 ? "club.postRef.kind.activity" : "club.postRef.kind.topic"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if selected == option {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint).accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(selected == option ? .isSelected : [])
                }
            }
        }
    }

    private func reload() async {
        state = .loading
        do {
            state = .ready(try await load())
        } catch let refusal as MPGapServerRefusal {
            state = .failed(refusal.message)
        } catch {
            state = .failed(nil)
        }
    }
}

/// Mount hook for `ClubDetailView` (活动 tab card) & `ClubDetailView` (管理 tab) — `CLB-G01` & `CLB-G02`:
/// Merchant `邀约承接` button & Club-scoped `扫码核销` quick action.
public struct ClubGapActivityAndScanActions: View {
    public let showsUndertake: Bool
    public let showsScanVerify: Bool
    public let onTapUndertake: () -> Void
    public let onTapScanVerify: () -> Void

    public init(
        showsUndertake: Bool,
        showsScanVerify: Bool,
        onTapUndertake: @escaping () -> Void,
        onTapScanVerify: @escaping () -> Void
    ) {
        self.showsUndertake = showsUndertake
        self.showsScanVerify = showsScanVerify
        self.onTapUndertake = onTapUndertake
        self.onTapScanVerify = onTapScanVerify
    }

    public var body: some View {
        HStack(spacing: 8) {
            if showsUndertake {
                Button(ClubScanCopy.undertakeTitle, action: onTapUndertake)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if showsScanVerify {
                Button(ClubScanCopy.scanActionTitle, action: onTapScanVerify)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

/// `CLB-G10`: follow-author pill on club post cards (MP `components/cy/post-card/index.wxml:15-17`). The MP only
/// follows from the card; after a tap it shows the done state and stays disabled.
struct ClubGapFollowAuthorButton: View {
    let isFollowing: Bool
    let onFollow: () -> Void

    var body: some View {
        let button = Button(action: onFollow) {
            Label(isFollowing ? "social.following" : "social.editor.follow",
                  systemImage: isFollowing ? "checkmark" : "plus")
        }
        .controlSize(.small)
        .disabled(isFollowing)
        .accessibilityIdentifier("club.community.follow")
        // Follow is prominent; the followed state is the quieter bordered button (Podcasts / Music follow buttons).
        if isFollowing { button.buttonStyle(.bordered) } else { button.buttonStyle(.borderedProminent) }
    }
}

/// Mount hook for `ClubOpsEventView` (`CLB-G15`):
/// 主持小费 `暂不可开通`, `paymentNotice`/`windowWarning` banners, and empty `发布主题` CTA.
public struct ClubGapEventOpsExtrasSection: View {
    public let paymentNotice: String?
    public let windowWarning: String?
    public let showsEmptyPublishCTA: Bool
    public let onTapPublishTopic: () -> Void

    public init(
        paymentNotice: String? = nil,
        windowWarning: String? = nil,
        showsEmptyPublishCTA: Bool = false,
        onTapPublishTopic: @escaping () -> Void
    ) {
        self.paymentNotice = paymentNotice
        self.windowWarning = windowWarning
        self.showsEmptyPublishCTA = showsEmptyPublishCTA
        self.onTapPublishTopic = onTapPublishTopic
    }

    public var body: some View {
        Group {
            if let paymentNotice, !paymentNotice.isEmpty {
                Section {
                    Text(verbatim: paymentNotice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let windowWarning, !windowWarning.isEmpty {
                Section {
                    Label(windowWarning, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                LabeledContent(ClubEventOpsGapCopy.hostTipTitle, value: ClubEventOpsGapCopy.hostTipUnavailable)
            }
            if showsEmptyPublishCTA {
                Section {
                    ContentUnavailableView {
                        Label(LocalizedStringKey(ClubEventOpsGapCopy.emptyTopicsTitle), systemImage: "sparkles")
                    } actions: {
                        Button(LocalizedStringKey(ClubEventOpsGapCopy.publishTopicCTA), action: onTapPublishTopic)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}
