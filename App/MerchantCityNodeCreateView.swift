import SwiftUI

/// Native counterpart of mini `pages/merchant/citynode/create` (报名成为节点).
/// The template is configured in the existing full merchant template editor; this page only
/// confirms the store address and submits the existing `city-node/save` placement application.
@MainActor struct MerchantCityNodeCreateView: View {
    private struct Picked: Equatable { var name: String, address: String, latitude: String, longitude: String }
    private enum Readback: Equatable { case idle, reading, missing, failed }
    let service: any MerchantContentServing
    let placeSearch: (any PublishingPlaceSearching)?
    let isOfflineFixture: Bool
    private let templateSeed: Int?
    @Environment(\.dismiss) private var dismiss
    /// MC7-25-2: 登录 opens the app sign-in (injected hook, else 我的 tab); with neither it relabels to 返回.
    @Environment(\.merchantOpenSignIn) private var openSignIn
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.merchantCityTemplateHandoffFactory) private var handoffFactory
    @StateObject private var model: MerchantContentViewModel
    @StateObject private var handoff = MerchantCityTemplateHandoffModel()
    @StateObject private var addressChoice = MerchantCityAddressChoice()
    @State private var templateID = 0
    @State private var picked: Picked?
    @State private var fromProfile = false
    @State private var confirmed = false
    @State private var addressGeneration = UUID()
    @State private var dirty = false
    @State private var stamps: [Int: Date] = [:]
    @State private var submittedID: Int?
    @State private var readback: Readback = .idle
    @State private var uncertainReadback: Bool?
    @State private var submitAttempted = false
    @State private var confirming = false
    @State private var leave = false
    @State private var toast: String?
    @State private var handoffReading = false
    @State private var protectedReadback: Date?

    init(service: any MerchantContentServing, placeSearch: (any PublishingPlaceSearching)? = nil, isOfflineFixture: Bool = false, templateSeed: Int? = nil) {
        self.service = service; self.placeSearch = placeSearch; self.isOfflineFixture = isOfflineFixture; self.templateSeed = templateSeed
        _model = StateObject(wrappedValue: MerchantContentViewModel(service: service, query: .cityPlacement))
    }
    private var c: MerchantContentCoordinator { model.coordinator }
    private var submitting: Bool { c.busy || confirming || readback == .reading }
    private var fields: [String: String] {
        guard let picked else { return [:] }
        return ["name": picked.name, "address": picked.address, "latitude": picked.latitude, "longitude": picked.longitude]
    }
    private var localDraft: MerchantCityTemplateLocalDraft { .init(fields: fields, templateID: templateID, confirmedAddress: confirmed, dirty: dirty) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }.padding()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { if c.isCurrent, c.snapshot != nil || submittedID != nil { submitBar } }
        .cyDomainScreen(.merchant)
        .cyHideTabBar(true)
        .navigationTitle(MerchantCityNodeCopy.string("merchantCityNode.create.title")).navigationBarTitleDisplayMode(.inline)
        .task(id: service.scope) { resetDraft(); await model.load(); seedIfNeeded() }
        .onChange(of: c.snapshot?.observedAt) { _, stamp in
            if !dirty, !handoffReading, submittedID == nil, stamp != protectedReadback { seedIfNeeded() }
        }
        .onChange(of: service.scope) { _, _ in addressChoice.invalidate() }
        .onAppear { addressChoice.appear(active: scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in addressChoice.sceneChanged(active: phase == .active) }
        .cyGuardedBack(when: dirty || submitting) { back() }
        .interactiveDismissDisabled(dirty || submitting)
        .cyModalConfirm(
            isPresented: leave,
            title: MerchantCityNodeCopy.string("merchantCityNode.create.leaveTitle"),
            message: MerchantCityNodeCopy.string("merchantCityNode.create.leaveBody"),
            cancelTitle: MerchantCityNodeCopy.string("merchantCityNode.create.leaveCancel"),
            confirmTitle: MerchantCityNodeCopy.string("merchantCityNode.create.leaveConfirm"),
            isDestructive: true,
            confirmIdentifier: "cityNodeCreate.leave.confirm",
            onCancel: { leave = false },
            onConfirm: {
                leave = false
                dirty = false
                model.invalidate()
                dismiss()
            }
        )
        .cyModalConfirm(
            isPresented: c.isCurrent && c.review != nil,
            title: MerchantCityNodeCopy.string("merchantCityNode.confirm.placeTitle"),
            message: MerchantCityNodeCopy.string("merchantCityNode.confirm.placeBody"),
            cancelTitle: MerchantCityNodeCopy.string("merchantCityNode.action.cancel"),
            confirmTitle: MerchantCityNodeCopy.string("merchantCityNode.create.submit"),
            isConfirmLoading: confirming,
            confirmIdentifier: "cityNodeCreate.confirm",
            onCancel: { if !confirming { model.cancel() } },
            onConfirm: {
                if let review = c.review {
                    confirming = true
                    Task { await confirm(review) }
                }
            }
        )
        .modifier(MerchantCityTemplateHandoffPresentation(model: handoff, binding: templateBinding))
        .background {
            if let attachment = addressChoice.attachment {
                MerchantCityAddressChoiceLifetime(owner: addressChoice, attachment: attachment).id(attachment)
            }
            if let original = addressChoice.item {
                MerchantCityAddressChoicePresentation(owner: addressChoice, original: original, current: { addressSource }, apply: applyPlace).id(original.id)
            }
        }
        .cyToast(verbatimMessage: $toast, tone: .info)
        .task(id: toast) { if toast != nil { try? await Task.sleep(nanoseconds: 4_000_000_000); toast = nil } }
    }

    @ViewBuilder private var content: some View {
        if c.isCurrent, let snapshot = c.snapshot { ready(snapshot) }
        else if c.isCurrent, submittedID != nil { ready(nil) }
        else if c.busy || c.loadedScope != service.scope {
            HStack(spacing: 10) { ProgressView(); MerchantCityNodeCopy.text("merchantCityNode.create.accessLoading") }
                .frame(maxWidth: .infinity).padding(.vertical, 40).accessibilityIdentifier("cityNodeCreate.loading")
        } else if c.issue == "merchant.content.signedOut" || !service.isAuthenticated {
            VStack(spacing: 12) {
                stateView(title: "merchantCityNode.create.login", sub: nil, identifier: "cityNodeCreate.login", retry: false)
                Button {
                    if let openSignIn { openSignIn() }
                    else if rootTabSwitch.isAvailable { rootTabSwitch(.mine) }
                    else { dismiss() }
                } label: {
                    Text(openSignIn != nil || rootTabSwitch.isAvailable ? LocalizedStringKey("auth.signIn") : LocalizedStringKey("action.back"))
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("cityNodeCreate.login.action")
            }
        } else if c.issue == "merchant.content.denied" {
            stateView(title: "merchantCityNode.permission.title", sub: MerchantCityNodeCopy.string("merchantCityNode.permission.sub"), identifier: "cityNodeCreate.noPermission", retry: false)
        } else {
            stateView(title: "merchantCityNode.create.accessFailed", sub: MerchantCityNodeCopy.failure(c, fallback: MerchantCityNodeCopy.string("merchantCityNode.create.accessFallback")),
                      identifier: "cityNodeCreate.accessError", retry: true)
        }
    }
    private func stateView(title: String, sub: String?, identifier: String, retry: Bool) -> some View {
        ContentUnavailableView {
            Label { MerchantCityNodeCopy.text(title) } icon: { Image(systemName: retry ? "exclamationmark.triangle" : "person.crop.circle") }
        } description: {
            if let sub { Text(verbatim: sub) }
        } actions: {
            if retry {
                Button { Task { await model.load(); seedIfNeeded() } } label: { MerchantCityNodeCopy.text("merchantCityNode.action.retry") }
                    .buttonStyle(.bordered).frame(minHeight: CYSpacing.minTouchTarget).accessibilityIdentifier("cityNodeCreate.retry")
            }
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }

    @ViewBuilder private func ready(_ snapshot: MerchantContentSnapshot?) -> some View {
        MerchantCityNodeCopy.text("merchantCityNode.create.lede").font(.subheadline).foregroundStyle(.secondary)
        if !MerchantCityNodeWriteGate.saveAvailable(permitsWrites: service.permitsWrites, isOfflineExample: isOfflineFixture) {
            MerchantCityNodeCopy.text("merchantCityNode.write.disabled").cyText(.bodyCompact).foregroundStyle(.secondary)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(CYColor.warningSoft, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                .accessibilityIdentifier("cityNodeCreate.writeUnavailable")
        }
        timeline
        templateCard(snapshot)
        addressCard
        if c.locked {
            VStack(alignment: .leading, spacing: 6) {
                MerchantCityNodeCopy.text("merchantCityNode.write.lockedTitle").cyText(.bodyMedium)
                MerchantCityNodeCopy.text("merchantCityNode.create.unknownBody").cyText(.bodyCompact).foregroundStyle(.secondary)
                if let found = uncertainReadback {
                    MerchantCityNodeCopy.text(found ? "merchantCityNode.create.unknownFound" : "merchantCityNode.create.unknownMissing").cyText(.bodyCompact)
                        .accessibilityIdentifier("cityNodeCreate.unknown.result")
                }
                Button { Task { await readUncertain() } } label: { MerchantCityNodeCopy.text("merchantCityNode.write.readback") }
                    .cyText(.bodyMedium).disabled(c.busy).accessibilityIdentifier("cityNodeCreate.unknown.readback")
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(CYColor.warningSoft, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)).accessibilityIdentifier("cityNodeCreate.locked")
        } else if submitAttempted, submittedID == nil, c.issue != nil, c.review == nil, c.receipt == nil, !submitting {
            MerchantCityNodeInlineError(titleKey: "merchantCityNode.create.submitFailed",
                message: MerchantCityNodeCopy.failure(c, fallback: MerchantCityNodeCopy.string("merchantCityNode.create.submitFallback")),
                actionKey: "merchantCityNode.create.retrySubmit", identifier: "cityNodeCreate.submit.retry") { submit() }
        }
        if submittedID != nil, readback == .missing || readback == .failed {
            MerchantCityNodeInlineError(titleKey: "merchantCityNode.create.readbackTitle",
                message: MerchantCityNodeCopy.string(readback == .missing ? "merchantCityNode.create.readbackMissing" : "merchantCityNode.create.readbackFailed"),
                actionKey: "merchantCityNode.create.readbackRetry", identifier: "cityNodeCreate.readback.retry") { submit() }
        }
    }

    private var timeline: some View {
        let states = MerchantCityNodeTimeline.states(templateReady: templateID > 0, addressConfirmed: confirmed, submitted: submittedID != nil)
        let titles = ["merchantCityNode.station.template", "merchantCityNode.station.address", "merchantCityNode.station.submit", "merchantCityNode.station.review"]
        return HStack(alignment: .top, spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                VStack(spacing: 4) {
                    Image(systemName: states[index] == .done ? "checkmark.circle.fill" : states[index] == .doing ? "circle.inset.filled" : "circle")
                        .foregroundStyle(states[index] == .todo ? Color.secondary : Color.accentColor)
                    MerchantCityNodeCopy.text(titles[index]).font(.caption.weight(states[index] == .doing ? .bold : .regular))
                    if let stamp = stamps[index] {
                        Text(verbatim: MerchantCityNodeCopy.format("merchantCityNode.station.today", stamp.formatted(date: .omitted, time: .shortened)))
                            .cyText(.meta).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cityNodeCreate.station.\(index).\(states[index].rawValue)")
            }
        }
    }

    @ViewBuilder private func templateCard(_ snapshot: MerchantContentSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MerchantCityNodeCopy.text("merchantCityNode.create.templateStep").cyText(.cardTitle)
                Spacer()
                if templateID > 0 {
                    Label { MerchantCityNodeCopy.text("merchantCityNode.create.configured") } icon: { Image(systemName: "checkmark") }
                        .font(.caption.weight(.semibold)).foregroundStyle(CYColor.successText).accessibilityIdentifier("cityNodeCreate.template.configured")
                }
            }
            if templateID > 0 {
                let summary = MerchantCityNodeTemplateSummary(templateID: templateID, templates: snapshot?.value["templates"] ?? .null)
                Text(verbatim: summary.title ?? "#\(templateID)").cyText(.bodyMedium).accessibilityIdentifier("cityNodeCreate.template.title")
                let meta = [summary.interaction.map { MerchantCityNodeCopy.string(interactionKey($0)) },
                            summary.validationMethod.map { MerchantCityNodeCopy.string(validationKey($0)) }].compactMap { $0 }
                if !meta.isEmpty { Text(verbatim: meta.joined(separator: " · ")).cyText(.bodyCompact).foregroundStyle(.secondary).accessibilityIdentifier("cityNodeCreate.template.summary") }
            }
            Button { openTemplate() } label: {
                MerchantCityNodeCopy.text(templateID > 0 ? "merchantCityNode.create.reconfigure" : "merchantCityNode.create.configure")
            }.buttonStyle(.bordered)
                .disabled(!handoff.active || handoffFactory == nil || !templateBinding.canOpen() || handoff.busy || handoff.opening != nil)
                .accessibilityIdentifier("cityNodeCreate.template.configure")
            if handoff.busy && handoff.opening == nil { ProgressView() }
            if handoff.recoveryNeeded, handoff.opening == nil, c.snapshot == nil {
                Button { let permit = handoff.generation; Task { await handoff.recoverParent(binding: templateBinding, permit: permit) } } label: {
                    MerchantCityNodeCopy.text("merchantCityNode.create.templateReread")
                }.cyText(.bodyCompact).disabled(!handoff.active || handoff.busy || !templateBinding.canReload())
            }
            if let issue = handoff.issue, handoff.opening == nil { Text(LocalizedStringKey(issue.key)).cyText(.meta) }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier("cityNodeCreate.template")
    }

    @ViewBuilder private var addressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MerchantCityNodeCopy.text("merchantCityNode.create.addressStep").cyText(.cardTitle)
                Spacer()
                if picked != nil {
                    HStack(spacing: 4) {
                        if confirmed { Image(systemName: "checkmark").accessibilityHidden(true) }
                        MerchantCityNodeCopy.text(confirmed ? "merchantCityNode.create.addressConfirmed" : "merchantCityNode.create.addressPending")
                    }.cyText(.meta, weight: .semibold).foregroundStyle(confirmed ? CYColor.successText : CYColor.warningText).accessibilityIdentifier("cityNodeCreate.address.state")
                }
            }
            let choose: () -> Void = addressSource.map { addressChoice.openAction($0, provider: placeSearch, current: { addressSource }) } ?? {}
            let canChoose = addressSource != nil && placeSearch != nil
            if let picked {
                Text(verbatim: picked.name.isEmpty ? MerchantCityNodeCopy.string("merchantCityNode.create.myStore") : picked.name).cyText(.bodyMedium)
                    .accessibilityIdentifier("cityNodeCreate.address.name")
                if !picked.address.isEmpty { Text(verbatim: picked.address).cyText(.bodyCompact).foregroundStyle(.secondary).accessibilityIdentifier("cityNodeCreate.address.line") }
                if fromProfile && !confirmed {
                    Text(verbatim: MerchantCityNodeCopy.format("merchantCityNode.create.profileHint", 80)).cyText(.bodyCompact).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("cityNodeCreate.address.hint")
                    HStack {
                        Button { confirmProfileAddress() } label: { MerchantCityNodeCopy.text("merchantCityNode.create.confirmAddress") }
                            .buttonStyle(.borderedProminent).disabled(submitting || submittedID != nil).accessibilityIdentifier("cityNodeCreate.address.confirm")
                        Button(action: choose) { MerchantCityNodeCopy.text("merchantCityNode.create.repick") }
                            .buttonStyle(.bordered).disabled(!canChoose).accessibilityIdentifier("cityNodeCreate.address.repick")
                    }
                } else {
                    Button(action: choose) { MerchantCityNodeCopy.text("merchantCityNode.create.repickAddress") }
                        .buttonStyle(.bordered).disabled(!canChoose).accessibilityIdentifier("cityNodeCreate.address.repickAddress")
                }
            } else {
                MerchantCityNodeCopy.text("merchantCityNode.create.noCoordinate").cyText(.bodyCompact).foregroundStyle(.secondary)
                Button(action: choose) { MerchantCityNodeCopy.text("merchantCityNode.create.markOnMap") }
                    .buttonStyle(.bordered).disabled(!canChoose).accessibilityIdentifier("cityNodeCreate.address.mark")
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier("cityNodeCreate.address")
    }

    private var submitBar: some View {
        let ready = templateID > 0 && picked != nil && confirmed
        return CYFooterBar {
            Button { submit() } label: {
                HStack(spacing: 8) {
                    if submitting { ProgressView() }
                    MerchantCityNodeCopy.text(submittedID != nil ? "merchantCityNode.create.reread" : "merchantCityNode.create.submit")
                }.cyText(.cardTitle).frame(maxWidth: .infinity).padding(.vertical, 6)
            }.buttonStyle(.borderedProminent).disabled(!ready && submittedID == nil)
                .accessibilityIdentifier("cityNodeCreate.submit")
        }
    }

    // MARK: Draft state

    private func resetDraft() {
        templateID = templateSeed ?? 0; picked = nil; fromProfile = false; confirmed = false; dirty = false; stamps = [:]
        submittedID = nil; readback = .idle; uncertainReadback = nil; submitAttempted = false; addressGeneration = UUID()
        if templateSeed != nil { stamp(0) }
    }
    private func seedIfNeeded() {
        guard c.isCurrent, let snapshot = c.snapshot else { return }
        if let profile = MerchantCityNodeProfileAddress(profile: snapshot.value["profile"]) {
            picked = .init(name: profile.name, address: profile.address, latitude: profile.latitude, longitude: profile.longitude); fromProfile = true
        } else { picked = nil; fromProfile = false }
        confirmed = false; addressGeneration = UUID()
    }
    private func stamp(_ index: Int) { if stamps[index] == nil { stamps[index] = Date() } }
    private func confirmProfileAddress() {
        guard picked != nil, !submitting, submittedID == nil else { return }
        confirmed = true; addressGeneration = UUID(); stamp(1); dirty = true; model.cancel()
    }
    private var addressSource: MerchantCityAddressChoice.Source? {
        guard service.isAuthenticated, c.isCurrent, !c.busy, !c.locked, c.review == nil, c.receipt == nil, submittedID == nil,
              let snapshot = c.snapshot, let merchantID = snapshot.access.merchantID else { return nil }
        return .init(scope: service.scope, observedAt: snapshot.observedAt, merchantID: merchantID, templateID: templateID,
                     addressGeneration: addressGeneration, fields: fields.mapValues { Data($0.utf8) }, addressConfirmed: confirmed)
    }
    private func applyPlace(_ original: MerchantCityAddressChoice.Source, _ place: PublishingPlace) -> Bool {
        guard addressSource == original else { return false }
        picked = .init(name: place.name, address: place.address, latitude: String(place.latitude), longitude: String(place.longitude))
        fromProfile = false; confirmed = true; addressGeneration = UUID(); stamp(1); dirty = true; model.cancel(); return true
    }
    private var templateBinding: MerchantCityTemplateHandoffBinding {
        .init(scope: { service.scope }, isAuthenticated: { service.isAuthenticated }, snapshot: { c.snapshot }, draft: { localDraft },
              canOpen: { c.isCurrent && !c.busy && !c.locked && c.review == nil && c.receipt == nil && submittedID == nil },
              canReload: { service.isAuthenticated && !c.busy && !c.locked && c.review == nil && c.receipt == nil },
              reload: {
            handoffReading = true
            await model.load()
            protectedReadback = c.snapshot?.observedAt
            handoffReading = false
        }, apply: { original, id, refreshed in
            guard c.isCurrent, !c.busy, !c.locked, c.review == nil, c.receipt == nil, localDraft == original,
                  MerchantCityTemplateHandoff.sameSnapshot(c.snapshot, refreshed), let merchantID = refreshed.access.merchantID,
                  (try? MerchantCityTemplateHandoff.returnedTemplate(id: id, snapshot: refreshed, scope: service.scope, merchantID: merchantID)) != nil else { return false }
            templateID = id; stamp(0); dirty = true; model.cancel(); return true
        }, isOfflineFixture: isOfflineFixture)
    }
    private func openTemplate() {
        let permit = handoff.generation
        Task {
            guard handoff.accepts(permit) else { return }
            await handoff.open(handoffFactory?(), binding: templateBinding, permit: permit)
        }
    }

    // MARK: Submit, confirmation and readback

    private func back() {
        if submitting { toast = MerchantCityNodeCopy.string("merchantCityNode.create.busy"); return }
        if dirty { leave = true } else { dismiss() }
    }
    private func submit() {
        if submitting { toast = MerchantCityNodeCopy.string("merchantCityNode.create.busy"); return }
        if let submittedID { Task { await readBack(submittedID) }; return }
        guard templateID > 0 else { toast = MerchantCityNodeCopy.string("merchantCityNode.create.needTemplate"); return }
        guard let picked else { toast = MerchantCityNodeCopy.string("merchantCityNode.create.needAddress"); return }
        guard confirmed else { toast = MerchantCityNodeCopy.string("merchantCityNode.create.needConfirm"); return }
        guard c.isCurrent, let snapshot = c.snapshot, !c.locked, c.review == nil else { return }
        switch MerchantCityQuota(catalog: snapshot.value["catalog"]).state {
        case .unknown: toast = MerchantCityNodeCopy.string("merchantCityNode.place.quotaRetry"); return
        case .none: toast = MerchantCityNodeCopy.string("merchantCityNode.place.noQuota"); return
        case .full: toast = MerchantCityNodeCopy.string("merchantCityNode.place.full"); return
        case .available: break
        }
        guard MerchantCityNodeWriteGate.enabled(permitsWrites: service.permitsWrites, isOfflineExample: isOfflineFixture, path: "api/merchant/city-node/save") else {
            toast = MerchantCityNodeCopy.string("merchantCityNode.write.disabled"); return
        }
        var draft = MerchantCityPlacementDraft()
        draft.templateID = templateID; draft.latitude = picked.latitude; draft.longitude = picked.longitude
        draft.name = picked.name; draft.address = picked.address; draft.addressConfirmed = true
        submitAttempted = true
        model.prepare(.place(draft))
    }
    private func confirm(_ review: MerchantContentReview) async {
        await model.confirm(review); confirming = false
        guard let receipt = c.receipt, let id = MerchantCityPlacementReceipt.applicationID(receipt.data) else { return }
        submittedID = id; stamp(2); dirty = false
        toast = MerchantCityNodeCopy.string("merchantCityNode.create.submitted")
        await readBack(id)
    }
    private func readBack(_ id: Int) async {
        readback = .reading
        await model.load()
        guard c.isCurrent, let snapshot = c.snapshot else { readback = .failed; return }
        if MerchantCityPlacementReceipt.contains(applicationID: id, catalog: snapshot.value["catalog"]) { readback = .idle; dismiss() }
        else { readback = .missing }
    }
    /// The journal lock stays: a projection that resembles success never clears an unknown write.
    private func readUncertain() async {
        uncertainReadback = nil
        await model.load()
        guard c.isCurrent, let snapshot = c.snapshot else { return }
        uncertainReadback = MerchantCityPlacementReceipt.hasPendingPlacement(snapshot.value["catalog"])
    }

    private func interactionKey(_ code: String) -> String {
        switch code {
        case "city_story_card": return "merchantCityNode.interaction.cityStoryCard"
        case "hidden_menu": return "merchantCityNode.interaction.hiddenMenu"
        case "photo_spot": return "merchantCityNode.interaction.photoSpot"
        default: return "merchantCityNode.interaction.qrCheckin"
        }
    }
    private func validationKey(_ code: Int) -> String {
        switch code {
        case 0: return "merchantCityNode.validation.0"
        case 1: return "merchantCityNode.validation.1"
        case 2: return "merchantCityNode.validation.2"
        case 3: return "merchantCityNode.validation.3"
        case 4: return "merchantCityNode.validation.4"
        case 5: return "merchantCityNode.validation.5"
        case 6: return "merchantCityNode.validation.6"
        default: return "merchantCityNode.validation.7"
        }
    }
}
