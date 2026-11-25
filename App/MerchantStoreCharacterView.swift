import AVFoundation
import SwiftUI

@MainActor final class StoreCharacterModel: ObservableObject {
    let coordinator: StoreCharacterCoordinator
    let reform: StoreCharacterReformContext?
    /// Knowledge review for this merchant. Publish stays on the waiting-source capability.
    let authorFlow: MerchantNPCKnowledgeAuthorFlow?
    @Published private(set) var revision = 0
    init(_ coordinator: StoreCharacterCoordinator, reform: StoreCharacterReformContext?, authorFlow: MerchantNPCKnowledgeAuthorFlow? = nil) {
        self.coordinator = coordinator; self.reform = reform; self.authorFlow = authorFlow
        coordinator.onChange = { [weak self] in self?.revision += 1 }
    }
}

/// W04/W05 inputs for the dormant scope section. Supplied only by the offline fixture.
struct StoreCharacterReformContext {
    let projection: StoreCharacterSceneProjection
    let draft: StoreCharacterAIDraftStatus
}

private func t(_ key: LocalizedStringKey) -> Text { Text(key, tableName: "StoreCharacter") }

/// Native `pages/merchant/decor/ai-npc` (AI 店铺角色): home view, avatar view and their sheets.
@MainActor struct MerchantStoreCharacterView: View {
    @StateObject private var model: StoreCharacterModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var toastMessage: String?
    /// MP `cy_ai_npc_intro_seen`: the four-step intro shows once; ✕ / 跳过 / 知道了 all count as seen.
    @AppStorage(StoreCharacterIntroSheet.seenKey) private var introSeen = false
    @State private var introPresented = false
    init(coordinator: StoreCharacterCoordinator, reform: StoreCharacterReformContext? = nil, authorFlow: MerchantNPCKnowledgeAuthorFlow? = nil) {
        _model = StateObject(wrappedValue: .init(coordinator, reform: reform, authorFlow: authorFlow))
    }
    private var c: StoreCharacterCoordinator { model.coordinator }

