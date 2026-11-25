import SwiftUI

@MainActor struct ClubBadgeManagementView: View {
    @StateObject private var model: ClubBadgeHostModel
    @State private var visible = false
    @State private var creating = false
    /// CLB-r8-badges-02 (fix-r8-club): the last mutation was 创建勋章, so a failed outcome reads 勋章没有创建成功.
    @State private var lastWasCreate = false
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
                // CLB-badges-01 (parity r2): the page-type title is the inline bar title, not a hero in the content.
                if let flow = model.flow, flow.isCurrent {
                    // CLB-badges-01 (fix-r3-club-b): MP cy-page-title subtitle = the club name.
                    if let clubName = flow.club?.name.trimmingCharacters(in: .whitespacesAndNewlines), !clubName.isEmpty {
                        Text(verbatim: clubName)
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                    }
                    badgeContent(flow)
                } else if model.working {
                    CYSkeleton().accessibilityLabel(Text("loading", tableName: "ClubBadge"))
                } else {
                    Text("listError", tableName: "ClubBadge")
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .disabled(model.working)
        }
        .cyDomainScreen(.player)
        .privacySensitive()
        .navigationTitle(Text("title", tableName: "ClubBadge"))
        .navigationBarTitleDisplayMode(.inline)
        // CLB-badges-06: pull to refresh (MP enablePullDownRefresh) instead of a toolbar 刷新.
        .refreshable { model.perform { await $0.refresh() } }
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
        // CLB-badges-04 (fix-r3-club-b): the member picker is the MP 颁给谁？ sheet; the grant confirm is presented from it.
        .sheet(isPresented: Binding(
            get: { model.flow?.pickerOpen == true },
            set: { open in
                guard !open, let flow = model.flow else { return }
                flow.closePicker(); pendingReview = nil; model.changed()
            }
        )) {
            if let flow = model.flow { memberPickerSheet(flow) }
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
                "listError",
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
                    // CLB-badges-07: MP 列表没刷新成功 for a failed refresh, 勋章列表没加载成功 otherwise.
                    Text(flow.refreshError != nil ? "refreshError" : "listError", tableName: "ClubBadge")
                        .cyText(.body)
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
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if flow.canCreate {
            CYPillButton("create", style: .primary, systemImage: "plus", tableName: "ClubBadge") {
                draft = .init(); creating = true
            }
        }
        if flow.screenState == .empty {
            // Round 4 image parity: MP cy-state-shell kind="empty" → the MP two-layer empty art.
            ClubMPEmptyState(title: Text("empty", tableName: "ClubBadge"))
        }
        if !flow.badges.isEmpty {
            // CLB-badges-06: MP 全部勋章 · N 枚 header.
            Text("allBadges \(flow.badges.count)", tableName: "ClubBadge")
                .cyText(.sectionTitle)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        ForEach(flow.badges) { badge in badgeCard(badge, flow: flow) }
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
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                        .accessibilityHidden(true)
                    } else {
                        // HANDOFF-R1 MC-30: a club badge without uploaded art gets the club crest family art.
                        ClubBadgeArt(name: shownName(badge) ?? "", seed: badge.badgeCode, category: .club, size: 44)
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        // CLB-badges-09: MP .badge-name body 14, .badge-desc caption 11 clamped to two lines.
                        badgeName(badge)
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let desc = shownDescription(badge) {
                            Text(verbatim: desc)
                                .cyText(.caption)
                                .foregroundStyle(palette.textTertiary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: CYSpacing.sm)
                }
            }
            if flow.canGrant {
                CYPillButton("grant", style: .secondary, systemImage: "person.badge.plus", tableName: "ClubBadge") {
                    model.perform { await $0.openGrant(badge) }
                }
                // CLB-badges-10: MP aria-label 把 X 颁给成员.
                .accessibilityLabel(Text("clubR3b.badges.grantA11y \(shownName(badge) ?? badge.badgeCode)"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    /// CLB-badges-04 (fix-r3-club-b): MP cy-sheet 颁给谁？ with the caption 勋章：X and one avatar row per member.
    private func memberPickerSheet(_ flow: ClubBadgeManagementFlow) -> some View {
        CYSheetContainer(
            title: String(localized: LocalizedStringResource("clubR3b.badges.pickerTitle", locale: locale)),
            onClose: { flow.closePicker(); pendingReview = nil; model.changed() }
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if let badgeName = flow.selectedBadgeName {
                    Text("clubR3b.badges.pickerCaption \(badgeName)")
                        .cyText(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                switch flow.memberPickerState {
                case .loading:
                    CYSkeleton().accessibilityLabel(Text("membersLoading", tableName: "ClubBadge"))
                case .error:
                    Text("membersError", tableName: "ClubBadge")
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CYPillButton("retry", style: .secondary, tableName: "ClubBadge") {
                        model.perform { await $0.retryMembers() }
                    }
                case .empty:
                    // Round 4 image parity: MP 暂无成员 is cy-state-shell kind="empty" (two-layer art).
                    ClubMPEmptyState(title: Text("membersEmpty", tableName: "ClubBadge"))
                case .ready, .closed:
                    ForEach(flow.members) { member in
                        let name = member.trimmedNickname ?? "—"
                        Button {
                            flow.selectMember(member); pendingReview = flow.review; model.changed()
                        } label: {
                            HStack(spacing: CYSpacing.md) {
                                // MP badges `item.avatar || '/images/d_profile.png'` (round 2 MP asset).
                                ClubMPAvatar(url: member.avatar.flatMap(URL.init(string:)), name: name, size: .md)
                                    .accessibilityHidden(true)
                                Text(verbatim: name)
                                    .cyText(.body)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if member.isOwner {
                                    Text("ownerMark", tableName: "ClubBadge")
                                        .cyText(.caption)
                                        .foregroundStyle(palette.textTertiary)
                                }
                                Spacer(minLength: CYSpacing.sm)
                            }
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.cyPressable)
                        .disabled(flow.busy)
                        // MP aria-label 颁给 {nickname}.
                        .accessibilityLabel(Text("clubR3b.badges.pickA11y \(name)"))
                    }
                }
            }
        }
        .cyDomainSheet(detents: [.half, .full])
        .interactiveDismissDisabled(flow.busy)
        .sheet(isPresented: Binding(get: { pendingReview != nil }, set: { if !$0 { pendingReview = nil } })) {
            if let review = pendingReview {
                // CLB-badges-05: the title names the badge and the person (MP 把「X」颁给 Y？).
                let memberName = review.member.trimmedNickname ?? "—"
                let badgeName = review.badge.badgeName ?? review.badge.badgeCode
                let detail = String(localized: LocalizedStringResource("confirmGrantDetail", table: "ClubBadge", locale: locale))
                CYConfirmSheet(
                    title: String(localized: LocalizedStringResource("confirmGrantNamed \(badgeName) \(memberName)", table: "ClubBadge", locale: locale)),
                    message: detail,
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
                        lastWasCreate = false
                        model.perform { await $0.confirmGrant(review) }
                    }
                )
                .cyDomainSheet(detents: [.half, .full])
            }
        }
    }

    @ViewBuilder private func resultStatus(_ result: ClubBadgeResultPresentation, createIsPrimary: Bool) -> some View {
        switch result {
        case .none:
            EmptyView()
        case .storageUnavailable:
            Text("storageUnavailable", tableName: "ClubBadge")
                .cyText(.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .unknown:
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("unknown", tableName: "ClubBadge")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("recover", style: createIsPrimary ? .secondary : .primary, tableName: "ClubBadge") {
                    model.perform { await $0.refresh() }
                }
            }
        case .needsReview where lastWasCreate:
            // MP badges js:264,282: 勋章没有创建成功, or the server's own sentence when it gave one.
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("clubR8b.badges.createFailed")
                    .cyText(.body, weight: .semibold)
                    .foregroundStyle(palette.textPrimary)
                if let message = model.flow?.operationMessage, !message.isEmpty {
                    Text(verbatim: message).cyText(.meta).foregroundStyle(palette.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("club.badges.createFailed")
        case .needsReview:
            Text("actionNeedsReview", tableName: "ClubBadge")
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .notSent:
            Text("notSent", tableName: "ClubBadge")
                .cyText(.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .confirmed(let receipt):
            receiptLine(receipt)
        case .historical(let receipt):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("historicalResult", tableName: "ClubBadge")
                    .cyText(.meta)
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
        .cyText(.label)
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
                // CLB-badges-02 (fix-r3-club-b): MP cy-field placeholders, n/max counters, 说明（选填）, inline errors.
                labeledField(
                    "name", label: Text("name", tableName: "ClubBadge"),
                    prompt: Text("clubR3b.badges.namePrompt"), text: $draft.name, limit: 120,
                    error: draft.name.isEmpty ? nil : nameIssue
                )
                labeledField(
                    "description", label: Text("clubR3b.badges.descriptionOptional"),
                    prompt: Text("clubR3b.badges.descriptionPrompt"), text: $draft.description, limit: 255,
                    error: descriptionIssue, axis: .vertical
                )
                VStack(spacing: CYSpacing.sm) {
                    CYPillButton("confirmCreate", tableName: "ClubBadge") {
                        let submitted = draft; creating = false; lastWasCreate = true
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
    /// The Core draft returns one sentence; it belongs to the field it describes.
    private var nameIssue: String? {
        let name = draft.normalizedName
        return name.isEmpty || name.utf16.count > 120 ? draft.validation : nil
    }
    private var descriptionIssue: String? {
        nameIssue == nil ? draft.validation : nil
    }
    private func labeledField(
        _ key: String, label: Text, prompt: Text, text: Binding<String>, limit: Int,
        error: String?, axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                label
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: CYSpacing.sm)
                Text(verbatim: "\(text.wrappedValue.utf16.count)/\(limit)")
                    .cyText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(text.wrappedValue.utf16.count > limit ? CYColor.dangerText : palette.textTertiary)
                    .accessibilityHidden(true)
            }
            TextField(text: text, prompt: prompt, axis: axis) { label }
                .lineLimit(axis == .vertical ? 3...6 : 1...1)
                .cyText(.body)
                .padding(CYSpacing.md)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                .accessibilityLabel(label)
                .accessibilityValue(Text(verbatim: "\(text.wrappedValue.utf16.count)/\(limit)"))
            if let error {
                Text(verbatim: error)
                    .cyText(.caption)
                    .foregroundStyle(CYColor.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
