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
    @Environment(\.locale) private var locale
    init(host: ClubBadgeHost) { _model = StateObject(wrappedValue: ClubBadgeHostModel(host: host)) }
    var body: some View {
        let _ = model.revision
        // CLB-r9-native-06: a system inset-grouped List (was a custom ScrollView); failures are ContentUnavailableView.
        List {
            // CLB-badges-01 (parity r2): the page-type title is the inline bar title, not a hero in the content.
            if let flow = model.flow, flow.isCurrent {
                badgeContent(flow)
            } else if model.working {
                ProgressView { Text("loading", tableName: "ClubBadge") }
                    .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView {
                    Label { Text("listError", tableName: "ClubBadge") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button("action.reload") { model.perform { await $0.refresh() } }
                        .buttonStyle(.bordered)
                }
            }
        }
        .disabled(model.working)
        .privacySensitive()
        .navigationTitle(Text("title", tableName: "ClubBadge"))
        .navigationBarTitleDisplayMode(.inline)
        // CLB-badges-06: pull to refresh (MP enablePullDownRefresh) instead of a toolbar 刷新.
        .refreshable { model.perform { await $0.refresh() } }
        .toolbar { createToolbarItem }
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
        .cySheet(isPresented: $creating) { createForm }
        // CLB-badges-04 (fix-r3-club-b): the member picker is the MP 颁给谁？ sheet; the grant confirm is presented from it.
        .cySheet(isPresented: Binding(
            get: { model.flow?.pickerOpen == true },
            set: { open in
                guard !open, let flow = model.flow else { return }
                flow.closePicker(); pendingReview = nil; model.changed()
            }
        )) {
            if let flow = model.flow { memberPickerSheet(flow) }
        }
    }

    /// CLB-r10-nat-badges-03 (MP badges/index.wxml create entry, shown when `canCreate`): toolbar 创建.
    private var createToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if let flow = model.flow, flow.isCurrent, flow.canCreate {
                Button {
                    draft = .init(); creating = true
                } label: {
                    Label { Text("create", tableName: "ClubBadge") } icon: { Image(systemName: "plus") }
                }
                .disabled(model.working)
            }
        }
    }

    @ViewBuilder private func badgeContent(_ flow: ClubBadgeManagementFlow) -> some View {
        Section {
            if model.working || flow.screenState == .loading {
                ProgressView { Text("loading", tableName: "ClubBadge") }
                    .frame(maxWidth: .infinity)
            }
            switch flow.screenState {
            case .notAvailable:
                ContentUnavailableView {
                    Label { Text("notAvailable", tableName: "ClubBadge") } icon: { Image(systemName: "medal") }
                }
            case .error:
                ContentUnavailableView {
                    Label { Text("listError", tableName: "ClubBadge") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button { model.perform { await $0.refresh() } } label: { Text("retry", tableName: "ClubBadge") }
                        .buttonStyle(.bordered)
                }
            case .loading:
                EmptyView()
            case .empty, .ready:
                if flow.error != nil || flow.refreshError != nil || flow.memberError != nil {
                    // CLB-badges-07: MP 列表没刷新成功 for a failed refresh, 勋章列表没加载成功 otherwise.
                    Text(flow.refreshError != nil ? "refreshError" : "listError", tableName: "ClubBadge")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { model.perform { await $0.refresh() } } label: { Text("refresh", tableName: "ClubBadge") }
                }
            }
            resultStatus(flow.resultPresentation, createIsPrimary: flow.canCreate)
            // CLB-r10-nat-badges-03: 创建勋章 (MP badges wxml create button, owner only) is the toolbar primary action.
            if flow.screenState == .empty {
                // Round 4 image parity: MP cy-state-shell kind="empty" → the MP two-layer empty art.
                ClubMPEmptyState(title: Text("empty", tableName: "ClubBadge"))
            }
        } header: {
            // CLB-badges-01 (fix-r3-club-b): MP cy-page-title subtitle = the club name.
            if let clubName = flow.club?.name.trimmingCharacters(in: .whitespacesAndNewlines), !clubName.isEmpty {
                Text(verbatim: clubName)
                    .lineLimit(2)
            }
        } footer: {
            if flow.showsOwnerOnlyNotice {
                Text("ownerOnly", tableName: "ClubBadge")
            }
        }
        if !flow.badges.isEmpty {
            Section {
                ForEach(flow.badges) { badge in badgeRow(badge, flow: flow) }
            } header: {
                // CLB-badges-06: MP 全部勋章 · N 枚 header.
                Text("allBadges \(flow.badges.count)", tableName: "ClubBadge")
                    .monospacedDigit()
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func badgeRow(_ badge: ClubBadgeRecord, flow: ClubBadgeManagementFlow) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            if let url = httpsURL(badge.iconUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Color(uiColor: .tertiarySystemFill) }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            } else {
                // HANDOFF-R1 MC-30: a club badge without uploaded art gets the club crest family art.
                ClubBadgeArt(name: shownName(badge) ?? "", seed: badge.badgeCode, category: .club, size: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                badgeName(badge)
                    .fixedSize(horizontal: false, vertical: true)
                if let desc = shownDescription(badge) {
                    Text(verbatim: desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            if flow.canGrant {
                Button {
                    model.perform { await $0.openGrant(badge) }
                } label: {
                    Label { Text("grant", tableName: "ClubBadge") } icon: { Image(systemName: "person.badge.plus") }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                // CLB-badges-10: MP aria-label 把 X 颁给成员.
                .accessibilityLabel(Text("clubR3b.badges.grantA11y \(shownName(badge) ?? badge.badgeCode)"))
            }
        }
        .accessibilityElement(children: .contain)
        // CLB-r10-nat-badges-03: 颁发 is also the row's swipe action (MP badges wxml per-badge 颁发).
        .swipeActions(edge: .trailing) {
            if flow.canGrant {
                Button {
                    model.perform { await $0.openGrant(badge) }
                } label: {
                    Label { Text("grant", tableName: "ClubBadge") } icon: { Image(systemName: "person.badge.plus") }
                }
                .tint(.accentColor)
            }
        }
    }

    /// CLB-badges-04 (fix-r3-club-b): MP cy-sheet 颁给谁？ with the caption 勋章：X and one avatar row per member.
    private func memberPickerSheet(_ flow: ClubBadgeManagementFlow) -> some View {
        NavigationStack {
            List {
                Section {
                    switch flow.memberPickerState {
                    case .loading:
                        ProgressView { Text("membersLoading", tableName: "ClubBadge") }
                            .frame(maxWidth: .infinity)
                    case .error:
                        Text("membersError", tableName: "ClubBadge")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button { model.perform { await $0.retryMembers() } } label: { Text("retry", tableName: "ClubBadge") }
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
                                        .fixedSize(horizontal: false, vertical: true)
                                    if member.isOwner {
                                        Text("ownerMark", tableName: "ClubBadge")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: CYSpacing.sm)
                                }
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                            }
                            .disabled(flow.busy)
                            // MP aria-label 颁给 {nickname}.
                            .accessibilityLabel(Text("clubR3b.badges.pickA11y \(name)"))
                        }
                    }
                } header: {
                    if let badgeName = flow.selectedBadgeName {
                        Text("clubR3b.badges.pickerCaption \(badgeName)")
                    }
                }
            }
            .navigationTitle(Text("clubR3b.badges.pickerTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { flow.closePicker(); pendingReview = nil; model.changed() } label: {
                        Text("cancel", tableName: "ClubBadge")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(flow.busy)
        // CLB-r10-nat-badges-04 (MP badges/index.js grant confirm, cy-confirm 把「X」颁给 Y？): a system confirmation
        // dialog with the consequences as its message, instead of a custom confirm sheet.
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { pendingReview != nil }, set: { if !$0 { pendingReview = nil } }),
                            titleVisibility: .visible, presenting: pendingReview) { review in
            Button {
                pendingReview = nil
                lastWasCreate = false
                model.perform { await $0.confirmGrant(review) }
            } label: { Text("grant", tableName: "ClubBadge") }
            Button(role: .cancel) {
                pendingReview = nil
                model.flow?.cancelReview()
                model.changed()
            } label: { Text("cancel", tableName: "ClubBadge") }
        } message: { _ in
            confirmMessage
        }
    }

    /// CLB-badges-05: the title names the badge and the person (MP 把「X」颁给 Y？).
    private var confirmTitle: Text {
        guard let review = pendingReview else { return Text("grant", tableName: "ClubBadge") }
        let memberName = review.member.trimmedNickname ?? "—"
        let badgeName = review.badge.badgeName ?? review.badge.badgeCode
        return Text("confirmGrantNamed \(badgeName) \(memberName)", tableName: "ClubBadge")
    }
    private var confirmMessage: Text {
        let lines: [Text] = [
            Text("confirmGrantConsequence1", tableName: "ClubBadge"),
            Text("confirmGrantConsequence2", tableName: "ClubBadge"),
            Text("confirmGrantConsequence3", tableName: "ClubBadge"),
            Text("confirmGrantDetail", tableName: "ClubBadge"),
        ]
        return lines.dropFirst().reduce(lines[0]) { $0 + Text(verbatim: "\n") + $1 }
    }

    @ViewBuilder private func resultStatus(_ result: ClubBadgeResultPresentation, createIsPrimary: Bool) -> some View {
        switch result {
        case .none:
            EmptyView()
        case .storageUnavailable:
            Text("storageUnavailable", tableName: "ClubBadge")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .unknown:
            Text("unknown", tableName: "ClubBadge")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { model.perform { await $0.refresh() } } label: { Text("recover", tableName: "ClubBadge") }
        case .needsReview where lastWasCreate:
            // MP badges js:264,282: 勋章没有创建成功, or the server's own sentence when it gave one.
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                // CLB-r8-badges-02 (MP badges wxml:56): title 勋章没有创建; the line under it is the server's sentence,
                // else 勋章没有创建成功.
                Text("clubR8b.badges.createFailedTitle")
                    .font(.headline)
                if let message = model.flow?.operationMessage, !message.isEmpty {
                    Text(verbatim: message).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("clubR8b.badges.createFailed").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("club.badges.createFailed")
        case .needsReview:
            Text("actionNeedsReview", tableName: "ClubBadge")
                .fixedSize(horizontal: false, vertical: true)
        case .notSent:
            Text("notSent", tableName: "ClubBadge")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .confirmed(let receipt):
            receiptLine(receipt)
        case .historical(let receipt):
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("historicalResult", tableName: "ClubBadge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .foregroundStyle(known ? Color.green : Color.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var createForm: some View {
        NavigationStack {
            Form {
                // CLB-badges-02 (fix-r3-club-b): MP cy-field placeholders, 说明（选填）, inline errors.
                labeledField(
                    label: Text("name", tableName: "ClubBadge"),
                    prompt: Text("clubR3b.badges.namePrompt"), text: $draft.name,
                    error: draft.name.isEmpty ? nil : nameIssue
                )
                labeledField(
                    label: Text("clubR3b.badges.descriptionOptional"),
                    prompt: Text("clubR3b.badges.descriptionPrompt"), text: $draft.description,
                    error: descriptionIssue, axis: .vertical
                )
            }
            .navigationTitle(Text("create", tableName: "ClubBadge"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { creating = false } label: { Text("cancel", tableName: "ClubBadge") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let submitted = draft; creating = false; lastWasCreate = true
                        model.perform { await $0.create(submitted) }
                    } label: { Text("confirmCreate", tableName: "ClubBadge") }
                    .disabled(draft.validation != nil || model.flow?.canCreate != true)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
        label: Text, prompt: Text, text: Binding<String>,
        error: String?, axis: Axis = .horizontal
    ) -> some View {
        Section {
            TextField(text: text, prompt: prompt, axis: axis) { label }
                .lineLimit(axis == .vertical ? 3...6 : 1...1)
        } header: {
            label
        } footer: {
            if let error {
                Text(verbatim: error)
                    .foregroundStyle(.red)
            }
        }
    }
    private func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
