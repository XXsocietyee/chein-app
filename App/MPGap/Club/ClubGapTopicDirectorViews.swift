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
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text(verbatim: summary.unknownWriteLabel ?? ClubTopicDirectorCopy.unknownWriteTitle)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                        HStack(spacing: CYSpacing.sm) {
                            Button(ClubTopicDirectorCopy.confirmResult, action: onConfirmUnknownWrite)
                                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            Button(ClubTopicDirectorCopy.retryOriginalAction, action: onRetryUnknownWrite)
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                        }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
            }

            // CLB-G13c: 准备总览 moved to `ClubTopicDirectorReadySection` (preparing only, MP wxml:244-261).
            Section {
                ForEach(ClubTopicDirectorToolKind.allCases) { tool in
                    Button {
                        onOpenTool(tool)
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                            .cyText(.body)
                    }
                }
            } header: {
                Text(verbatim: ClubTopicDirectorCopy.directorToolsTitle).cyText(.sectionTitle)
            }

            Section {
                Button {
                    onToggleLeaderboardVisibility()
                } label: {
                    Label(
                        summary.leaderboardHidden ? ClubTopicDirectorCopy.showLeaderboard : ClubTopicDirectorCopy.hideLeaderboard,
                        systemImage: summary.leaderboardHidden ? "eye" : "eye.slash"
                    )
                    .cyText(.body)
                }
            } header: {
                Text(verbatim: ClubTopicDirectorCopy.leaderboardTitle).cyText(.sectionTitle)
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
