import SwiftUI

/// Native counterpart of mini-program pages/play/merchant: arrival, photo proof, verification
/// hand-off and records only. Gameplay beyond the in-store quiz is handed back to the play host.
@MainActor struct PlayStoreDayMerchantView: View {
    @Bindable var model: PlayStoreDayCoordinator
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var mediaScope: UUID = UUID()
    /// Hero artwork loads only from explicitly approved https hosts; otherwise a placeholder.
    var approvedImageHosts: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.locale) private var locale
    @State private var pendingProof: PlayStoreDayPreparedProof?
    @State private var showingProof = false
    @State private var confirmRevoke = false
    /// PLAYM-1: MP shows the purpose once (用一次位置确认你到店了) before the first foreground fix.
    @State private var showingArrivePurpose = false
    @State private var arrivePurposeShown = false
    @State private var showingMore = false
    /// PLAYM-3: no 到店体验 page-type title over the hero; the store's name shows inline once the hero scrolls away.
    @State private var heroScrolledAway = false

    private enum Sheet: String, Identifiable { case game, task; var id: String { rawValue } }
    private var sheet: Binding<Sheet?> {
        Binding(get: { model.game.show ? .game : model.taskVisible ? .task : nil },
                set: { if $0 == nil { model.closeSheets() } })
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loaded:
                if let node = model.node { content(node) } else { stateView("playStoreDay.state.notFound", id: "notFound") }
            case .loading: ProgressView { Text("playStoreDay.state.loading", tableName: "PlayStoreDay") }.accessibilityIdentifier("storeDayPage.state.loading")
            case .notFound: stateView("playStoreDay.state.notFound", id: "notFound")
            case .failed: stateView("playStoreDay.state.failed", id: "failed")
            case .signedOut: stateView("playStoreDay.state.signedOut", id: "signedOut")
            case .unavailable: stateView("playStoreDay.state.unavailable", id: "unavailable")
            }
        }
        .privacySensitive()
        .background(CYColor.bgPage)
        .modifier(PlayStoreDayTitle(hero: model.phase == .loaded && model.node != nil, name: model.node?.name, scrolledAway: heroScrolledAway))
        .task(id: model.nodeID) { await model.load() }
        .sheet(item: sheet) { item in
            switch item {
            case .game:
                gameSheet
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.player)
            case .task:
                taskSheet
                    .cyDomainSheet(detents: [.half])
                    .themeDomain(.player)
            }
        }
        .cyModalConfirm(
            isPresented: showingProof,
            title: String(localized: LocalizedStringResource("playStoreDay.proofConfirm.title", table: "PlayStoreDay", locale: locale)),
            message: String(localized: LocalizedStringResource("playStoreDay.proofConfirm.notice", table: "PlayStoreDay", locale: locale)),
            cancelTitle: String(localized: LocalizedStringResource("playStoreDay.cancel", table: "PlayStoreDay", locale: locale)),
            confirmTitle: pendingProofIsPhoto
                ? String(localized: LocalizedStringResource("playStoreDay.proofConfirm.photo", table: "PlayStoreDay", locale: locale))
                : String(localized: LocalizedStringResource("playStoreDay.proofConfirm.scan", table: "PlayStoreDay", locale: locale)),
            onCancel: {
                showingProof = false
                pendingProof = nil
                model.cancelPreparedProof()
            },
            onConfirm: {
                showingProof = false
                guard let proof = pendingProof else { return }
                pendingProof = nil
                Task { await model.submitProof(proof) }
            }
        )
        .onChange(of: model.preparedProof) { _, proof in
            guard let proof else { return }
            pendingProof = proof
            // Let a closing task sheet finish before the confirmation is presented.
            Task { try? await Task.sleep(nanoseconds: 450_000_000); if pendingProof == proof, model.preparedProof == proof { showingProof = true } }
        }
        .onChange(of: showingProof) { _, visible in if !visible, pendingProof != nil { pendingProof = nil; model.cancelPreparedProof() } }
        .cyModalConfirm(
            isPresented: model.consentPromptVisible,
            title: String(localized: LocalizedStringResource("playStoreDay.modal.title", table: "PlayStoreDay", locale: locale)),
            message: String(format: String(localized: LocalizedStringResource("playStoreDay.modal.body", table: "PlayStoreDay", locale: locale)), storeName),
            cancelTitle: String(localized: LocalizedStringResource("playStoreDay.cancel", table: "PlayStoreDay", locale: locale)),
            confirmTitle: String(localized: LocalizedStringResource("playStoreDay.modal.confirm", table: "PlayStoreDay", locale: locale)),
            confirmIdentifier: "storeDayPage.modal.confirm",
            onCancel: { model.declineConsent() },
            onConfirm: { Task { await model.agreeConsent() } }
        )
        .cyModalConfirm(
            isPresented: confirmRevoke,
            title: String(localized: LocalizedStringResource("playStoreDay.revokeConfirm.title", table: "PlayStoreDay", locale: locale)),
            cancelTitle: String(localized: LocalizedStringResource("playStoreDay.cancel", table: "PlayStoreDay", locale: locale)),
            confirmTitle: String(localized: LocalizedStringResource("playStoreDay.consent.revoke", table: "PlayStoreDay", locale: locale)),
            isDestructive: true,
            onCancel: { confirmRevoke = false },
            onConfirm: {
                confirmRevoke = false
                Task { await model.revokeConsent() }
            }
        )
        .onChange(of: model.dismissRequested) { _, requested in if requested { dismiss() } }
    }

    private var pendingProofIsPhoto: Bool { if case .photo = pendingProof { return true }; return false }
    private var storeName: String { model.node?.name ?? L("playStoreDay.consent.defaultStore") }
    private func L(_ key: String.LocalizationValue) -> String { String(localized: key, table: "PlayStoreDay") }

    private func stateView(_ key: String.LocalizationValue, id: String) -> some View {
        ContentUnavailableView {
            Label { Text(L(key)) } icon: { Image(systemName: id == "signedOut" ? "person.crop.circle" : id == "failed" ? "exclamationmark.triangle" : "storefront") }
        } actions: {
            // PLAYM-6: MP cy-access-gate kind=login — signed out offers 登录 (opens 我的).
            if id == "signedOut", rootTabSwitch.isAvailable {
                Button { rootTabSwitch(.mine) } label: { Text("auth.signIn") }
                    .buttonStyle(.cyPrimary(fullWidth: false)).accessibilityIdentifier("storeDayPage.signIn")
            }
            Button { Task { await model.load() } } label: { Text("playStoreDay.state.reload", tableName: "PlayStoreDay") }
                .buttonStyle(.cyPrimary(fullWidth: false))
                .disabled(model.phase == .loading).accessibilityIdentifier("storeDayPage.refresh")
            // PLAYM-4: MP 链接已失效 offers 重新加载 and 返回.
            Button { dismiss() } label: { Text("playStoreDay.state.back", tableName: "PlayStoreDay") }
                .buttonStyle(.cySecondary(fullWidth: false)).accessibilityIdentifier("storeDayPage.back")
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("storeDayPage.state." + id)
    }

    // MARK: Page
    // Mini-program order: hero -> head (tag, name, meta) -> proof steps -> reference stats -> feedback
    // -> consent -> merchant info; primary action docked at the bottom.
    private func content(_ node: PlayStoreDayNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(node)
                VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    header(node)
                    proofSection(node)
                    referenceSection(node)
                    if let notice = model.notice {
                        Text(verbatim: noticeText(notice)).cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
                            .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                            .accessibilityIdentifier("storeDayPage.feedback")
                    }
                    if model.consent == .agree { consentSection }
                    if let perk = node.perk, let name = perk.name { perkSection(name: name, rule: perk.redeemRule) }
                    if let address = node.address { infoSection(node, address: address) }
                    PlayStoreDaySafetyRatingEntry(ownerMemberID: node.merchantID)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.top, CYSpacing.lg).padding(.bottom, CYSpacing.xxl)
            }
        }
        .background(CYColor.bgPage)
        .cyTracksHeroScroll($heroScrolledAway, threshold: 200)
        .safeAreaInset(edge: .bottom) { bottomBar(node) }
    }
    @ViewBuilder private func hero(_ node: PlayStoreDayNode) -> some View {
        let url = node.heroImage.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" && approvedImageHosts.contains($0.host?.lowercased() ?? "") ? $0 : nil }
        ZStack {
            CYColor.bgElevated
            if let url {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { heroPlaceholder }
            } else { heroPlaceholder }
            // Vignette keeps the navigation bar and tag legible over artwork (mini-program .mp-hero__vig).
            LinearGradient(colors: [Color.black.opacity(0.34), Color.black.opacity(0), Color.black.opacity(0.30)], startPoint: .top, endPoint: .bottom)
        }
        .frame(maxWidth: .infinity).frame(height: 260).clipped()
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: CYRadius.sheet, bottomTrailingRadius: CYRadius.sheet, style: .continuous))
        .accessibilityHidden(true)
    }
    private var heroPlaceholder: some View {
        Image(systemName: "mappin.circle").accessibilityHidden(true).font(.largeTitle).foregroundStyle(CYColor.textPlaceholder)
    }
    private func header(_ node: PlayStoreDayNode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(L(tagKey(PlayStoreDayHeaderTag(node)))).cyText(.micro).foregroundStyle(CYColor.textTertiary)
                .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                .background(CYColor.bgRaised, in: Capsule()).accessibilityIdentifier("storeDayPage.tag")
            Group {
                if let name = node.name { Text(verbatim: name) } else { Text("playStoreDay.name.untitled", tableName: "PlayStoreDay") }
            }.cyText(.pageTitle).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("storeDayPage.name")
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if let open = openText {
                    metaRow(label: Text("playStoreDay.meta.open", tableName: "PlayStoreDay"), value: Text(verbatim: open)).accessibilityIdentifier("storeDayPage.meta.open")
                }
                metaRow(label: Text("playStoreDay.meta.onsite", tableName: "PlayStoreDay"), value: Text(L(crowdKey(PlayStoreDayCrowd(node)))))
                    .accessibilityIdentifier("storeDayPage.meta.onsite")
            }.padding(.top, CYSpacing.xs)
        }
    }
    /// Letter-spaced key + primary value, baseline aligned (mini-program .mp-mc).
    private func metaRow(label: Text, value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            label.cyText(.micro).foregroundStyle(CYColor.textTertiary)
            value.cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityElement(children: .combine)
    }
    private var openText: String? {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        switch model.openText(nowMinutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)) {
        case .server(let text): return text
        case .open: return L("playStoreDay.open.open")
        case .closed: return L("playStoreDay.open.closed")
        case nil: return nil
        }
    }
    private func proofSection(_ node: PlayStoreDayNode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playStoreDay.section.proof", tableName: "PlayStoreDay").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            step(1, done: node.arrived, title: L("playStoreDay.step.scan.title"), detail: L("playStoreDay.step.scan.detail"), id: "scan")
            step(2, done: node.selfReported, title: L("playStoreDay.step.photo.title"),
                 detail: node.arrived ? (node.photoDescription ?? L("playStoreDay.step.photo.default")) : L("playStoreDay.step.photo.locked"), id: "photo")
            step(3, done: node.done, title: L("playStoreDay.step.verify.title"), detail: L("playStoreDay.step.verify.detail"), id: "verify")
            if node.arrived, let rule = node.rule {
                Text(verbatim: rule).cyText(.meta).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("storeDayPage.rule")
            }
        }
    }
    /// One bordered card per step with a numbered badge; done steps use primary ink, pending ones tertiary.
    private func step(_ index: Int, done: Bool, title: String, detail: String, id: String) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(index).circle").font(.title3)
                .foregroundStyle(done ? CYColor.brand : CYColor.textTertiary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: title).cyText(.label).foregroundStyle(done ? CYColor.textPrimary : CYColor.textTertiary)
                Text(verbatim: detail).cyText(.meta).foregroundStyle(CYColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyCardSurface(variant: .surface, radius: CYRadius.md, padding: CYSpacing.md)
        .accessibilityElement(children: .combine).accessibilityIdentifier("storeDayPage.step." + id)
        .accessibilityValue(done ? Text("playStoreDay.step.done", tableName: "PlayStoreDay") : Text(verbatim: ""))
    }
    private func referenceSection(_ node: PlayStoreDayNode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playStoreDay.section.reference", tableName: "PlayStoreDay").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            // Unknown values stay an em dash (the mini-program shows 0 here; the native app must not).
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                stat(node.inStoreLoad.map(String.init) ?? "—", L("playStoreDay.stat.load"), id: "load")
                stat(node.servicePerHour.map(Self.number) ?? "—", L("playStoreDay.stat.perHour"), id: "perHour")
                stat(node.expectedWaitMinutes.map(String.init) ?? "—", L("playStoreDay.stat.wait"), id: "wait")
            }
        }
    }
    private static func number(_ value: Double) -> String { value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value) }
    private func stat(_ value: String, _ label: String, id: String) -> some View {
        VStack(spacing: CYSpacing.xs) {
            Text(verbatim: value).cyText(.sectionTitle, monospacedDigit: true).foregroundStyle(CYColor.textPrimary).cyWrapText(alignment: .center)
            Text(verbatim: label).cyText(.micro).foregroundStyle(CYColor.textTertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cyCardSurface(variant: .surface, radius: CYRadius.sm, padding: CYSpacing.md)
        .accessibilityElement(children: .combine).accessibilityIdentifier("storeDayPage.stat." + id)
    }
    private var consentSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playStoreDay.section.consent", tableName: "PlayStoreDay").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: CYSpacing.md) {
                Text(verbatim: String(format: L("playStoreDay.consent.scope"), storeName)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { confirmRevoke = true } label: {
                    Text(L(model.consentBusy ? "playStoreDay.consent.revoking" : "playStoreDay.consent.revoke")).cyText(.meta).underline()
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }.buttonStyle(.plain).foregroundStyle(CYColor.textPrimary)
                .disabled(model.consentBusy).accessibilityIdentifier("storeDayPage.consent.revoke")
            }
            .cyCardSurface(variant: .surface, radius: CYRadius.md, padding: CYSpacing.md)
        }
    }
    /// PLAYM-2: MP 本店权益 (`node.perk.name` + `redeemRule`), with the MP gift artwork.
    private func perkSection(name: String, rule: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playMerchant.perk.title").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: CYSpacing.md) {
                MPAsset.FeatureIcon.gift.resizable().scaledToFit().frame(width: 24, height: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(verbatim: name).cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary).cyWrapText()
                    if let rule { Text(verbatim: rule).cyText(.meta).foregroundStyle(CYColor.textSecondary).cyWrapText() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cyCardSurface(variant: .surface, radius: CYRadius.md, padding: CYSpacing.md)
            .accessibilityElement(children: .combine).accessibilityIdentifier("storeDayPage.perk")
        }
    }
    private func infoSection(_ node: PlayStoreDayNode, address: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playStoreDay.section.info", tableName: "PlayStoreDay").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            // Address card: pin, address, open hours, trailing navigate control (mini-program .mp-addr).
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Label {
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(verbatim: address).cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                        if let open = openText { Text(verbatim: open).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                    }
                } icon: { Image(systemName: "mappin").foregroundStyle(CYColor.textTertiary) }
                mapControl(node, label: L("playStoreDay.info.navigate"), id: "storeDayPage.info.navigate")
                if !node.hasCoordinates { PlayStoreDayGeocodeEntry(name: node.name ?? "", address: address) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyCardSurface(variant: .surface, radius: CYRadius.md, padding: CYSpacing.lg)
        }
    }
    /// Coordinates come only from the server row; the existing external-map host is reused.
    @ViewBuilder private func mapControl(_ node: PlayStoreDayNode, label: String, id: String) -> some View {
        if node.hasCoordinates, makeExternalMaps != nil {
            PlatformExternalMapHost(destination: .init(name: node.name ?? "", address: node.address, latitude: node.latitude, longitude: node.longitude),
                                    scope: mediaScope, makeModel: makeExternalMaps).accessibilityIdentifier(id)
        } else {
            Button { model.mapUnavailable() } label: { Label(label, systemImage: "mappin") }
                .buttonStyle(.cySecondary(fullWidth: false)).accessibilityIdentifier(id)
        }
    }

    // MARK: Bottom bar
    // Status line sits right above the control it governs; colour only on the dot (mini-program .mp-status).
    private func bottomBar(_ node: PlayStoreDayNode) -> some View {
        VStack(spacing: CYSpacing.sm) {
            if let degraded = model.degraded {
                Button { Task { await model.retryProofReadback() } } label: {
                    HStack(spacing: CYSpacing.sm) {
                        Circle().fill(model.receipt == .unknown ? CYColor.warningText : CYColor.textSecondary).frame(width: 8, height: 8).accessibilityHidden(true)
                        Text(verbatim: degradedText(degraded)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(minHeight: CYSpacing.minTouchTarget)
                }.buttonStyle(.plain).disabled(model.receipt != .unknown).accessibilityIdentifier("storeDayPage.degraded")
            }
            HStack(spacing: CYSpacing.md) {
                mapControl(node, label: L("playStoreDay.cta.address"), id: "storeDayPage.cta.address").fixedSize()
                primaryButton(node).frame(maxWidth: .infinity)
                // MP 更多: 扫描门店码 / 拍摄到店凭证 fall back here once 我已到店 is the first step.
                if !node.done {
                    Button { showingMore = true } label: { Image(systemName: "ellipsis").frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget) }
                        .buttonStyle(.cySecondary(fullWidth: false)).disabled(model.busy)
                        .accessibilityLabel(Text("playStoreDay.cta.more", tableName: "PlayStoreDay"))
                        .accessibilityIdentifier("storeDayPage.cta.more")
                }
            }
            .confirmationDialog(Text("playStoreDay.cta.more", tableName: "PlayStoreDay"), isPresented: $showingMore, titleVisibility: .hidden) {
                Button(L("playStoreDay.more.scan")) { model.prepareScan() }
                Button(L("playStoreDay.more.photo")) { model.preparePhoto() }
                Button(L("playStoreDay.cancel"), role: .cancel) {}
            }
            .cyModalConfirm(
                isPresented: showingArrivePurpose,
                title: L("playStoreDay.arrive.purpose"),
                cancelTitle: L("playStoreDay.cancel"),
                confirmTitle: L("playStoreDay.arrive.confirm"),
                onCancel: { showingArrivePurpose = false },
                onConfirm: { showingArrivePurpose = false; arrivePurposeShown = true; Task { await locateAndArrive() } }
            )
        }
        .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md).background(.bar)
    }
    @ViewBuilder private func primaryButton(_ node: PlayStoreDayNode) -> some View {
        switch PlayStoreDayPrimaryAction.resolve(node, receipt: model.receipt, arriveRetry: model.arriveRetry) {
        case .confirmPending: primary(L("playStoreDay.cta.confirmPending"), disabled: false) { Task { await model.retryProofReadback() } }
        case .arrive: primary(L(model.busy ? "playStoreDay.cta.arriveBusy" : "playStoreDay.cta.arrive"), disabled: model.busy) { arriveHere() }
        case .relocate: primary(L(model.busy ? "playStoreDay.cta.arriveBusy" : "playStoreDay.cta.relocate"), disabled: model.busy) { arriveHere() }
        case .scanUnlock: primary(L(model.busy ? "playStoreDay.cta.scanBusy" : "playStoreDay.cta.scanUnlock"), disabled: model.busy) { model.prepareScan() }
        case .scan: primary(L(model.busy ? "playStoreDay.cta.scanBusy" : "playStoreDay.cta.scan"), disabled: model.busy) { model.prepareScan() }
        case .photo: primary(L(model.busy ? "playStoreDay.cta.photoBusy" : "playStoreDay.cta.photo"), disabled: model.busy) { model.preparePhoto() }
        case .verify where node.redeemBlockedNotice != nil:
            // PLAYM-2: daily quota used up / not started yet: the server line, no code (MP .mp-cta__main.is-dead).
            primary(node.redeemBlockedNotice ?? "", disabled: true) {}
        case .verify: primary(L(model.consentBusy ? "playStoreDay.cta.verifyBusy" : "playStoreDay.cta.verify"), disabled: model.consentBusy) { model.openVerifyCode() }
        case .redeemed: primary(L("playStoreDay.cta.redeemed"), disabled: true) {}
        }
    }
    /// MP `arriveHere`: purpose prompt once, then one foreground GCJ-02 fix handed to /api/play/arrive.
    private func arriveHere() {
        guard !model.busy else { return }
        if arrivePurposeShown { Task { await locateAndArrive() } } else { showingArrivePurpose = true }
    }
    private func locateAndArrive() async {
        do {
            let fix = try await RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true))
            await model.arrive(longitude: fix.coordinate.longitude, latitude: fix.coordinate.latitude, accuracy: fix.accuracyMeters)
        } catch is CancellationError {
            return
        } catch {
            model.arriveLocationFailed(denied: error as? RoamActionFailure == .locationDenied)
        }
    }
    private func primary(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(verbatim: title).frame(maxWidth: .infinity) }
            .buttonStyle(.cyPrimary(fullWidth: true)).disabled(disabled).accessibilityIdentifier("storeDayPage.cta.primary")
    }

    // MARK: Sheets
    // Mini-program half-screen cards: eyebrow, question, option rows with a selected state, one pill action.
    private var gameSheet: some View {
        NavigationStack {
            Form {
                if let node = model.node {
                    Section {
                        if let question = node.question { Text(verbatim: question).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("storeDayPage.game.question") }
                    } header: {
                        if let title = node.gameTitle { Text(verbatim: title) } else { Text("playStoreDay.game.defaultTitle", tableName: "PlayStoreDay") }
                    }
                    if let result = model.game.result {
                        Section {
                            Text(verbatim: resultText(result)).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("storeDayPage.game.result")
                            Button { model.closeGame() } label: { Text(L(node.selfReported ? "playStoreDay.game.finish" : "playStoreDay.game.next")).frame(maxWidth: .infinity) }
                                .buttonStyle(.cyPrimary(fullWidth: true)).listRowBackground(Color.clear)
                                .accessibilityIdentifier("storeDayPage.game.close")
                        }
                    } else {
                        Section {
                            if let options = node.options {
                                ForEach(options) { option in
                                    Button { model.pick(option.key) } label: {
                                        HStack(spacing: CYSpacing.md) {
                                            Text(verbatim: option.key).bold()
                                            Text(verbatim: option.text).frame(maxWidth: .infinity, alignment: .leading)
                                            if model.game.choice == option.key { Image(systemName: "checkmark").foregroundStyle(CYColor.brand) }
                                        }.foregroundStyle(model.game.choice == option.key ? CYColor.textPrimary : CYColor.textSecondary)
                                        .frame(minHeight: CYSpacing.minTouchTarget)
                                    }
                                    .accessibilityLabel(Text(verbatim: String(format: L("playStoreDay.game.option"), option.key) + " " + option.text))
                                    .accessibilityAddTraits(model.game.choice == option.key ? .isSelected : [])
                                    .accessibilityIdentifier("storeDayPage.game.option." + option.key)
                                }
                            } else {
                                TextField(text: Binding(get: { model.game.answer }, set: { model.setAnswer($0) })) { Text("playStoreDay.game.placeholder", tableName: "PlayStoreDay") }
                                    .accessibilityLabel(Text("playStoreDay.game.answerLabel", tableName: "PlayStoreDay")).accessibilityIdentifier("storeDayPage.game.answer")
                            }
                            if let error = model.game.error {
                                Button { Task { await model.retryGameReadback() } } label: {
                                    Text(verbatim: gameErrorText(error) + (model.game.receipt == .unknown ? " · " + L("playStoreDay.game.recheck") : ""))
                                        .cyText(.meta)
                                        .foregroundStyle(model.game.receipt == .unknown ? CYColor.warningText : CYColor.textTertiary)
                                }.disabled(model.game.receipt != .unknown).accessibilityIdentifier("storeDayPage.game.error")
                            }
                        }
                        let locked = model.game.submitting || model.game.receipt == .unknown
                        Section {
                            Button { Task { await model.submitGame() } } label: {
                                Text(L(model.game.receipt == .unknown ? "playStoreDay.game.pending" : model.game.submitting ? "playStoreDay.game.submitting" : "playStoreDay.game.submit")).frame(maxWidth: .infinity)
                            }.buttonStyle(.cyPrimary(fullWidth: true)).listRowBackground(Color.clear)
                            .disabled(locked).accessibilityIdentifier("storeDayPage.game.submit")
                        }
                    }
                }
            }.cyGroupedSurface()
            .scrollContentBackground(.hidden).background(CYColor.sheetGlass)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { model.closeSheets() } label: { Text("playStoreDay.mask.close", tableName: "PlayStoreDay") } } }
        }
        .cyPlayerSheetGlass().presentationDragIndicator(.visible)
    }
    private var taskSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: model.node?.photoDescription ?? L("playStoreDay.step.photo.default")).cyText(.bodyMedium)
                        .foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("storeDayPage.task.requirement")
                    if let rule = model.node?.rule { Text(verbatim: rule).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                } header: { Text("playStoreDay.task.title", tableName: "PlayStoreDay") }
                Section {
                    Button { model.taskGoPhoto() } label: { Text(L(model.busy ? "playStoreDay.task.busy" : "playStoreDay.task.photo")).frame(maxWidth: .infinity) }
                        .buttonStyle(.cyPrimary(fullWidth: true)).listRowBackground(Color.clear)
                        .disabled(model.busy).accessibilityIdentifier("storeDayPage.task.photo")
                    Button { model.closeTaskCard() } label: { Text("playStoreDay.task.later", tableName: "PlayStoreDay").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget) }
                        .buttonStyle(.plain).foregroundStyle(CYColor.textTertiary).listRowBackground(Color.clear)
                        .accessibilityIdentifier("storeDayPage.task.later")
                }
            }.cyGroupedSurface()
            .scrollContentBackground(.hidden).background(CYColor.sheetGlass)
        }
        .cyPlayerSheetGlass().presentationDragIndicator(.visible)
    }

    // MARK: Copy
    private func tagKey(_ tag: PlayStoreDayHeaderTag) -> String.LocalizationValue {
        switch tag { case .redeemed: return "playStoreDay.tag.redeemed"; case .photoRecorded: return "playStoreDay.tag.photoRecorded"
        case .arrived: return "playStoreDay.tag.arrived"; case .pending: return "playStoreDay.tag.pending" }
    }
    private func crowdKey(_ crowd: PlayStoreDayCrowd) -> String.LocalizationValue {
        switch crowd { case .queue: return "playStoreDay.crowd.queue"; case .go: return "playStoreDay.crowd.go"; case .unknown: return "playStoreDay.crowd.unknown" }
    }
    private func degradedText(_ value: PlayStoreDayDegraded) -> String {
        switch value { case .quantityUnavailable: return L("playStoreDay.degraded.quantity")
        case .checking: return L("playStoreDay.degraded.checking"); case .stillUnknown: return L("playStoreDay.degraded.still") }
    }
    private func gameErrorText(_ error: PlayStoreDayGameError) -> String {
        switch error {
        case .chooseOption: return L("playStoreDay.game.error.choose")
        case .writeAnswer: return L("playStoreDay.game.error.write")
        case .wrong(let message): return message ?? L("playStoreDay.game.error.wrong")
        case .checking: return L("playStoreDay.game.error.checking")
        case .stillUnknown: return L("playStoreDay.game.error.still")
        case .notRecorded: return L("playStoreDay.game.error.notRecorded")
        }
    }
    private func resultText(_ result: PlayStoreDayAnswerResult) -> String {
        if result.confirmedByReadback { return L("playStoreDay.game.result.recorded") }
        let base = result.message ?? L(result.firstTime ? "playStoreDay.game.result.correct" : "playStoreDay.game.result.completed")
        return base + (result.experience.map { "  " + String(format: L("playStoreDay.game.result.xp"), $0) } ?? "")
    }
    private func noticeText(_ notice: PlayStoreDayNotice) -> String {
        switch notice {
        case .server(let text): return text
        case .arriveTooFar(let meters?): return String(format: L("playStoreDay.notice.arriveTooFar"), meters)
        case .arriveTooFar(nil): return L("playStoreDay.notice.notArrived")
        case .arriveAccuracyLow: return L("playStoreDay.notice.accuracyLow")
        case .arriveLocationMissing: return L("playStoreDay.notice.locationMissing")
        case .arriveScanRequired: return L("playStoreDay.notice.scanRequired")
        case .locationDenied: return L("playStoreDay.notice.locationDenied")
        case .locationFailed: return L("playStoreDay.notice.locationFailed")
        case .arrivalRecorded: return L("playStoreDay.notice.arrivalRecorded")
        case .photoRecorded: return L("playStoreDay.notice.photoRecorded")
        case .proofFailed: return L("playStoreDay.notice.proofFailed")
        case .proofLanded: return L("playStoreDay.notice.proofLanded")
        case .proofNotLanded: return L("playStoreDay.notice.proofNotLanded")
        case .arriveFirst: return L("playStoreDay.notice.arriveFirst")
        case .preferenceUnreachable: return L("playStoreDay.notice.preferenceUnreachable")
        case .handoffFailed: return L("playStoreDay.notice.handoffFailed")
        case .noCoordinates: return L("playStoreDay.notice.noCoordinates")
        case .noCode: return L("playStoreDay.notice.noCode")
        case .noPhoto: return L("playStoreDay.notice.noPhoto")
        case .deviceUnavailable: return L("playStoreDay.notice.deviceUnavailable")
        case .writesUnavailable: return L("playStoreDay.notice.writesUnavailable")
        case .needTicket: return L("playStoreDay.notice.needTicket")
        case .merchantUnconfirmed: return L("playStoreDay.notice.merchantUnconfirmed")
        case .verifyOpenFailed: return L("playStoreDay.notice.verifyOpenFailed")
        case .consentRevoked: return L("playStoreDay.notice.consentRevoked")
        case .consentDeclined: return L("playStoreDay.notice.consentDeclined")
        case .consentWriteFailed: return L("playStoreDay.notice.consentWriteFailed")
        case .consentUnconfirmed: return L("playStoreDay.notice.consentUnconfirmed")
        case .consentWritesUnavailable: return L("playStoreDay.notice.consentWritesUnavailable")
        }
    }
}

/// PLAYM-3: states keep the 到店体验 bar title; the loaded hero page shows the store name only after the hero.
private struct PlayStoreDayTitle: ViewModifier {
    let hero: Bool
    let name: String?
    let scrolledAway: Bool
    func body(content: Content) -> some View {
        if hero {
            content.cyPageTitle(verbatim: scrolledAway ? (name ?? "") : "")
        } else {
            content.navigationTitle(Text("playStoreDay.title", tableName: "PlayStoreDay")).navigationBarTitleDisplayMode(.inline)
        }
    }
}
