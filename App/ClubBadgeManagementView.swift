import SwiftUI

@MainActor struct ClubBadgeManagementView: View {
    @StateObject private var model: ClubBadgeHostModel
    @State private var visible = false
    @State private var creating = false
    @State private var pendingReview: ClubBadgeGrantReview?
    @State private var draft = ClubBadgeCreateDraft()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    init(host: ClubBadgeHost) { _model = StateObject(wrappedValue: ClubBadgeHostModel(host: host)) }
    var body: some View {
        let _ = model.revision
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("title", tableName: "ClubBadge")
                if let flow = model.flow, flow.isCurrent {
                    badgeContent(flow)
                } else if model.working {
                    CYSkeleton().accessibilityLabel(Text("loading", tableName: "ClubBadge"))
                } else {
                    Text("readError", tableName: "ClubBadge")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .disabled(model.working)
        }
        .cyDomainPageBackground()
        .privacySensitive()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.perform { await $0.refresh() } } label: { Text("refresh", tableName: "ClubBadge") }
            }
        }
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
        .sheet(isPresented: Binding(get: { pendingReview != nil }, set: { if !$0 { pendingReview = nil } })) {
            if let review = pendingReview {
                let targetName = (review.member.trimmedNickname ?? String(review.member.memberId)) + " · " + (review.badge.badgeName ?? review.badge.badgeCode)
                let detail = String(localized: LocalizedStringResource("confirmGrantDetail", table: "ClubBadge", locale: locale))
                CYConfirmSheet(
                    title: String(localized: LocalizedStringResource("confirmGrant", table: "ClubBadge", locale: locale)),
                    message: "\(targetName)\n\(detail)",
                    confirmTitle: String(localized: LocalizedStringResource("grant", table: "ClubBadge", locale: locale)),
                    cancelTitle: String(localized: LocalizedStringResource("cancel", table: "ClubBadge", locale: locale)),
                    isDestructive: false,
                    consequences: [
                        CYConfirmConsequence(systemImage: "person.badge.plus", text: String(localized: LocalizedStringResource("confirmGrantConsequence1", table: "ClubBadge", locale: locale))),
                        CYConfirmConsequence(systemImage: "medal", text: String(localized: LocalizedStringResource("confirmGrantConsequence2", table: "ClubBadge", locale: locale))),
                        CYConfirmConsequence(systemImage: "exclamationmark.circle", text: String(localized: LocalizedStringResource("confirmGrantConsequence3", table: "ClubBadge", locale: locale)))
                    ],
                    onCancel: {
                        pendingReview = nil
                        model.flow?.cancelReview()
                        model.changed()
                    },
                    onConfirm: {
                        pendingReview = nil
                        model.perform { await $0.confirmGrant(review) }
                    }
                )
                .cyDomainSheet(detents: [.half, .full])
            }
        }
    }

    @ViewBuilder private func badgeContent(_ flow: ClubBadgeManagementFlow) -> some View {
        if model.working || flow.screenState == .loading {
            CYSkeleton().accessibilityLabel(Text("loading", tableName: "ClubBadge"))
        }
        switch flow.screenState {
        case .notAvailable:
            CYEmptyState(systemImage: "medal", "notAvailable", tableName: "ClubBadge")
        case .error:
            CYEmptyState(
                systemImage: "exclamationmark.triangle",
                "readError",
                tableName: "ClubBadge",
                actionTitle: "retry",
                actionStyle: flow.canCreate ? .secondary : .primary,
                kind: .failure
            ) { model.perform { await $0.refresh() } }
        case .loading:
            EmptyView()
        case .empty, .ready:
            if flow.error != nil || flow.refreshError != nil || flow.memberError != nil {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("readError", tableName: "ClubBadge")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CYPillButton("refresh", style: flow.canCreate ? .secondary : .primary, tableName: "ClubBadge") {
                        model.perform { await $0.refresh() }
                    }
                }
            }
        }
        resultStatus(flow.resultPresentation, createIsPrimary: flow.canCreate)
        if flow.showsOwnerOnlyNotice {
            Text("ownerOnly", tableName: "ClubBadge")
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if flow.canCreate {
            CYPillButton("create", style: .primary, systemImage: "plus", tableName: "ClubBadge") {
                draft = .init(); creating = true
            }
        }
        if flow.screenState == .empty {
            CYEmptyState(systemImage: "medal", "empty", tableName: "ClubBadge")
        }
        ForEach(flow.badges) { badge in badgeCard(badge, flow: flow) }
        if flow.pickerOpen { memberPicker(flow) }
    }

    private func badgeCard(_ badge: ClubBadgeRecord, flow: ClubBadgeManagementFlow) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let url = httpsURL(badge.iconUrl), let name = shownName(badge) {
                CYImageCard(verbatim: name, fallback: "unnamed", meta: shownDescription(badge), imageURL: url)
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    if let url = httpsURL(badge.iconUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { CYCoverArt(seed: badge.badgeCode, showsDebugLabel: false) }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    } else {
                        CYRowIcon(systemImage: "medal")
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        badgeName(badge)
                            .font(CYTypography.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let desc = shownDescription(badge) {
                            Text(verbatim: desc)
                                .font(CYTypography.meta)
                                .foregroundStyle(palette.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: CYSpacing.sm)
                }
            }
            if flow.canGrant {
                CYPillButton("grant", style: .secondary, systemImage: "person.badge.plus", tableName: "ClubBadge") {
                    model.perform { await $0.openGrant(badge) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func memberPicker(_ flow: ClubBadgeManagementFlow) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("recipient", tableName: "ClubBadge")
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            switch flow.memberPickerState {
            case .loading:
                CYSkeleton().accessibilityLabel(Text("membersLoading", tableName: "ClubBadge"))
            case .error:
                Text("membersError", tableName: "ClubBadge")
                    .font(CYTypography.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("retry", style: .secondary, tableName: "ClubBadge") {
                    model.perform { await $0.retryMembers() }
                }
            case .empty:
                CYEmptyState(systemImage: "person.2", "membersEmpty", tableName: "ClubBadge")
            case .ready, .closed:
                ForEach(flow.members) { member in
                    Button {
                        flow.selectMember(member); pendingReview = flow.review; model.changed()
                    } label: {
                        HStack(spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: member.isOwner ? "crown" : "person")
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text(verbatim: member.trimmedNickname ?? String(member.memberId))
                                    .font(CYTypography.cardTitle)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if member.isOwner {
                                    Text("ownerMark", tableName: "ClubBadge")
                                        .font(CYTypography.meta)
                                        .foregroundStyle(palette.textTertiary)
                                }
                            }
                            Spacer(minLength: CYSpacing.sm)
                        }
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                    }
                    .buttonStyle(.cyPressable)
                }
            }
            CYPillButton("cancel", style: .tertiary, tableName: "ClubBadge") {
                flow.closePicker(); pendingReview = nil; model.changed()
            }
        }
    }

    @ViewBuilder private func resultStatus(_ result: ClubBadgeResultPresentation, createIsPrimary: Bool) -> some View {
        switch result {
        case .none:
            EmptyView()
        case .storageUnavailable:
            Text("storageUnavailable", tableName: "ClubBadge")
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .unknown:
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("unknown", tableName: "ClubBadge")
                    .font(CYTypography.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("recover", style: createIsPrimary ? .secondary : .primary, tableName: "ClubBadge") {
                    model.perform { await $0.refresh() }
                }
            }
        case .needsReview:
            Text("actionNeedsReview", tableName: "ClubBadge")
                .font(CYTypography.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .notSent:
            Text("notSent", tableName: "ClubBadge")
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .confirmed(let receipt):
            receiptLine(receipt)
        case .historical(let receipt):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("historicalResult", tableName: "ClubBadge")
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                receiptLine(receipt)
            }
        }
    }

    /// Known receipt states stay on the ClubBadge table. Anything else uses the existing unknown sentence, never a raw key.
    private func receiptLine(_ receipt: ClubBadgeOriginalReceipt) -> some View {
        let known = ["CREATED", "GRANTED", "ALREADY_GRANTED"].contains(receipt.state)
        return Label {
            if known {
                Text(LocalizedStringKey("receipt." + receipt.state), tableName: "ClubBadge")
            } else {
                Text("unknown", tableName: "ClubBadge")
            }
        } icon: {
            Image(systemName: known ? "checkmark.seal" : "questionmark.circle")
                .accessibilityHidden(true)
        }
        .font(CYTypography.label)
        .foregroundStyle(known ? palette.success : palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var createForm: some View {
        CYSheetContainer(
            title: String(localized: LocalizedStringResource("create", table: "ClubBadge", locale: locale)),
            onClose: { creating = false }
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                labeledField("name", text: $draft.name)
                labeledField("description", text: $draft.description, axis: .vertical)
                Text("limits", tableName: "ClubBadge")
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: CYSpacing.sm) {
                    CYPillButton("confirmCreate", tableName: "ClubBadge") {
                        let submitted = draft; creating = false
                        model.perform { await $0.create(submitted) }
                    }
                    .disabled(draft.validation != nil || model.flow?.canCreate != true)
                    CYPillButton("cancel", style: .tertiary, tableName: "ClubBadge") { creating = false }
                }
            }
        }
        .cyDomainSheet(detents: [.half, .full])
    }

    @ViewBuilder private func badgeName(_ badge: ClubBadgeRecord) -> some View {
        if let name = shownName(badge) { Text(verbatim: name) }
        else { Text("unnamed", tableName: "ClubBadge") }
    }
    private func shownName(_ badge: ClubBadgeRecord) -> String? {
        let name = badge.badgeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
    private func shownDescription(_ badge: ClubBadgeRecord) -> String? {
        let desc = badge.badgeDesc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return desc.isEmpty ? nil : desc
    }
    private func labeledField(_ key: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(LocalizedStringKey(key), tableName: "ClubBadge")
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: text, axis: axis)
                .font(CYTypography.body)
                .padding(CYSpacing.md)
                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityLabel(Text(LocalizedStringKey(key), tableName: "ClubBadge"))
        }
    }
    private func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
