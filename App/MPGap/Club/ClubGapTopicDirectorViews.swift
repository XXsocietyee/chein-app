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

    /// CLB-r9-native-02: catalog keys instead of the Core Chinese literals; system buttons and sections.
    public var body: some View {
        Group {
            if summary.hasUnknownWrite {
                Section {
                    if let label = summary.unknownWriteLabel {
                        Text(verbatim: label)
                    } else {
                        Text("club.director.unknownWrite")
                    }
                    HStack {
                        Button("club.director.confirmResult", action: onConfirmUnknownWrite)
                            .buttonStyle(.bordered)
                        Button("club.director.retryOriginal", action: onRetryUnknownWrite)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            // CLB-G13c: 准备总览 moved to `ClubTopicDirectorReadySection` (preparing only, MP wxml:244-261).
            Section {
                ForEach(ClubTopicDirectorToolKind.allCases) { tool in
                    Button {
                        onOpenTool(tool)
                    } label: {
                        Label(LocalizedStringKey("club.director.tool." + tool.rawValue), systemImage: tool.systemImage)
                    }
                }
            } header: {
                Text("club.director.tools")
            }

            Section {
                Button {
                    onToggleLeaderboardVisibility()
                } label: {
                    Label(summary.leaderboardHidden ? LocalizedStringKey("club.director.showLeaderboard") : LocalizedStringKey("club.director.hideLeaderboard"),
                          systemImage: summary.leaderboardHidden ? "eye" : "eye.slash")
                }
            } header: {
                Text("club.director.leaderboard")
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
        Menu("club.director.more") {
            if canEditContent {
                Button("club.director.editTopic", action: onEditContent)
            }
            if canConfirmFinalPrice {
                Button("club.director.confirmFinalPrice", action: onConfirmFinalPrice)
            }
            if canReviewUndertake {
                Button("club.director.reviewUndertake", action: onReviewUndertake)
            }
        }
    }
}
