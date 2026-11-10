import SwiftUI

@MainActor struct ClubBadgeManagementView: View {
    @StateObject private var model: ClubBadgeHostModel
    @State private var visible = false
    @State private var creating = false
    @State private var pendingReview: ClubBadgeGrantReview?
    @State private var draft = ClubBadgeCreateDraft()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    init(host: ClubBadgeHost) { _model = StateObject(wrappedValue: ClubBadgeHostModel(host: host)) }
    var body: some View {
        let _ = model.revision
        List {
            CYHeroHeader("title", tableName: "ClubBadge")
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            if model.working { ProgressView { Text("loading", tableName: "ClubBadge") } }
            if let flow = model.flow, flow.isCurrent {
                switch flow.screenState {
                case .notAvailable:
                    CYEmptyState(systemImage: "rosette", "notAvailable", tableName: "ClubBadge")
                case .error:
                    CYStatusChip(verbatim: String(localized: LocalizedStringResource("readError", table: "ClubBadge", locale: locale)), tone: .danger, systemImage: "exclamationmark.triangle")
                    CYPillButton("retry", style: .secondary, tableName: "ClubBadge") { model.perform { await $0.refresh() } }
                case .loading:
                    ProgressView { Text("loading", tableName: "ClubBadge") }
                case .empty, .ready:
                    if flow.error != nil || flow.refreshError != nil || flow.memberError != nil {
                        CYStatusChip(verbatim: String(localized: LocalizedStringResource("readError", table: "ClubBadge", locale: locale)), tone: .danger, systemImage: "exclamationmark.triangle")
                        CYPillButton("refresh", style: .secondary, tableName: "ClubBadge") { model.perform { await $0.refresh() } }
                    }
                }
                resultStatus(flow.resultPresentation)
                if flow.showsOwnerOnlyNotice {
                    Text("ownerOnly", tableName: "ClubBadge").font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                }
                if flow.canCreate {
                    CYPillButton("create", systemImage: "plus", tableName: "ClubBadge") { draft = .init(); creating = true }
                }
                if flow.screenState == .empty {
                    CYEmptyState(systemImage: "rosette", "empty", tableName: "ClubBadge")
                }
                ForEach(flow.badges) { badge in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYListRow(
                            verbatim: (badge.badgeName?.isEmpty == false ? badge.badgeName : nil) ?? String(localized: LocalizedStringResource("unnamed", table: "ClubBadge", locale: locale)),
                            meta: badge.badgeDesc?.isEmpty == false ? badge.badgeDesc : nil,
                            trailing: .none
                        ) { CYRowIcon(systemImage: "rosette") }
                        if flow.canGrant {
                            CYPillButton("grant", style: .secondary, fullWidth: false, tableName: "ClubBadge") { model.perform { await $0.openGrant(badge) } }
                        }
                    }
                }
                if flow.pickerOpen {
                    Section {
                        switch flow.memberPickerState {
                        case .loading:
                            ProgressView { Text("membersLoading", tableName: "ClubBadge") }
                        case .error:
                            CYStatusChip(verbatim: String(localized: LocalizedStringResource("membersError", table: "ClubBadge", locale: locale)), tone: .danger, systemImage: "exclamationmark.triangle")
                            CYPillButton("retry", style: .secondary, tableName: "ClubBadge") { model.perform { await $0.retryMembers() } }
                        case .empty:
                            CYEmptyState(systemImage: "person.2", "membersEmpty", tableName: "ClubBadge")
                        case .ready, .closed:
                            ForEach(flow.members) { member in
                                Button {
                                    flow.selectMember(member); pendingReview = flow.review; model.changed()
                                } label: {
                                    HStack {
                                        Text(verbatim: member.trimmedNickname ?? String(member.memberId))
                                            .font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                                        if member.isOwner { Text("ownerMark", tableName: "ClubBadge").font(CYTypography.caption).foregroundStyle(palette.textTertiary) }
                                    }
                                }
                                .frame(minHeight: CYSpacing.minTouchTarget)
                            }
                        }
                        CYPillButton("cancel", style: .tertiary, tableName: "ClubBadge") { flow.closePicker(); pendingReview = nil; model.changed() }
                    } header: { Text("recipient", tableName: "ClubBadge") }
                }
            } else { CYStatusChip(verbatim: String(localized: LocalizedStringResource("readError", table: "ClubBadge", locale: locale)), tone: .danger, systemImage: "exclamationmark.triangle") }
        }
        .disabled(model.working)
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .toolbar { Button { model.perform { await $0.refresh() } } label: { Text("refresh", tableName: "ClubBadge") } }
        .onAppear { visible = true; if scenePhase == .active { model.start() } }
        .onDisappear { visible = false; creating = false; pendingReview = nil; draft = .init(); model.retire() }
        .onChange(of: scenePhase) { _, phase in
            guard visible else { return }
            creating = false; pendingReview = nil; draft = .init()
            if phase == .active { model.start() } else { model.retire() }
        }
        .onChange(of: model.flow?.isCurrent) { _, current in
            if current == false { creating = false; pendingReview = nil; draft = .init(); model.retire() }
        }
        .sheet(isPresented: $creating) { createForm }
        .confirmationDialog(Text("confirmGrant", tableName: "ClubBadge"), isPresented: Binding(
            get: { pendingReview != nil }, set: { if !$0 { pendingReview = nil } })) {
                if let review = pendingReview {
                    Button { pendingReview = nil; model.perform { await $0.confirmGrant(review) } } label: { Text("grant", tableName: "ClubBadge") }
                }
                Button(role: .cancel) { pendingReview = nil; model.flow?.cancelReview(); model.changed() } label: { Text("cancel", tableName: "ClubBadge") }
            } message: {
                if let review = pendingReview {
                    Text(verbatim: (review.member.trimmedNickname ?? String(review.member.memberId)) + " · " + (review.badge.badgeName ?? review.badge.badgeCode))
                }
            }
    }
    @ViewBuilder private func resultStatus(_ result: ClubBadgeResultPresentation) -> some View {
        switch result {
        case .none: EmptyView()
        case .storageUnavailable:
            CYStatusChip(verbatim: String(localized: LocalizedStringResource("storageUnavailable", table: "ClubBadge", locale: locale)), tone: .warning, systemImage: "externaldrive.badge.exclamationmark")
        case .unknown:
            Section {
                CYStatusChip(verbatim: String(localized: LocalizedStringResource("unknown", table: "ClubBadge", locale: locale)), tone: .warning, systemImage: "questionmark.circle")
                CYPillButton("recover", style: .secondary, tableName: "ClubBadge") { model.perform { await $0.refresh() } }
            }
        case .needsReview: CYStatusChip(verbatim: String(localized: LocalizedStringResource("actionNeedsReview", table: "ClubBadge", locale: locale)), tone: .warning, systemImage: "exclamationmark.circle")
        case .notSent: CYStatusChip(verbatim: String(localized: LocalizedStringResource("notSent", table: "ClubBadge", locale: locale)), tone: .neutral, systemImage: "paperplane")
        case .confirmed(let receipt):
            Text(LocalizedStringKey("receipt." + receipt.state), tableName: "ClubBadge").font(CYTypography.bodyCompact).foregroundStyle(palette.success)
        case .historical(let receipt):
            Section {
                Text(LocalizedStringKey("receipt." + receipt.state), tableName: "ClubBadge")
            } header: { Text("historicalResult", tableName: "ClubBadge") }
        }
    }
    private var createForm: some View {
        NavigationStack {
            Form {
                TextField(text: $draft.name) { Text("name", tableName: "ClubBadge") }
                TextField(text: $draft.description, axis: .vertical) { Text("description", tableName: "ClubBadge") }
                Text("limits", tableName: "ClubBadge")
                Button {
                    let submitted = draft; creating = false
                    model.perform { await $0.create(submitted) }
                } label: { Text("confirmCreate", tableName: "ClubBadge") }
                .disabled(draft.validation != nil || model.flow?.canCreate != true)
                Button { creating = false } label: { Text("cancel", tableName: "ClubBadge") }
            }.navigationTitle(Text("create", tableName: "ClubBadge"))
        }
    }
}