    var body: some View {
        content
            .navigationTitle(c.screen == .home ? t("storeCharacter.title.home") : t("storeCharacter.title.avatar")).navigationBarTitleDisplayMode(.inline)
            // type-and-chrome §3: the coordinator decides (avatar sub-screen, unsaved text, saving); the system back
            // and swipe return as soon as nothing needs guarding.
            .cyGuardedBack(when: c.screen != .home || c.saving || !c.home.sameText(c.saved)) {
                if c.back() == .leave { dismiss() }
            }
            .task { await c.load() }
            .task(id: c.shouldPoll) { await poll() }
            .task(id: deniedKey) { await autoExit() }
            .onAppear { c.setPageVisible(scenePhase == .active) }
            .onDisappear { c.setPageVisible(false) }
            .onChange(of: scenePhase) { _, phase in
                c.setPageVisible(phase == .active)
                if phase == .active, c.homeVoiceStatus == .pending { Task { await c.refreshVoice() } }
            }
            .sheet(isPresented: fieldPresented) {
                StoreCharacterFieldSheet(model: model)
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.merchant)
            }
            .sheet(isPresented: presetsPresented) {
                StoreCharacterPresetSheet(model: model)
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.merchant)
            }
            .onChange(of: isReady, initial: true) { _, ready in
                if ready, !introSeen { introPresented = true }
            }
            .sheet(isPresented: $introPresented, onDismiss: { introSeen = true }) {
                StoreCharacterIntroSheet { introSeen = true; introPresented = false }
                    .cyDomainSheet(detents: [.full])
                    .themeDomain(.merchant)
            }
            .sheet(isPresented: voicePresented) {
                StoreCharacterVoiceSheet(model: model)
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.merchant)
            }
            .onChange(of: c.notice) { _, notice in
                guard let notice else { return }
                toastMessage = storeCharacterNoticeText(notice, locale: locale)
            }
            .cyToast(verbatimMessage: $toastMessage)
            .cyModalConfirm(
                isPresented: discardPresented.wrappedValue,
                title: String(localized: LocalizedStringResource("storeCharacter.discard.title", table: "StoreCharacter", locale: locale)),
                message: String(localized: LocalizedStringResource("storeCharacter.discard.body", table: "StoreCharacter", locale: locale)),
                cancelTitle: String(localized: LocalizedStringResource("storeCharacter.discard.keep", table: "StoreCharacter", locale: locale)),
                confirmTitle: String(localized: LocalizedStringResource("storeCharacter.discard.discard", table: "StoreCharacter", locale: locale)),
                isDestructive: true,
                onCancel: { c.keepEditing() },
                onConfirm: { if c.discardChanges() == .leave { dismiss() } }
            )
            .cyModalConfirm(
                isPresented: mapPointPresented.wrappedValue,
                title: String(localized: LocalizedStringResource("storeCharacter.mapPoint.confirmTitle", table: "StoreCharacter", locale: locale)),
                message: String(localized: LocalizedStringResource("storeCharacter.mapPoint.confirmBody", table: "StoreCharacter", locale: locale)),
                cancelTitle: String(localized: LocalizedStringResource("storeCharacter.action.cancel", table: "StoreCharacter", locale: locale)),
                confirmTitle: String(localized: LocalizedStringResource("storeCharacter.action.confirmSave", table: "StoreCharacter", locale: locale)),
                onCancel: { c.cancelMapPoint() },
                onConfirm: {
                    if let value = c.mapPointConfirmation {
                        Task { await c.confirmMapPoint(value.id) }
                    }
                }
            )
            .cyDomainScreen(.merchant)
    }

    private var isReady: Bool { if case .ready = c.phase { return true }; return false }
    private var deniedKey: Bool { if case .denied = c.phase { return true }; return false }
    /// Source gate: a zero-button fail sheet that leaves after two seconds.
    private func autoExit() async {
        guard deniedKey else { return }
        try? await Task.sleep(for: .seconds(2))
        if !Task.isCancelled, deniedKey { dismiss() }
    }
    private func poll() async {
        while c.shouldPoll {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, c.shouldPoll else { return }
            await c.refreshVoice()
        }
    }
    private var fieldPresented: Binding<Bool> {
        Binding(get: { c.field != nil && c.discard == nil }, set: { if !$0 { c.closeField() } })
    }
    private var presetsPresented: Binding<Bool> {
        Binding(get: { c.presetPick != nil }, set: { if !$0 { c.closePresets() } })
    }
    private var voicePresented: Binding<Bool> {
        Binding(get: { c.voiceVisible }, set: { if !$0 { c.closeVoice() } })
    }
    private var discardPresented: Binding<Bool> {
        Binding(get: { c.discard != nil }, set: { if !$0, c.discard != nil { c.keepEditing() } })
    }
    private var mapPointPresented: Binding<Bool> {
        // Dismissal goes through the dialog's own buttons; confirm must still find its prepared value.
        Binding(get: { c.mapPointConfirmation != nil }, set: { _ in })
    }

    @ViewBuilder private var content: some View {
        switch c.phase {
        case .checking, .loading:
            CYSkeleton(variant: .detail)
                .padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityIdentifier("aiNPC.loading")
        case .login:
            CYEmptyState(
                systemImage: "person.crop.circle.badge.exclamationmark",
                "storeCharacter.gate.loginTitle",
                tableName: "StoreCharacter",
                detail: "storeCharacter.gate.loginReason"
            )
            .accessibilityIdentifier("aiNPC.gate.login")
        case .denied(let reason):
            VStack(spacing: CYSpacing.sm) {
                Image(systemName: "lock")
                    .cyText(.display)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityHidden(true)
                t("storeCharacter.gate.deniedTitle")
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                denyText(reason)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("aiNPC.gate.denied")
        case .currentReadDenied(let reason):
            // A current read refusal is not a network failure or a new initial-admission exit.
            VStack(spacing: CYSpacing.md) {
                Image(systemName: "lock")
                    .cyText(.display)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityHidden(true)
                t("storeCharacter.gate.deniedTitle")
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                denyText(reason)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center)
                CYPillButton("storeCharacter.action.retry", style: .primary, tableName: "StoreCharacter") {
                    Task { await c.load() }
                }
                .accessibilityIdentifier("aiNPC.currentReadDenied.retry")
            }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("aiNPC.currentReadDenied")
        case .failed(let message):
            VStack(spacing: CYSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .cyText(.display)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityHidden(true)
                t("storeCharacter.load.failedTitle")
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                Group {
                    if let message { Text(verbatim: message) } else { t("storeCharacter.error.network") }
                }
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center)
                CYPillButton("storeCharacter.action.retry", style: .primary, tableName: "StoreCharacter") {
                    Task { await c.load() }
                }
                .accessibilityIdentifier("aiNPC.retry")
            }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("aiNPC.load.failed")
        case .ready:
            List {
                if let notice = c.notice { Section { StoreCharacterNoticeText(notice: notice) } }
                // MC7-23-1 (until the npc/save review): say up front that saving is closed, instead of only on a tap.
                else if !c.canSave {
                    Section { StoreCharacterNoticeText(notice: .writesDisabled) }.accessibilityIdentifier("aiNPC.writesClosed")
                }
                Section { hero }
                if c.screen == .home { homeRows } else { avatarRows }
                if c.showsReformScopes, let reform = model.reform { StoreCharacterReformSection(context: reform) }
            }
            .scrollContentBackground(.hidden)
            .cyDomainScreen(.merchant)
            .accessibilityIdentifier("aiNPC.list")
        }
    }

    private func denyText(_ reason: StoreCharacterDenyReason) -> Text {
        switch reason {
        case .notMember: return t("storeCharacter.gate.notMember")
        case .missingPermission: return t("storeCharacter.gate.missingPermission")
        case .noViewPermission: return t("storeCharacter.gate.noViewPermission")
        }
    }

    private var hero: some View {
        VStack(spacing: CYSpacing.s2_5) {
            StoreCharacterPreview(avatar: c.selection, side: c.screen == .home ? 128 : 192)
            if c.screen == .home {
                if c.home.name.isEmpty {
                    t("storeCharacter.hero.namePlaceholder")
                        .cyText(.sectionTitle)
                        .foregroundStyle(CYColor.textSecondary)
                } else {
                    Text(verbatim: c.home.name)
                        .cyText(.sectionTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityIdentifier("aiNPC.hero.name")
                }
                if let badge = c.saved.badge {
                    CYStatusChip(LocalizedStringKey(badgeKey(badge)), tone: badgeTone(badge), tableName: "StoreCharacter")
                        .accessibilityIdentifier("aiNPC.hero.badge")
                    if let reason = c.saved.rejectionReason {
                        (t("storeCharacter.hero.rejectReason") + Text(verbatim: reason))
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("aiNPC.hero.rejectReason")
                    }
                }
            } else {
                t("storeCharacter.avatar.previewCaption")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.sm)
    }
    private func badgeKey(_ badge: StoreCharacterBadge) -> String {
        switch badge {
        case .online: return "storeCharacter.badge.online"
        case .rejected: return "storeCharacter.badge.rejected"
        case .reviewing: return "storeCharacter.badge.reviewing"
        }
    }
    private func badgeTone(_ badge: StoreCharacterBadge) -> CYStatusTone {
        switch badge { case .online: return .success; case .rejected: return .warning; case .reviewing: return .neutral }
    }

    @ViewBuilder private var homeRows: some View {
        Section {
            StoreCharacterRow(title: t("storeCharacter.row.avatar"), value: t("storeCharacter.row.avatarValue"), id: "aiNPC.row.avatar") { c.openAvatar() }
            StoreCharacterRow(title: t("storeCharacter.row.voice"), value: voiceValue, id: "aiNPC.row.voice") { Task { await c.openVoice() } }
        }
        Section {
            StoreCharacterRow(title: t("storeCharacter.row.name"), required: true, value: fieldValue(.name), id: "aiNPC.row.name") { c.editField(.name) }
            StoreCharacterRow(title: t("storeCharacter.row.greeting"), value: fieldValue(.greeting), id: "aiNPC.row.greeting") { c.editField(.greeting) }
            StoreCharacterRow(title: t("storeCharacter.row.persona"), value: fieldValue(.persona), id: "aiNPC.row.persona") { c.editField(.persona) }
            StoreCharacterRow(title: t("storeCharacter.row.knowledge"), value: fieldValue(.knowledge), id: "aiNPC.row.knowledge") { c.editField(.knowledge) }
            StoreCharacterRow(title: t("storeCharacter.row.mapPoint"), value: mapPointValue, id: "aiNPC.row.mapPoint") { c.chooseStorePoint() }
        }
    }
    private var voiceValue: Text {
        switch c.homeVoiceStatus {
        case .pending?: return t("storeCharacter.voiceValue.pending")
        case .ready?: return t("storeCharacter.voiceValue.ready")
        case .failed?: return t("storeCharacter.voiceValue.failed")
        case .none?: return t("storeCharacter.voiceValue.none")
        case nil: return t("storeCharacter.voiceValue.unknown")
        }
    }
    private func fieldValue(_ field: StoreCharacterField) -> Text {
        let value = c.home[field]
        if !value.isEmpty { return Text(verbatim: value) }
        switch field {
        case .name: return t("storeCharacter.placeholder.name")
        case .greeting: return t("storeCharacter.placeholder.greeting")
        case .persona: return t("storeCharacter.placeholder.persona")
        case .knowledge: return t("storeCharacter.placeholder.knowledge")
        }
    }
    private var mapPointValue: Text {
        if let address = c.mapPoint.displayAddress { return Text(verbatim: address) }
        return c.mapPoint.hasPoint ? t("storeCharacter.mapPoint.selected") : t("storeCharacter.mapPoint.unset")
    }

    @ViewBuilder private var avatarRows: some View {
        Section {
            HStack(spacing: 12) {
                Button { c.choosePhoto() } label: { t("storeCharacter.avatar.uploadPhoto").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).disabled(c.saving).accessibilityIdentifier("aiNPC.avatar.photo")
                Button { c.openPresets() } label: { t("storeCharacter.avatar.presets").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).disabled(c.saving).accessibilityIdentifier("aiNPC.avatar.presets")
            }
        }
        if let issue = c.saveIssue { Section { StoreCharacterSaveIssueView(model: model, issue: issue) } }
        if let confirmation = c.saveConfirmation, confirmation.origin == .avatar {
            StoreCharacterSaveConfirmationSection(model: model, confirmation: confirmation)
        } else {
            Section {
                Button { c.saveAvatar() } label: {
                    HStack {
                        Spacer()
                        if c.saving { ProgressView() }
                        (c.saveIssue == nil ? t("storeCharacter.avatar.save") : t("storeCharacter.avatar.retrySave")).bold()
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent).disabled(c.saving || c.saveLocked).accessibilityIdentifier("aiNPC.avatar.save")
            }
        }
    }
}

private struct StoreCharacterRow: View {
    let title: Text
    var required = false
    let value: Text
    let id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                title.foregroundStyle(.primary)
                if required { Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true) }
                Spacer(minLength: 12)
                value.foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

struct StoreCharacterPreview: View {
    let avatar: StoreCharacterAvatar
    let side: CGFloat
    var body: some View {
        Group {
            if let preset = avatar.preset { MerchantNPCPresetArtwork(avatar: preset) }
            else if let url = photoURL {
                // MC7-23-3: render the saved photo avatar (MP ai-npc/index.wxml:26) instead of a grey placeholder.
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { photoPlaceholder }
                }
            } else { photoPlaceholder }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aiNPC.preview")
    }
    /// Absolute https photo references only; a site-relative path keeps the placeholder (no base URL here).
    private var photoURL: URL? {
        guard case .photo(let source) = avatar, source.hasPrefix("https://"), let url = URL(string: source) else { return nil }
        return url
    }
    private var photoPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            VStack(spacing: 6) {
                Image(systemName: "person.crop.square").font(.largeTitle).accessibilityHidden(true)
                t("storeCharacter.hero.photoSaved").cyText(.meta)
            }.foregroundStyle(.secondary)
        }
    }
}

