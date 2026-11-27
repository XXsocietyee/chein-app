import SwiftUI

/// Mini `square/components/activity-picker`: "choose a completed activity" bottom sheet used by the
/// square composer to attach a finished play. States match the mini: skeleton, load failure with retry,
/// empty ("only completed activities are listed"), list rows (cover, name, done x/total · cleared, check).
/// The mini renders a hidden route map to snapshot a preview image; native shows the live route
/// card instead (`CYSquareRouteMapCard`), so selection returns at once with no upload step.
struct CYSquareActivityPicker: View {
    let provider: any SquareCompletedActivityProviding
    let onSelect: (CYSquareCompletedActivity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var attempt = 0
    @QuestifyReduceMotion private var reduceMotion
    private enum Phase: Equatable { case loading, failed, ready([CYSquareCompletedActivity]) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("activityPicker.title", tableName: "SocialParity").cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(CYTypography.label.weight(.semibold))
                        .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                        .background(Circle().fill(CYColor.actionSecondary))
                }
                .buttonStyle(.cyPressable)
                .accessibilityLabel(Text("activityPicker.close", tableName: "SocialParity"))
                .accessibilityIdentifier("square.activityPicker.close")
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            ScrollView {
                content.padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.xxl)
            }
        }
        .background(CYDomainPalette(.player).sheetGlass.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .cyPlayerSheetGlass()
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: phase)
        .task(id: attempt) { await load() }
        .accessibilityIdentifier("square.activityPicker")
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            VStack(spacing: CYSpacing.lg) { ForEach(0..<3, id: \.self) { _ in CYSkeleton() } }
                .accessibilityIdentifier("square.activityPicker.loading")
        case .failed:
            CYEmptyState(systemImage: "exclamationmark.triangle", "activityPicker.failed", tableName: "SocialParity",
                         detailVerbatim: String(localized: "activityPicker.failedDetail", table: "SocialParity"), messageIdentifier: "square.activityPicker.failed",
                         actionTitle: "action.retry", actionIdentifier: "square.activityPicker.retry", kind: .failure) { attempt += 1 }
        case .ready(let list) where list.isEmpty:
            CYEmptyState(systemImage: "flag.checkered", "activityPicker.empty", tableName: "SocialParity",
                         detailVerbatim: String(localized: "activityPicker.emptyDetail", table: "SocialParity"), messageIdentifier: "square.activityPicker.empty")
        case .ready(let list):
            LazyVStack(spacing: CYSpacing.sm) {
                ForEach(list) { activity in
                    Button { onSelect(activity); dismiss() } label: { row(activity) }
                        .buttonStyle(.cyPressable)
                        .accessibilityIdentifier("square.activityPicker.row.\(activity.id)")
                }
            }
        }
    }

    private func row(_ activity: CYSquareCompletedActivity) -> some View {
        HStack(spacing: CYSpacing.md) {
            Group {
                if let cover = activity.cover, let url = URL(string: cover), url.scheme == "https" {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { CYColor.bgRaised }
                    }
                } else { ZStack { CYColor.bgRaised; Image(systemName: "map").foregroundStyle(CYColor.textTertiary) } }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: activity.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                Text("activityPicker.progress \(Self.count(activity.doneCount)) \(Self.count(activity.total))", tableName: "SocialParity")
                    .cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill").font(CYTypography.sectionTitle).foregroundStyle(CYColor.brand)
                .accessibilityHidden(true)
        }
        .padding(CYSpacing.md)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.sheetCard))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Unknown counts read as an em dash, never as zero.
    private static func count(_ value: Int?) -> String { value.map(String.init) ?? "\u{2014}" }

    private func load() async {
        phase = .loading
        do {
            let list = try await provider.completedActivities()
            try Task.checkCancellation()
            phase = .ready(list)
        } catch is CancellationError {
        } catch { phase = .failed }
    }
}
