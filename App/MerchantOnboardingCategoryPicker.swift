import SwiftUI

/// Source pages/merchant/apply 行业类型 (M-16): a required row that opens a multi-select sheet over
/// api/category/list type=MERCHANT, 1–5 choices, first choice primary. Replaces the free-text 经营类目.
struct MerchantOnboardingCategoryRow: View {
    @ObservedObject var model: MerchantOnboardingModel
    @State private var showsSheet = false
    var body: some View {
        Button { showsSheet = true } label: {
            CYListRow("merchant.onboarding.category", trailing: .value(summary))
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy || model.coordinator.submission.isLocked)
        .accessibilityIdentifier("merchant.onboarding.category")
        .sheet(isPresented: $showsSheet) {
            MerchantOnboardingCategorySheet(model: model) { showsSheet = false }
                .presentationDetents([.medium, .large])
        }
    }
    private var summary: String {
        if !model.draft.categoryNames.isEmpty { return model.draft.categoryNames.joined(separator: " · ") }
        if !model.draft.categoryIDs.isEmpty { return model.draft.categoryIDs.map { "#\($0)" }.joined(separator: " · ") }
        return "—"
    }
}

private struct MerchantOnboardingCategorySheet: View {
    @ObservedObject var model: MerchantOnboardingModel
    let close: () -> Void
    private enum Load: Equatable { case loading, failed, loaded([MerchantOnboardingCategory]) }
    @State private var load: Load = .loading
    @State private var selection: [Int] = []
    var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("merchant.onboarding.category.sheetTitle"), isDoneEnabled: !selection.isEmpty,
                          onClose: close, onDone: apply)
            content
        }
        .task { selection = model.draft.categoryIDs; await reload() }
    }
    @ViewBuilder private var content: some View {
        switch load {
        case .loading:
            CYSkeleton().padding(CYSpacing.pageHorizontal)
            Spacer()
        case .failed:
            CYEmptyStateView(systemImage: "exclamationmark.triangle", title: "merchant.onboarding.category.loadFailed",
                             actionTitle: "merchant.onboarding.category.retry") { Task { await reload() } }
        case .loaded(let rows):
            List {
                Section {
                    ForEach(rows) { row in
                        let index = selection.firstIndex(of: row.id)
                        Button { toggle(row.id) } label: {
                            HStack {
                                // Round 2 MP asset (apply/index.wxml:308 cy-tag-sheet): the tag-library icon when the
                                // label maps to one; unmapped labels stay text only, as in the MP.
                                if let icon = MerchantTagIcons.image(for: row.name) {
                                    MerchantMPIcon(image: icon, size: 20).opacity(index == nil ? 0.58 : 1)
                                }
                                Text(verbatim: row.name).cyText(.body).foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                if let index {
                                    Text(verbatim: "\(index + 1)").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                                    MerchantMPIcon(image: MPAsset.FeatureIcon.check, size: 20)
                                } else {
                                    Image(systemName: "circle").foregroundStyle(CYColor.textTertiary)
                                }
                            }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(index == nil && selection.count >= MerchantOnboardingDraft.categoryLimit)
                        .accessibilityAddTraits(index == nil ? [] : .isSelected)
                    }
                } footer: {
                    Text("merchant.onboarding.category.hint \(MerchantOnboardingDraft.categoryLimit)").cyText(.meta)
                }
            }
        }
    }
    private func toggle(_ id: Int) {
        if let index = selection.firstIndex(of: id) { selection.remove(at: index) }
        else if selection.count < MerchantOnboardingDraft.categoryLimit { selection.append(id) }
    }
    private func apply() {
        guard !selection.isEmpty, case .loaded(let rows) = load else { return }
        model.draft.categoryIDs = selection
        model.draft.categoryNames = selection.compactMap { id in rows.first { $0.id == id }?.name }
        if model.errorKey == "merchant.onboarding.required.category" { model.errorKey = nil }
        close()
    }
    private func reload() async {
        load = .loading
        do {
            let rows = try await model.coordinator.categories()
            load = .loaded(rows)
            // Backfill names for a reapplication that restored ids only.
            if model.draft.categoryNames.isEmpty, !model.draft.categoryIDs.isEmpty {
                model.draft.categoryNames = model.draft.categoryIDs.compactMap { id in rows.first { $0.id == id }?.name }
            }
        } catch { load = .failed }
    }
}