private func storeCharacterNoticeText(_ notice: StoreCharacterCoordinator.Notice, locale: Locale) -> String {
    let key: String.LocalizationValue
    switch notice {
    case .saved: key = "storeCharacter.notice.saved"
    case .nameRequired: key = "storeCharacter.notice.nameRequired"
    case .nameFirst: key = "storeCharacter.notice.nameFirst"
    case .saveProfileFirst: key = "storeCharacter.notice.saveProfileFirst"
    case .photoUnavailable: key = "storeCharacter.notice.photoUnavailable"
    case .writesDisabled: key = "storeCharacter.notice.writesDisabled"
    case .mapPointUnavailable: key = "storeCharacter.notice.mapPointUnavailable"
    case .mapPointFailed(let message):
        if let message { return message }
        key = "storeCharacter.error.request"
    case .mapPointUnknown: key = "storeCharacter.notice.mapPointUnknown"
    case .readbackConfirmed: key = "storeCharacter.notice.readbackConfirmed"
    case .readbackMismatch: key = "storeCharacter.notice.readbackMismatch"
    }
    return String(localized: LocalizedStringResource(key, table: "StoreCharacter", locale: locale))
}

struct StoreCharacterNoticeText: View {
    @Environment(\.locale) private var locale
    let notice: StoreCharacterCoordinator.Notice
    var body: some View {
        Text(verbatim: storeCharacterNoticeText(notice, locale: locale))
            .font(.subheadline)
            .accessibilityIdentifier("aiNPC.notice")
    }
}

