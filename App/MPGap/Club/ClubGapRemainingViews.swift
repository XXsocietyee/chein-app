import SwiftUI

/// Mount hook for `ClubCommunityViews` (post composer) — `CLB-G05`:
/// 带上一次游玩记录 picker sheet & attached row.
public struct ClubGapPlayRecordPickerRow: View {
    public let selected: ClubPostRefOption?
    public let options: [ClubPostRefOption]
    public let isLoading: Bool
    public let errorText: String?
    public let onSelect: (ClubPostRefOption?) -> Void
    public let onRetryLoad: () -> Void

    @State private var showPicker = false

    public init(
        selected: ClubPostRefOption?,
        options: [ClubPostRefOption],
        isLoading: Bool = false,
        errorText: String? = nil,
        onSelect: @escaping (ClubPostRefOption?) -> Void,
        onRetryLoad: @escaping () -> Void
    ) {
        self.selected = selected
        self.options = options
        self.isLoading = isLoading
        self.errorText = errorText
        self.onSelect = onSelect
        self.onRetryLoad = onRetryLoad
    }

    public var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                MPAsset.FeatureIcon.introTicketMap
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(verbatim: ClubPostRefCopy.pickerTitle)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                if let selected {
                    Text(verbatim: selected.title)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.brand)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                List {
                    pickerContent
                }
                .cyPageTitle(verbatim: ClubPostRefCopy.pickerTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { showPicker = false }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if selected != nil {
            Button(ClubPostRefCopy.clearSelection) {
                onSelect(nil)
                showPicker = false
            }
            .cyText(.body)
        }
        if isLoading {
            HStack { Spacer(); ProgressView(); Spacer() }
        } else if let errorText, !errorText.isEmpty {
            CYEmptyState(systemImage: "exclamationmark.triangle", verbatimTitle: ClubPostRefCopy.loadFailed, verbatimSubtitle: errorText, action: onRetryLoad)
        } else if options.isEmpty {
            CYEmptyState(systemImage: "tray", verbatimTitle: ClubPostRefCopy.emptyTitle)
        } else {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                    showPicker = false
                } label: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: option.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        if let sub = option.subtitle, !sub.isEmpty {
                            Text(verbatim: sub).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
            }
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
        HStack(spacing: CYSpacing.sm) {
            if showsUndertake {
                Button(ClubScanCopy.undertakeTitle, action: onTapUndertake)
                    .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
            }
            if showsScanVerify {
                Button(ClubScanCopy.scanActionTitle, action: onTapScanVerify)
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
            }
        }
    }
}

/// Mount hook for `ClubCommunityViews` (post header) — `CLB-G10`:
/// Inline follow-author pill button.
public struct ClubGapFollowAuthorButton: View {
    public let isFollowing: Bool
    public let isBusy: Bool
    public let onToggle: () -> Void

    public init(isFollowing: Bool, isBusy: Bool = false, onToggle: @escaping () -> Void) {
        self.isFollowing = isFollowing
        self.isBusy = isBusy
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(isFollowing ? "已关注" : "关注", action: onToggle)
            .buttonStyle(CYPillButtonStyle(style: isFollowing ? .secondary : .primary, fullWidth: false, compact: true))
            .disabled(isBusy)
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
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
            if let windowWarning, !windowWarning.isEmpty {
                Section {
                    Label(windowWarning, systemImage: "exclamationmark.triangle")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.warningText)
                }
            }
            Section {
                LabeledContent(ClubEventOpsGapCopy.hostTipTitle, value: ClubEventOpsGapCopy.hostTipUnavailable)
                    .cyText(.body)
            }
            if showsEmptyPublishCTA {
                Section {
                    CYEmptyState(
                        systemImage: "sparkles",
                        LocalizedStringKey(ClubEventOpsGapCopy.emptyTopicsTitle),
                        actionTitle: LocalizedStringKey(ClubEventOpsGapCopy.publishTopicCTA),
                        action: onTapPublishTopic
                    )
                }
            }
        }
    }
}
