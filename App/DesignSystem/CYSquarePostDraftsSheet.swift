import SwiftUI

/// Mini `square/components/cy/post-drafts` (Figma 379:923): T4 full sheet over the composer.
/// Header: large left title + round close; Loading uses the row geometry; Filled rows (avatar, name,
/// date, two-line summary, trash); "only N drafts" footer; Empty is a real state, never a blank panel.
/// Delete has no confirm (owner 2026-10-23): the row leaves at once and an undo bar stays 4 s;
/// only then is the draft actually discarded.
struct CYSquarePostDraftRow: Identifiable, Equatable {
    let id: String
    let summary: String?
    let updatedAt: Date
    var nickname: String? = nil
    var avatar: String? = nil
    /// A draft with a send in flight cannot be deleted.
    var locked = false
}

struct CYSquarePostDraftsSheet: View {
    let loading: Bool
    let drafts: [CYSquarePostDraftRow]
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var undoID: String?
    @State private var undoTask: Task<Void, Never>?
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private static let undoSeconds: UInt64 = 4

    private var visible: [CYSquarePostDraftRow] { drafts.filter { $0.id != undoID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("drafts.title", tableName: "SocialParity").cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(CYTypography.label.weight(.semibold))
                        .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                        .background(Circle().fill(CYColor.actionSecondary))
                }
                .buttonStyle(.cyPressable)
                .accessibilityLabel(Text("drafts.close", tableName: "SocialParity"))
                .accessibilityIdentifier("square.drafts.close")
            }
            .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.lg).padding(.bottom, CYSpacing.md)
            Divider().overlay(CYColor.borderSubtle)
            ScrollView {
                Group {
                    if loading {
                        VStack(spacing: CYSpacing.lg) { ForEach(0..<3, id: \.self) { _ in skeletonRow } }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("drafts.loading", tableName: "SocialParity"))
                            .accessibilityIdentifier("square.drafts.loading")
                    } else if visible.isEmpty {
                        CYEmptyState(systemImage: "doc.text", "drafts.empty", tableName: "SocialParity",
                                     detailVerbatim: String(localized: "drafts.emptyDetail", table: "SocialParity"),
                                     messageIdentifier: "square.drafts.empty")
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(visible) { row in
                                draftRow(row)
                                    .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                            }
                            Text("drafts.count \(visible.count)", tableName: "SocialParity")
                                .cyText(.caption).foregroundStyle(CYColor.textTertiary)
                                .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.lg)
                        }
                        .accessibilityIdentifier("square.drafts.list")
                    }
                }
                .padding(.horizontal, CYSpacing.lg)
            }
        }
        .safeAreaInset(edge: .bottom) { if undoID != nil { undoBar } }
        .background(CYDomainPalette(.player).sheetGlass.ignoresSafeArea())
        .presentationDetents([.large])
        .cyPlayerSheetGlass()
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: visible)
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: undoID)
        .onDisappear { commitPending() }
        .accessibilityIdentifier("square.drafts")
    }

    private func draftRow(_ row: CYSquarePostDraftRow) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Button { commitPending(); dismiss(); onSelect(row.id) } label: {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    SquareAuthorAvatar(source: row.avatar, size: 40)
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Group { if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                draftName(row).lineLimit(2)
                                draftDate(row)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                draftName(row)
                                Spacer(minLength: CYSpacing.sm)
                                draftDate(row)
                            }
                        } }
                        .cyText(.label, weight: .semibold).foregroundStyle(CYColor.textPrimary)
                        Group {
                            if let summary = row.summary, !summary.isEmpty { Text(verbatim: summary) } else { Text("drafts.untitled", tableName: "SocialParity") }
                        }
                        .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.cyPressable)
            .accessibilityHint(Text("drafts.resumeHint", tableName: "SocialParity"))
            .accessibilityIdentifier("square.drafts.row.\(row.id)")
            Button { startUndo(row.id) } label: {
                Image(systemName: "trash").font(CYTypography.label).foregroundStyle(row.locked ? CYColor.textDisabled : CYColor.textSecondary)
                    .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.cyPressable)
            .disabled(row.locked)
            .accessibilityLabel(Text("drafts.delete", tableName: "SocialParity"))
            .accessibilityIdentifier("square.drafts.delete.\(row.id)")
        }
        .padding(.vertical, CYSpacing.md)
        .overlay(alignment: .bottom) { Divider().overlay(CYColor.borderSubtle) }
    }

    private var skeletonRow: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Circle().fill(CYColor.sheetCard).frame(width: 40, height: 40)
            CYSkeleton()
        }
    }

    private var undoBar: some View {
        HStack {
            Text("drafts.deleted", tableName: "SocialParity").cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
            Spacer()
            Button { undoTask?.cancel(); undoTask = nil; undoID = nil } label: {
                Text("drafts.undo", tableName: "SocialParity").cyText(.label, weight: .semibold).foregroundStyle(CYColor.brand)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.cyPressable)
            .accessibilityIdentifier("square.drafts.undo")
        }
        .padding(.horizontal, CYSpacing.lg)
        .background(Capsule().fill(CYColor.sheetCard).overlay(Capsule().strokeBorder(CYColor.borderSubtle, lineWidth: 1)))
        .padding(CYSpacing.lg)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder private func draftName(_ row: CYSquarePostDraftRow) -> some View {
        if let name = row.nickname, !name.isEmpty { Text(verbatim: name) } else { Text("drafts.me", tableName: "SocialParity") }
    }

    private func draftDate(_ row: CYSquarePostDraftRow) -> some View {
        Text(row.updatedAt, format: .dateTime.month().day().hour().minute())
            .cyText(.caption, monospacedDigit: true).foregroundStyle(CYColor.textTertiary)
    }

    private func startUndo(_ id: String) {
        commitPending()
        undoID = id
        undoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.undoSeconds * 1_000_000_000)
            guard !Task.isCancelled, undoID == id else { return }
            commitPending()
        }
    }

    /// Discards the draft behind the undo bar now (timer ran out, another delete, or the sheet closed).
    private func commitPending() {
        undoTask?.cancel(); undoTask = nil
        guard let id = undoID else { return }
        undoID = nil
        onDelete(id)
    }
}