struct StoreCharacterSaveIssueView: View {
    @ObservedObject var model: StoreCharacterModel
    let issue: StoreCharacterCoordinator.SaveIssue
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            t("storeCharacter.issue.title").cyText(.bodyMedium)
            switch issue {
            case .rejected(let message):
                if let message { Text(verbatim: message) } else { t("storeCharacter.error.request") }
            case .unknown: t("storeCharacter.issue.unknown")
            case .readbackFailed:
                t("storeCharacter.issue.readbackFailed")
                Button { Task { await model.coordinator.readbackSave() } } label: { t("storeCharacter.action.readback") }
                    .accessibilityIdentifier("aiNPC.save.readback")
            }
        }
        .cyText(.bodyCompact).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("aiNPC.save.issue")
    }
}

struct StoreCharacterSaveConfirmationSection: View {
    @ObservedObject var model: StoreCharacterModel
    let confirmation: StoreCharacterCoordinator.SaveConfirmation
    var body: some View {
        Section {
            line(t("storeCharacter.row.name"), confirmation.payload.name)
            line(t("storeCharacter.row.greeting"), confirmation.payload.greeting)
            line(t("storeCharacter.row.persona"), confirmation.payload.persona)
            line(t("storeCharacter.row.knowledge"), confirmation.payload.knowledge)
            HStack {
                t("storeCharacter.row.avatar")
                Spacer()
                if let avatar = StoreCharacterAvatar(code: confirmation.payload.avatar), let preset = avatar.preset {
                    Text(LocalizedStringKey(preset.titleKey))
                } else { t("storeCharacter.hero.photoSaved") }
            }
            t("storeCharacter.confirm.reviewHint").cyText(.bodyCompact).foregroundStyle(.secondary)
            Button { Task { await model.coordinator.confirmSave(confirmation.id) } } label: { t("storeCharacter.action.confirmSave").bold() }
                .accessibilityIdentifier("aiNPC.save.confirm")
            Button(role: .cancel) { model.coordinator.cancelSave() } label: { t("storeCharacter.action.cancel") }
                .accessibilityIdentifier("aiNPC.save.cancel")
        } header: { t("storeCharacter.confirm.title") }
    }
    private func line(_ title: Text, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            title.cyText(.meta).foregroundStyle(.secondary)
            if value.isEmpty { t("storeCharacter.confirm.empty").foregroundStyle(.secondary) } else { Text(verbatim: value) }
        }
    }
}

