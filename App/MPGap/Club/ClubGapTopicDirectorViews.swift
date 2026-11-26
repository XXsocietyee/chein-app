import SwiftUI

/// Mount hook for `ClubGovernanceViews` (topic detail) — `CLB-G13` (embedded 导演台 sections)
/// & `CLB-G12` (rejected resubmission + 更多 menu + 选择导演场次).
public struct ClubGapTopicDirectorEmbeddedSection: View {
    public let summary: ClubTopicDirectorSummary
    public let onConfirmUnknownWrite: () -> Void
    public let onRetryUnknownWrite: () -> Void
    public let onOpenTool: (ClubTopicDirectorToolKind) -> Void
    public let onToggleLeaderboardVisibility: () -> Void

    public init(
        summary: ClubTopicDirectorSummary,
        onConfirmUnknownWrite: @escaping () -> Void,
        onRetryUnknownWrite: @escaping () -> Void,
        onOpenTool: @escaping (ClubTopicDirectorToolKind) -> Void,
        onToggleLeaderboardVisibility: @escaping () -> Void
    ) {
        self.summary = summary
        self.onConfirmUnknownWrite = onConfirmUnknownWrite
        self.onRetryUnknownWrite = onRetryUnknownWrite
        self.onOpenTool = onOpenTool
        self.onToggleLeaderboardVisibility = onToggleLeaderboardVisibility
    }

    public var body: some View {
        Group {
            if summary.hasUnknownWrite {
                Section {
                    Label {
                        Text(verbatim: summary.unknownWriteLabel ?? ClubTopicDirectorCopy.unknownWriteTitle)
                    } icon: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.orange)
                    }
                    Button(ClubTopicDirectorCopy.confirmResult, action: onConfirmUnknownWrite)
                    Button(ClubTopicDirectorCopy.retryOriginalAction, action: onRetryUnknownWrite)
                }
            }

            Section {
                LabeledContent("站点准备", value: "\(summary.readyStations) / \(summary.totalStations)")
                LabeledContent("进行中队伍", value: "\(summary.activeTeams)")
            } header: {
                Text(verbatim: ClubTopicDirectorCopy.prepOverviewTitle)
            } footer: {
                if let caption = summary.caption, !caption.isEmpty {
                    Text(verbatim: caption)
                }
            }

            Section {
                ForEach(ClubTopicDirectorToolKind.allCases) { tool in
                    Button {
                        onOpenTool(tool)
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                    }
                }
            } header: {
                Text(verbatim: ClubTopicDirectorCopy.directorToolsTitle)
            }

            Section {
                Button {
                    onToggleLeaderboardVisibility()
                } label: {
                    Label(
                        summary.leaderboardHidden ? ClubTopicDirectorCopy.showLeaderboard : ClubTopicDirectorCopy.hideLeaderboard,
                        systemImage: summary.leaderboardHidden ? "eye" : "eye.slash"
                    )
                }
            } header: {
                Text(verbatim: ClubTopicDirectorCopy.leaderboardTitle)
            }
        }
    }
}

/// Mount hook for `ClubGovernanceViews` (topic detail toolbar) — `CLB-G12`:
/// `更多` menu (`编辑主题内容`, `确认终价`, `承接审核`) & `修改并重新提交` for rejected topics.
public struct ClubGapTopicMoreMenu: View {
    public let canEditContent: Bool
    public let canConfirmFinalPrice: Bool
    public let canReviewUndertake: Bool
    public let onEditContent: () -> Void
    public let onConfirmFinalPrice: () -> Void
    public let onReviewUndertake: () -> Void

    public init(
        canEditContent: Bool,
        canConfirmFinalPrice: Bool,
        canReviewUndertake: Bool,
        onEditContent: @escaping () -> Void,
        onConfirmFinalPrice: @escaping () -> Void,
        onReviewUndertake: @escaping () -> Void
    ) {
        self.canEditContent = canEditContent
        self.canConfirmFinalPrice = canConfirmFinalPrice
        self.canReviewUndertake = canReviewUndertake
        self.onEditContent = onEditContent
        self.onConfirmFinalPrice = onConfirmFinalPrice
        self.onReviewUndertake = onReviewUndertake
    }

    public var body: some View {
        Menu(ClubTopicDirectorCopy.moreMenuTitle) {
            if canEditContent {
                Button(ClubTopicDirectorCopy.editTopicContent, action: onEditContent)
            }
            if canConfirmFinalPrice {
                Button(ClubTopicDirectorCopy.confirmFinalPrice, action: onConfirmFinalPrice)
            }
            if canReviewUndertake {
                Button(ClubTopicDirectorCopy.reviewUndertake, action: onReviewUndertake)
            }
        }
    }
}