private struct StoreCharacterFieldSheet: View {
    @ObservedObject var model: StoreCharacterModel
    private var c: StoreCharacterCoordinator { model.coordinator }
    var body: some View {
        NavigationStack {
            Form {
                if let edit = c.field, edit.field == .persona {
                    // MC7-23-4: MP M-28 性格三选一 (温柔 / 可爱 / 毒舌), no free text. The Chinese label is the saved
                    // value (MP writes the label into `persona`; the `personality` enum is a Core follow-up).
                    Section {
                        ForEach(Self.personas.indices, id: \.self) { index in
                            let option = Self.personas[index]
                            Button {
                                c.updateField(option.value)
                                c.saveField()
                            } label: {
                                HStack {
                                    Text(option.title).foregroundStyle(CYColor.textPrimary)
                                    Spacer()
                                    if edit.value == option.value {
                                        Image(systemName: c.saving ? "clock" : "checkmark").foregroundStyle(CYColor.brand).accessibilityHidden(true)
                                    }
                                }
                                .frame(minHeight: CYSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                            }
                            .disabled(c.saving || c.saveLocked)
                            .accessibilityAddTraits(edit.value == option.value ? [.isSelected] : [])
                            .accessibilityIdentifier("aiNPC.persona." + option.id)
                        }
                    }
                    if let notice = c.notice { Section { StoreCharacterNoticeText(notice: notice) } }
                    if let issue = c.saveIssue { Section { StoreCharacterSaveIssueView(model: model, issue: issue) } }
                    if let confirmation = c.saveConfirmation, case .field = confirmation.origin {
                        StoreCharacterSaveConfirmationSection(model: model, confirmation: confirmation)
                    }
                } else if let edit = c.field {
                    Section {
                        TextField(text: Binding(get: { c.field?.value ?? "" }, set: { c.updateField($0) }),
                                  axis: edit.field.multiline ? .vertical : .horizontal) { label(edit.field) }
                            .lineLimit(edit.field.multiline ? 6...14 : 1...1)
                            .disabled(c.saving).accessibilityIdentifier("aiNPC.field.input")
                        HStack { Spacer(); Text(verbatim: edit.counter).cyText(.meta).foregroundStyle(.secondary).accessibilityIdentifier("aiNPC.field.counter") }
                    }
                    if let notice = c.notice { Section { StoreCharacterNoticeText(notice: notice) } }
                    if let issue = c.saveIssue { Section { StoreCharacterSaveIssueView(model: model, issue: issue) } }
                    if let confirmation = c.saveConfirmation, case .field = confirmation.origin {
                        StoreCharacterSaveConfirmationSection(model: model, confirmation: confirmation)
                    } else {
                        Section {
                            Button { c.saveField() } label: {
                                HStack { Spacer(); if c.saving { ProgressView() }; t("storeCharacter.action.save").bold(); Spacer() }
                            }
                            .disabled(c.saving || c.saveLocked).accessibilityIdentifier("aiNPC.field.save")
                        }
                    }
                }
            }
            .navigationTitle(c.field.map { label($0.field) } ?? Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { c.closeField() } label: { t("storeCharacter.action.close") }.disabled(c.saving).accessibilityIdentifier("aiNPC.field.close")
                }
            }
        }
        .interactiveDismissDisabled(c.saving || c.field.map { $0.value != $0.initial } == true)
        .cyDomainSheet(detents: c.field?.field.multiline == true && c.field?.field != .persona ? [.full] : [.half])
        .themeDomain(.merchant)
    }
    /// MP `PERSONALITIES` (ai-npc/index.js:30): key, saved Chinese label, display title.
    static var personas: [(id: String, value: String, title: LocalizedStringKey)] {
        [("gentle", "温柔", "merchantCoop.npc.persona.gentle"),
         ("cute", "可爱", "merchantCoop.npc.persona.cute"),
         ("savage", "毒舌", "merchantCoop.npc.persona.savage")]
    }
    private func label(_ field: StoreCharacterField) -> Text {
        switch field {
        case .name: return t("storeCharacter.field.name")
        case .greeting: return t("storeCharacter.field.greeting")
        case .persona: return t("storeCharacter.field.persona")
        case .knowledge: return t("storeCharacter.field.knowledge")
        }
    }
}

private struct StoreCharacterPresetSheet: View {
    @ObservedObject var model: StoreCharacterModel
    private var c: StoreCharacterCoordinator { model.coordinator }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                    ForEach(MerchantNPCPresetAvatar.all) { preset in
                        Button { c.pickPreset(preset.id) } label: {
                            VStack(spacing: 6) {
                                MerchantNPCPresetArtwork(avatar: preset).frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).stroke(c.presetPick == preset.id ? Color.accentColor : .clear, lineWidth: 3))
                                Text(LocalizedStringKey(preset.titleKey)).cyText(.meta)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(c.presetPick == preset.id ? [.isSelected] : [])
                        .accessibilityIdentifier("aiNPC.preset." + preset.id)
                    }
                }
                .padding()
                Button { c.confirmPreset() } label: { t("storeCharacter.preset.use").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).padding(.horizontal).accessibilityIdentifier("aiNPC.preset.use")
            }
            .navigationTitle(t("storeCharacter.preset.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { c.closePresets() } label: { t("storeCharacter.action.close") } }
            }
        }
    }
}

private struct StoreCharacterVoiceSheet: View {
    @ObservedObject var model: StoreCharacterModel
    private var c: StoreCharacterCoordinator { model.coordinator }
    private var status: StoreCharacterVoiceState.Status { c.voice?.status ?? .none }
    /// MC7-23-5: 试听原录音 / 暂停试听 of the enrolled sample (MP `playVoice`).
    @State private var samplePlayer: AVPlayer?
    @State private var samplePlaying = false
    private var sampleURL: URL? {
        guard let sample = c.voice?.sample, sample.hasPrefix("https://") else { return nil }
        return URL(string: sample)
    }
    private func toggleSample() {
        if samplePlaying { samplePlayer?.pause(); samplePlaying = false; return }
        guard let url = sampleURL else { return }
        let player = samplePlayer ?? AVPlayer(url: url)
        samplePlayer = player
        player.seek(to: .zero)
        player.play()
        samplePlaying = true
    }
    var body: some View {
        NavigationStack {
            List {
                Section { t("storeCharacter.voice.heading").cyText(.cardTitle) }
                if status != .pending {
                    Section {
                        Toggle(isOn: Binding(get: { c.voiceConsent }, set: { c.setVoiceConsent($0) })) { t("storeCharacter.voice.consent").cyText(.bodyCompact) }
                            .accessibilityIdentifier("aiNPC.voice.consent")
                    }
                }
                switch status {
                case .pending:
                    Section {
                        ProgressView()
                        t("storeCharacter.voice.pendingBody")
                        Button { Task { await c.refreshVoice() } } label: { t("storeCharacter.voice.refresh") }.accessibilityIdentifier("aiNPC.voice.refresh")
                    }
                case .ready:
                    Section {
                        t("storeCharacter.voice.readyBody").accessibilityIdentifier("aiNPC.voice.ready")
                        if sampleURL != nil {
                            Button { toggleSample() } label: {
                                Label(samplePlaying ? "merchantCoop.npc.voice.pauseSample" : "merchantCoop.npc.voice.playSample",
                                      systemImage: samplePlaying ? "pause.circle" : "play.circle")
                            }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("aiNPC.voice.playSample")
                        }
                        Button { samplePlayer?.pause(); samplePlaying = false; c.resetRecording() } label: { t("storeCharacter.voice.rerecord") }.accessibilityIdentifier("aiNPC.voice.rerecord")
                    }
                case .none, .failed:
                    if status == .failed { Section { t("storeCharacter.voice.failedBody").foregroundStyle(CYColor.dangerText) } }
                    if let recording = c.recording { recorded(recording) } else { voiceMode }
                }
                if let confirmation = c.voiceConfirmation { consentDialog(confirmation) }
                if let issue = c.voiceIssue {
                    Section {
                        VStack(alignment: .leading, spacing: 4) { t("storeCharacter.issue.title").bold(); issueText(issue) }
                            .cyText(.bodyCompact).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("aiNPC.voice.issue")
                    }
                }
                if c.voiceUnknown {
                    Section {
                        Button { Task { await c.refreshVoice() } } label: { t("storeCharacter.voice.queryStatus") }.accessibilityIdentifier("aiNPC.voice.query")
                    }
                }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { c.closeVoice() } label: { t("storeCharacter.action.close") }.disabled(c.voiceBusy).accessibilityIdentifier("aiNPC.voice.close")
                }
            }
        }
        .interactiveDismissDisabled(c.voiceBusy)
        .onDisappear { samplePlayer?.pause(); samplePlaying = false }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            if let item = note.object as? AVPlayerItem, item === samplePlayer?.currentItem { samplePlaying = false }
        }
    }
    private var title: Text {
        if c.recording != nil { return t("storeCharacter.voice.titleConfirm") }
        switch status {
        case .pending: return t("storeCharacter.voiceValue.pending")
        case .ready: return t("storeCharacter.voiceValue.ready")
        default: return t("storeCharacter.voice.titleRecord")
        }
    }
    @ViewBuilder private var voiceMode: some View {
        Section {
            t("storeCharacter.voice.mode").cyText(.cardTitle)
            HStack(spacing: 6) {
                ForEach(0..<StoreCharacterVoiceScript.sentenceCount, id: \.self) { index in
                    Capsule().fill(index == 0 ? Color.accentColor : Color.secondary.opacity(0.3)).frame(height: 4)
                }
            }
            .accessibilityElement().accessibilityLabel(t("storeCharacter.voice.progress"))
            t("storeCharacter.voice.sentence1")
            Button {} label: { t("storeCharacter.voice.hold").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).disabled(true).accessibilityIdentifier("aiNPC.voice.hold")
            t("storeCharacter.voice.recordingUnavailable").cyText(.bodyCompact).foregroundStyle(.secondary)
            // MC8-23-8 (ai-npc index.wxml:303): a denied microphone grant offers 去设置开启麦克风.
            if AVAudioApplication.shared.recordPermission == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Label("merchantCoop.npc.voice.openMicSettings", systemImage: "mic.slash").frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("aiNPC.voice.openMicSettings")
            }
            if c.canRecord {
                Button { c.useSyntheticRecording() } label: { t("storeCharacter.voice.useSample") }
                    .disabled(c.voiceBusy || c.voiceUnknown).accessibilityIdentifier("aiNPC.voice.useSample")
            }
        }
    }
    @ViewBuilder private func recorded(_ recording: StoreCharacterRecordedSample) -> some View {
        Section {
            t("storeCharacter.voice.recordedTitle").cyText(.cardTitle).accessibilityIdentifier("aiNPC.voice.recorded")
            (Text(verbatim: String(recording.durationSeconds)) + t("storeCharacter.voice.recordedHint")).cyText(.bodyCompact).foregroundStyle(.secondary)
            Button { c.resetRecording() } label: { t("storeCharacter.voice.rerecord") }
                .disabled(c.voiceBusy || c.voiceUnknown).accessibilityIdentifier("aiNPC.voice.reset")
            Button { c.prepareEnroll() } label: {
                HStack { if c.voiceBusy { ProgressView() }; t("storeCharacter.voice.enroll").bold() }
            }
            .disabled(c.voiceBusy || c.voiceUnknown || !c.voiceConsent).accessibilityIdentifier("aiNPC.voice.enroll")
        }
    }
    @ViewBuilder private func consentDialog(_ confirmation: StoreCharacterCoordinator.VoiceConfirmation) -> some View {
        Section {
            t("storeCharacter.consent.body").cyText(.bodyCompact)
            Button { Task { await c.agreeAndEnroll(confirmation.id) } } label: { t("storeCharacter.consent.agree").bold() }
                .accessibilityIdentifier("aiNPC.consent.agree")
            Button(role: .cancel) { c.declineVoiceConsent() } label: { t("storeCharacter.consent.decline") }
                .accessibilityIdentifier("aiNPC.consent.decline")
        } header: { t("storeCharacter.consent.title") }
    }
    private func issueText(_ issue: StoreCharacterCoordinator.VoiceIssue) -> Text {
        switch issue {
        case .server(let message): return message.map { Text(verbatim: $0) } ?? t("storeCharacter.error.request")
        case .statusUnconfirmed: return t("storeCharacter.voiceIssue.statusUnconfirmed")
        case .consentRequired: return t("storeCharacter.voiceIssue.consentRequired")
        case .consentDeclined: return t("storeCharacter.voiceIssue.consentDeclined")
        case .consentFailed: return t("storeCharacter.voiceIssue.consentFailed")
        case .enrollUnknown: return t("storeCharacter.voiceIssue.enrollUnknown")
        case .writesDisabled: return t("storeCharacter.voiceIssue.writesDisabled")
        }
    }
}

/// Reform plan v9 W04/W05, dormant: rendered only when a gate is on (offline fixture only).
private struct StoreCharacterReformSection: View {
    let context: StoreCharacterReformContext
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                t("storeCharacter.reform.storePublic").bold()
                if let key = context.projection.storePublicKey { Text(verbatim: key).font(.caption.monospaced()).textSelection(.enabled) }
                modeText(context.projection.storeMode).cyText(.bodyCompact).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine).accessibilityIdentifier("aiNPC.reform.storePublic")
            VStack(alignment: .leading, spacing: 4) {
                t("storeCharacter.reform.themeBinding").bold()
                switch context.projection.themeBinding {
                case .notBound: t("storeCharacter.reform.themeNotBound")
                case .bound(let key): Text(verbatim: key).font(.caption.monospaced()).textSelection(.enabled)
                case .hintMismatch: t("storeCharacter.reform.themeMismatch")
                }
            }
            .accessibilityElement(children: .combine).accessibilityIdentifier("aiNPC.reform.theme")
            if !context.projection.sharesIsolation { t("storeCharacter.reform.separate").cyText(.bodyCompact) }
            if !context.projection.knowledgeReachesTheme {
                t("storeCharacter.reform.knowledgeIsolation").cyText(.bodyCompact).accessibilityIdentifier("aiNPC.reform.knowledge")
            }
        } header: { t("storeCharacter.reform.scopesHeader") }
        Section {
            LabeledContent { Text(verbatim: context.draft.stage.rawValue) } label: { t("storeCharacter.reform.draftStage") }
            ForEach(context.draft.blockers, id: \.self) { blocker in
                blockerText(blocker).cyText(.bodyCompact).accessibilityIdentifier("aiNPC.reform.blocker." + blocker.rawValue)
            }
            t("storeCharacter.reform.noGeneration").cyText(.bodyCompact).foregroundStyle(.secondary)
        } header: { t("storeCharacter.reform.draftHeader") }
    }
    private func modeText(_ mode: SceneAIAvailability.Mode) -> Text {
        switch mode {
        case .generative: return t("storeCharacter.reform.generative")
        case .nonGenerative: return t("storeCharacter.reform.nonGenerative")
        }
    }
    private func blockerText(_ blocker: MerchantPublishBlocker) -> Text {
        switch blocker {
        case .notApproved: return t("storeCharacter.blocker.notApproved")
        case .missingMerchantFacts: return t("storeCharacter.blocker.missingMerchantFacts")
        case .missingThemeApproval: return t("storeCharacter.blocker.missingThemeApproval")
        case .wrongAuthority: return t("storeCharacter.blocker.wrongAuthority")
        case .selfApproval: return t("storeCharacter.blocker.selfApproval")
        case .editedAfterReview: return t("storeCharacter.blocker.editedAfterReview")
        case .capabilityDisabled: return t("storeCharacter.blocker.capabilityDisabled")
        }
    }
}

/// MP `pages/merchant/decor/ai-npc` first-visit intro (`introSteps`): four pages, each with the two MP npc-intro
/// images (`MPAsset.FeatureIcon.*`), a title and a line. Paged `TabView`; 跳过 in the toolbar, 下一步 / 知道了 below.
@MainActor struct StoreCharacterIntroSheet: View {
    static let seenKey = "cy_ai_npc_intro_seen"
    let onDone: () -> Void
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Step { let a: Image; let b: Image; let title: LocalizedStringKey; let line: LocalizedStringKey }
    private var steps: [Step] {
        [
            Step(a: MPAsset.FeatureIcon.convenienceStore, b: MPAsset.FeatureIcon.sparkles,
                 title: "merchantCoop.aiNpc.intro.avatar.title", line: "merchantCoop.aiNpc.intro.avatar.line"),
            Step(a: MPAsset.FeatureIcon.wavingHand, b: MPAsset.FeatureIcon.speechBalloon,
                 title: "merchantCoop.aiNpc.intro.greet.title", line: "merchantCoop.aiNpc.intro.greet.line"),
            Step(a: MPAsset.FeatureIcon.forkAndKnifeWithPlate, b: MPAsset.FeatureIcon.alarmClock,
                 title: "merchantCoop.aiNpc.intro.menu.title", line: "merchantCoop.aiNpc.intro.menu.line"),
            Step(a: MPAsset.FeatureIcon.nameBadge, b: MPAsset.FeatureIcon.performingArts,
                 title: "merchantCoop.aiNpc.intro.persona.title", line: "merchantCoop.aiNpc.intro.persona.line"),
        ]
    }
    private var isLast: Bool { step >= steps.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.lg) {
                TabView(selection: $step) {
                    ForEach(steps.indices, id: \.self) { index in
                        page(steps[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                CYPillButton(isLast ? "merchantCoop.aiNpc.intro.done" : "merchantCoop.aiNpc.intro.next") {
                    if isLast { onDone() } else if reduceMotion { step += 1 } else { withAnimation { step += 1 } }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.bottom, CYSpacing.lg)
                .accessibilityIdentifier("aiNPC.intro.next")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isLast {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("merchantCoop.aiNpc.intro.skip", action: onDone)
                            .accessibilityIdentifier("aiNPC.intro.skip")
                    }
                }
            }
        }
        .accessibilityIdentifier("aiNPC.intro")
    }

    private func page(_ item: Step) -> some View {
        VStack(spacing: CYSpacing.md) {
            HStack(alignment: .bottom, spacing: CYSpacing.sm) {
                item.a.resizable().scaledToFit().frame(width: 120, height: 120)
                item.b.resizable().scaledToFit().frame(width: 64, height: 64)
            }
            .accessibilityHidden(true)
            Text(item.title)
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(item.line)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .accessibilityElement(children: .combine)
    }
}
