import SwiftUI
import PhotosUI
import UIKit

/// Host in the existing NavigationStack and retain coordinator outside this view.
@MainActor
struct MerchantOnboardingView<Session: MerchantOnboardingObserving>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.deepLinkDirtyTracker) private var dirtyTracker
    @ObservedObject var session: Session
    @StateObject private var model: MerchantOnboardingModel
    let openMerchant: (() -> Void)?
    @State private var loadedRevision: UInt64?
    @State private var baselineDraft: MerchantOnboardingDraft?
    @State private var showsDiscardModal = false
    @State private var photo: PhotosPickerItem?
    @State private var showBrandPhotos = false
    @State private var showBrandUploadConfirmation = false
    @State private var showPhotos = false
    @State private var showHours = false
    /// MC8-02-1: the 店铺地址 map picker (MP wx.chooseLocation) writes address + locationLat/locationLng.
    @State private var showsAddressPicker = false
    /// MC8-02-4: the 开场屏 shows once before step 1 of a fresh application (no /merchant/info application).
    @State private var introDismissed = false
    @State private var hoursEditor: MerchantOnboardingHoursSession?
    @State private var showUploadConfirmation = false
    @State private var showSubmitConfirmation = false
    @State private var showLicenseRemoval = false
    @State private var licenseRemoval: MerchantOnboardingModel.LicenseRemoval?
    @State private var toastMessage: String?
    init(session: Session, coordinator: MerchantOnboardingCoordinator, openMerchant: (() -> Void)? = nil) {
        self.session = session; _model = StateObject(wrappedValue: MerchantOnboardingModel(coordinator: coordinator))
        self.openMerchant = openMerchant
    }
    private var hasUnsavedChanges: Bool {
        model.isEditing && baselineDraft != nil && model.draft != baselineDraft && model.coordinator.submission != .acknowledged
    }
    var body: some View {
        ZStack {
            if !session.isConfigured || !model.coordinator.isConfigured {
                VStack(spacing: CYSpacing.md) {
                    CYEmptyState(systemImage: "network.slash", "merchant.onboarding.title")
                    Text("auth.notConfigured").cyText(.body).foregroundStyle(CYColor.textSecondary)
                }
            } else if !session.isSignedIn {
                // MC7-02-1 (apply/index.wxml:52): 登录后申请商家入驻 + 登录.
                MerchantSignInState(title: "merchant.apply.signInTitle", identifier: "merchant.onboarding.signIn")
            } else if model.identity != model.coordinator.identity {
                CYSkeleton().accessibilityLabel(Text("merchant.onboarding.checking"))
            } else {
                content
            }
            if showsDiscardModal {
                MemberSettingsSceneDiscardModal(
                    onCancel: { showsDiscardModal = false },
                    onConfirm: {
                        showsDiscardModal = false
                        baselineDraft = nil
                        dirtyTracker?.isDirty = false
                        model.leave()
                        dismiss()
                    }
                )
            }
        }
        .cyDomainScreen(.merchant)
        .cyHideTabBar(true)
        .appNavigationTitle(key: navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        // type-and-chrome §3: one exit guard (system back until there are edits, then the discard confirm).
        .cyGuardedBack(when: hasUnsavedChanges) { showsDiscardModal = true }
        .task(id: session.sessionRevision) {
            // Returning from a transient sheet may restart .task without a new account.
            guard loadedRevision != session.sessionRevision else { return }
            loadedRevision = session.sessionRevision
            photo = nil; showPhotos = false; showHours = false
            showBrandPhotos = false; showBrandUploadConfirmation = false
            showUploadConfirmation = false; showSubmitConfirmation = false
            showLicenseRemoval = false; licenseRemoval = nil; model.cancelLicenseRemoval()
            showsDiscardModal = false; baselineDraft = nil
            model.reset(); await model.load()
            if model.isEditing { baselineDraft = model.draft }
        }
        .onChange(of: model.isEditing) { _, editing in
            if editing, baselineDraft == nil { baselineDraft = model.draft }
            if !editing { baselineDraft = nil; showsDiscardModal = false }
            dirtyTracker?.isDirty = hasUnsavedChanges
        }
        .onChange(of: hasUnsavedChanges) { _, dirty in
            dirtyTracker?.isDirty = dirty
        }
        .onDisappear {
            // Presenting a child surface is not leaving the application. Keep the draft
            // and selected item through picker/sheet/confirmation transitions.
            guard !showPhotos, !showHours, !showUploadConfirmation, !showSubmitConfirmation, !showBrandPhotos, !showBrandUploadConfirmation, !showLicenseRemoval else { return }
            loadedRevision = nil; baselineDraft = nil; dirtyTracker?.isDirty = false; model.leave(); photo = nil
        }
        .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: photo) { _, value in
            guard let value else { return }
            Task { await model.select(value); photo = nil }
        }
        .sheet(isPresented: $showHours) {
            if let hoursEditor {
                MerchantOnboardingHoursEditor(editor: hoursEditor) { hoursEditor.cancel(); showHours = false }
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.merchant)
            }
        }
        .onChange(of: showHours) { _, shown in if !shown { hoursEditor?.cancel(); hoursEditor = nil } }
        .cyModalConfirm(
            isPresented: showUploadConfirmation,
            title: appLocalized("merchant.onboarding.uploadConfirm.title", locale: locale),
            message: appLocalized("merchant.onboarding.uploadConfirm.message", locale: locale),
            cancelTitle: appLocalized("action.cancel", locale: locale),
            confirmTitle: appLocalized("merchant.onboarding.uploadConfirm.action", locale: locale),
            onCancel: { showUploadConfirmation = false },
            onConfirm: {
                showUploadConfirmation = false
                Task { await model.uploadSelected() }
            }
        )
        .cyModalConfirm(
            isPresented: showLicenseRemoval && licenseRemoval != nil,
            title: appLocalized("merchant.onboardingLicenseRemoval.title", locale: locale),
            message: appLocalized("merchant.onboardingLicenseRemoval.message", locale: locale),
            cancelTitle: appLocalized("action.cancel", locale: locale),
            confirmTitle: appLocalized("merchant.onboardingLicenseRemoval.action", locale: locale),
            isDestructive: true,
            onCancel: {
                showLicenseRemoval = false
                if let request = licenseRemoval { model.cancelLicenseRemoval(request) }
                licenseRemoval = nil
            },
            onConfirm: {
                showLicenseRemoval = false
                if let request = licenseRemoval { model.removeLicense(request) }
                licenseRemoval = nil
            }
        )
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.cancelLicenseRemoval(); showLicenseRemoval = false; licenseRemoval = nil }
        }
        .cyModalConfirm(
            isPresented: showSubmitConfirmation,
            title: appLocalized("merchant.onboarding.submitConfirm.title", locale: locale),
            message: appLocalized("merchant.onboarding.submitConfirm.message", locale: locale),
            cancelTitle: appLocalized("action.cancel", locale: locale),
            confirmTitle: appLocalized("merchant.onboarding.submitConfirm.action", locale: locale),
            onCancel: {
                showSubmitConfirmation = false
                model.cancelConfirmation()
            },
            onConfirm: {
                showSubmitConfirmation = false
                model.submitConfirmed()
            }
        )
        .onChange(of: model.coordinator.submission) { _, submission in
            switch submission {
            case .acknowledged:
                toastMessage = MerchantCloseCopy.text("已提交入驻资料", "Onboarding submitted", locale)
            case .outcomeUnknown:
                toastMessage = MerchantCloseCopy.text("提交结果待确认，请刷新核对", "Submission status unknown, please check again", locale)
            case .rejected(let failure):
                let detail = failure.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                toastMessage = detail.isEmpty
                    ? MerchantCloseCopy.text("提交失败，请重试", "Submission failed, please retry", locale)
                    : detail
            default:
                break
            }
        }
        .cyToast(verbatimMessage: $toastMessage)
        .onChange(of: showSubmitConfirmation) { _, shown in
            if !shown, model.confirmation != nil, !model.isBusy { model.cancelConfirmation() }
        }
    }
    /// MP apply/index.wxml cy-nav-bar title: 审核状态 in status mode, 提交成功 after a submit, else the 商家入驻 bar.
    private var navigationTitleKey: String {
        if model.coordinator.submission == .acknowledged { return "merchant.onboarding.submittedTitle" }
        if case .loaded(let snapshot) = model.coordinator.loadState, case .application(let application) = snapshot,
           !model.isEditing || !application.canReapply {
            return "merchant.onboarding.statusTitle"
        }
        return "merchant.onboarding.title"
    }
    @ViewBuilder private var content: some View {
        switch model.coordinator.loadState {
        case .idle, .loading:
            CYSkeleton()
                .accessibilityIdentifier("merchant.onboarding.loading")
                .accessibilityLabel(Text("merchant.onboarding.checking"))
        case .unavailable:
            Form {
                onboardingHero
                submissionSection
                Section {
                    CYEmptyState(systemImage: "exclamationmark.triangle", "merchant.onboarding.stateUnavailable")
                    refreshButton
                }
            }
        case .loaded(let snapshot):
            if model.coordinator.submission.isLocked && model.coordinator.submission != .awaitingConfirmation {
                Form {
                    onboardingHero
                    submissionSection
                    if case .application(let application) = snapshot { statusSection(application) }
                    else { Section { CYEmptyState("merchant.onboarding.noApplicationReadback") } }
                    Section { refreshButton }
                }
            } else if case .application(let application) = snapshot, (!model.isEditing || !application.canReapply) {
                Form {
                    onboardingHero
                    submissionSection
                    statusSection(application)
                    Section {
                        if application.canReapply {
                            CYPillButton("merchant.onboarding.reapply") { model.reapply(application) }
                                .accessibilityIdentifier("merchant.onboarding.reapply")
                        }
                        if application.status == 1 && application.accountStatus == 1, let openMerchant {
                            CYPillButton("merchant.onboarding.openMerchant", style: application.canReapply ? .secondary : .primary, action: openMerchant)
                        }
                        refreshButton
                    }
                }
            } else if snapshot == .none, !introDismissed, model.step == 1, !model.isBusy {
                introScreen
            } else { applicationForm }
        }
    }
    /// MC8-02-4 (apply/index.wxml:22-31): 把你的店放进玩家的路线里 + 开始入驻. 认领已有门店 is not offered until the
    /// claim flow exists (MC8-02-3, for Cursor), so there is no dead link.
    private var introScreen: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xl) {
            Spacer(minLength: 0)
            Text("merchantR8.onboarding.introTitle")
                .cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            CYPillButton("merchantR8.onboarding.start") { introDismissed = true }
                .accessibilityIdentifier("merchant.onboarding.intro.start")
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.bottom, CYSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityIdentifier("merchant.onboarding.intro")
    }
    private var onboardingHero: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                // Parity apply P1: one title. The bar keeps 商家入驻申请; the form shows only the step headline.
                Text(heroSubtitle)
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                // Figma 182:7693: a five-segment bar; the current and earlier segments are filled.
                MerchantOnboardingProgressBar(step: model.step, count: MerchantOnboardingSteps.count)
            }
            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
        }
    }
    private var heroSubtitle: LocalizedStringKey {
        switch model.step {
        case 1: return "merchant.onboarding.step.1"
        case 2: return "merchant.onboarding.step.2"
        case 3: return "merchant.onboarding.step.3"
        case MerchantOnboardingSteps.identity: return "merchant.onboarding.step.identity"
        default: return "merchant.onboarding.step.review"
        }
    }
    private var applicationForm: some View {
        Form {
            onboardingHero
            submissionSection
            switch model.step {
            case 1: basicSection
            case 2: businessSection
            case 3: licenseSection
            case MerchantOnboardingSteps.identity: MerchantOnboardingIdentitySection(model: model)
            default: reviewSection
            }
            // The identity step shows its field errors under the fields; the page-level line would repeat them.
            if let error = model.errorKey, !(model.step == MerchantOnboardingSteps.identity && error.hasPrefix("merchant.onboarding.identity.")) {
                Section { Text(LocalizedStringKey(error)).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("merchant.onboarding.error") }
            }
            if model.isBusy {
                Section {
                    CYSkeleton().accessibilityLabel(Text("merchant.onboarding.working"))
                }
            }
        }
        .disabled(model.isBusy)
        .scrollDismissesKeyboard(.interactively)
        // Source wizard: one pinned primary action, 继续 on steps 1-3 and 提交申请 on step 4.
        .questifyBottomAction {
            Group {
                if model.step < MerchantOnboardingSteps.review {
                    // Figma 182:7628: on the identity step 继续 waits for the consent box, with the reason above it.
                    let needsConsent = model.step == MerchantOnboardingSteps.identity && !model.draft.identityConsent
                    VStack(spacing: CYSpacing.sm) {
                        if needsConsent {
                            Text("merchant.onboarding.identity.required.consent")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("merchant.onboarding.identity.consentHint")
                        }
                        // Code r3: 上一步 is the secondary beside 下一步 in the one bottom bar (not alone in a white card).
                        onboardingButtonRow {
                            CYPillButton("merchant.onboarding.next") { model.next() }
                                .disabled(needsConsent)
                                .accessibilityHint(needsConsent ? Text("merchant.onboarding.identity.required.consent") : Text(verbatim: ""))
                                .accessibilityIdentifier("merchant.onboarding.next")
                        }
                    }
                } else {
                    // HANDOFF-R1 MR-01 / MR-11: the primary stays enabled and jumps to what is missing.
                    VStack(spacing: CYSpacing.sm) {
                        Text("r1merchant.onboarding.consent", tableName: "DesignR1Merchant")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        onboardingButtonRow {
                        CYPillButton("r1merchant.onboarding.submit", tableName: "DesignR1Merchant") {
                            if model.draft.blocker() != nil || model.draft.identityBlocker() != nil || model.draft.consentBlocker() != nil {
                                let step = firstIncompleteStep
                                model.step = step
                                model.errorKey = model.draft.blocker(step: step)
                            } else if model.coordinator.identityGate != .registered && !model.draft.canRegisterIdentity {
                                model.errorKey = "merchant.onboarding.identity.required"
                            } else {
                                model.prepare(); showSubmitConfirmation = model.confirmation != nil
                            }
                        }
                        .accessibilityIdentifier("merchant.onboarding.submit")
                        }
                    }
                }
            }
            .disabled(model.isBusy || model.coordinator.submission.isLocked)
        }
    }
    /// 上一步 (secondary, from step 2) and the step's primary side by side; stacked at accessibility sizes.
    @ViewBuilder private func onboardingButtonRow<Primary: View>(@ViewBuilder primary: () -> Primary) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        layout {
            if model.step > 1 {
                CYPillButton("merchant.onboarding.previous", style: .secondary) { model.step -= 1; model.errorKey = nil }
                    .disabled(model.isBusy || model.coordinator.submission.isLocked)
                    .accessibilityIdentifier("merchant.onboarding.previous")
            }
            primary()
        }
    }
    private var basicSection: some View {
        Section("merchant.onboarding.step.1") {
            TextField("merchant.onboarding.name", text: $model.draft.name).accessibilityIdentifier("merchant.onboarding.name")
            // Parity apply P0 (M-16): 行业类型 picked from the MERCHANT catalog, 1–5, sent as categoryIds.
            MerchantOnboardingCategoryRow(model: model)
            TextField("merchant.onboarding.phone", text: $model.draft.phone).keyboardType(.phonePad)
                .accessibilityIdentifier("merchant.onboarding.phone")
        }
    }
    private var businessSection: some View {
        Section("merchant.onboarding.step.2") {
            // MC8-02-1 (apply/index.js:509-540, index.wxml:140-142): the address is picked on the map, not typed.
            Button { showsAddressPicker = true } label: {
                LabeledContent("merchant.onboarding.address") {
                    if model.draft.address.isEmpty { Text("merchantR8.onboarding.pickAddress").foregroundStyle(CYColor.textTertiary) }
                    else { Text(verbatim: model.draft.address).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.trailing) }
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
            }
            .disabled(model.isBusy || model.coordinator.submission.isLocked)
            .accessibilityIdentifier("merchant.onboarding.address")
            .sheet(isPresented: $showsAddressPicker) {
                PublishingPlacePicker(provider: PublishingMapKitAdapter()) { place in
                    model.draft.address = place.address.isEmpty ? place.name : place.address
                    model.draft.locationLat = place.latitude
                    model.draft.locationLng = place.longitude
                    showsAddressPicker = false
                }
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            CYListRow("merchant.onboarding.hours", trailing: .value(model.draft.businessTime.isEmpty ? "—" : displayHours(model.draft.businessTime)))
            Button("merchant.onboarding.chooseHours") {
                hoursEditor = MerchantOnboardingHoursSession(model: model)
                showHours = hoursEditor != nil
            }
                .accessibilityIdentifier("merchant.onboarding.hours")
            TextField("merchant.onboarding.description", text: $model.draft.description, axis: .vertical).lineLimit(3...8)
                .onChange(of: model.draft.description) { old, new in
                    // Only user edits are clamped; a loaded reapplication is never rewritten on display.
                    if new.count > MerchantOnboardingDescriptionLimit.maximum, old.count <= MerchantOnboardingDescriptionLimit.maximum {
                        model.draft.description = MerchantOnboardingDescriptionLimit.clamped(new)
                    }
                }
            Text("merchant.onboarding.descriptionCount \(model.draft.description.count) \(MerchantOnboardingDescriptionLimit.maximum)")
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .accessibilityIdentifier("merchant.onboarding.descriptionCount")
        }
    }
    private var licenseSection: some View {
        Group {
            identitySection
            Section("merchant.onboarding.step.3") {
                if model.draft.license != nil {
                    Label("merchant.onboarding.licenseUploaded", systemImage: "checkmark.circle")
                        .accessibilityIdentifier("merchant.onboarding.licenseUploaded")
                    Button("merchant.onboardingLicenseRemoval.action", role: .destructive) {
                        licenseRemoval = model.prepareLicenseRemoval(); showLicenseRemoval = licenseRemoval != nil
                    }.disabled(!model.canRemoveLicense)
                        .accessibilityIdentifier("merchant.onboarding.license.remove")
                }
                if let selectedImage = model.selectedImage {
                    if let preview = UIImage(data: selectedImage.data) {
                        Image(uiImage: preview).resizable().scaledToFit().frame(maxHeight: 200)
                            .accessibilityLabel("merchant.onboarding.licensePreview")
                    }
                    Text("merchant.onboarding.licenseSelected").accessibilityIdentifier("merchant.onboarding.licenseSelected")
                    Button("merchant.onboarding.uploadLicense") { showUploadConfirmation = true }
                    Button("merchant.onboarding.discardPhoto", role: .destructive) { model.selectedImage = nil }
                }
                Button("merchant.onboarding.chooseLicense") { showPhotos = true }
                    .accessibilityIdentifier("merchant.onboarding.chooseLicense")
            }
            MerchantOnboardingBrandImagesEditor(model: model, pickerPresented: $showBrandPhotos,
                uploadConfirmationPresented: $showBrandUploadConfirmation)
        }
        .task { if model.coordinator.identityGate == .unchecked { await model.checkIdentity() } }
    }
    private var reviewSection: some View {
        Group {
            // HANDOFF-R1 MR-01: step 4 is a review — every answer as a row, 修改 per group, one consent
            // sentence above the pinned 提交入驻申请.
            Section {
                reviewRow("merchant.onboarding.name", model.draft.name)
                reviewRow("merchant.onboarding.category", model.draft.categoryNames.isEmpty
                          ? (model.draft.categoryIDs.isEmpty ? "" : model.draft.categoryIDs.map { "#\($0)" }.joined(separator: " · "))
                          : model.draft.categoryNames.joined(separator: " · "))
                reviewRow("merchant.onboarding.phone", model.draft.phone)
            } header: { reviewHeader(group: 1) }
            Section {
                reviewRow("merchant.onboarding.address", model.draft.address)
                reviewRow("merchant.onboarding.hours", displayHours(model.draft.businessTime))
                reviewRow("merchant.onboarding.description", model.draft.description)
            } header: { reviewHeader(group: 2) }
            Section {
                if model.draft.license != nil {
                    Label("merchant.onboarding.licenseUploaded", systemImage: "doc.badge.checkmark")
                } else {
                    Label { Text(verbatim: merchantR1("onboarding.review.licenseMissing", locale)) } icon: { Image(systemName: "doc.badge.ellipsis") }
                        .foregroundStyle(CYColor.dangerText)
                }
            } header: { reviewHeader(group: 3) }
            // Owner 2026-11-16: the identity group, with the ID number masked (110***********1234).
            Section {
                reviewRow("merchant.onboarding.identity.realName", model.draft.realName)
                reviewRow("merchant.onboarding.identity.idCard", model.draft.idCardNumber.masked)
            } header: { reviewHeader(group: MerchantOnboardingSteps.identity) }
            if model.draft.brandImages?.urls.isEmpty == false {
                Section("merchant.onboardingBrand.title") { MerchantOnboardingBrandImageRows(images: model.draft.brandImages) }
            }
            identitySection
        }
        .task { if model.coordinator.identityGate == .unchecked { await model.checkIdentity() } }
    }
    /// Translate only the exact source-generated weekday grammar; preserve unknown server text.
    private func displayHours(_ value: String) -> String {
        let parts = value.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return value }
        if parts[0] == "周一至周日" { return appLocalized("merchant.onboarding.everyDay",locale:locale) + " " + String(parts[1]) }
        guard parts[0].hasPrefix("周") else { return value }
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        let names = [appLocalized("merchant.onboarding.day.0",locale:locale), appLocalized("merchant.onboarding.day.1",locale:locale),
                     appLocalized("merchant.onboarding.day.2",locale:locale), appLocalized("merchant.onboarding.day.3",locale:locale),
                     appLocalized("merchant.onboarding.day.4",locale:locale), appLocalized("merchant.onboarding.day.5",locale:locale),
                     appLocalized("merchant.onboarding.day.6",locale:locale)]
        let days = parts[0].dropFirst().split(separator: "、")
        let indexes = days.compactMap { labels.firstIndex(of: String($0)) }
        guard !days.isEmpty, indexes.count == days.count else { return value }
        return indexes.map { names[$0] }.joined(separator: ", ") + " " + String(parts[1])
    }
    private func reviewHeader(group: Int) -> some View {
        MerchantR1SectionHeader(title: merchantR1("onboarding.review.group\(group)", locale),
                                actionTitle: merchantR1("onboarding.review.edit", locale)) {
            model.errorKey = nil
            model.step = group
        }
        .accessibilityIdentifier("merchant.onboarding.review.edit.\(group)")
    }
    /// The first step with a missing answer; 4 when the draft is complete.
    private var firstIncompleteStep: Int {
        (1...MerchantOnboardingSteps.identity).first { model.draft.blocker(step: $0) != nil } ?? MerchantOnboardingSteps.review
    }
    private func reviewRow(_ key: String, _ value: String) -> some View {
        // polish-d-r1: plain rows inside the grouped section — one card with dividers, not a card per row.
        CYListRow(LocalizedStringKey(key), trailing: .value(value.isEmpty ? "—" : value))
    }
    private var identitySection: some View {
        Section("merchant.onboarding.identity.title") {
            switch model.coordinator.identityGate {
            case .registered: CYStatusChip("merchant.onboarding.identity.registered", tone: .success, systemImage: "checkmark")
            case .checking: CYSkeleton().accessibilityLabel(Text("merchant.onboarding.identity.checking"))
            case .required:
                // Parity apply P0: not a blocker any more; the identity entered in step 4 is registered on submit.
                Text("merchant.onboarding.identity.registerOnSubmit").accessibilityIdentifier("merchant.onboarding.identityGate")
                Text("merchant.onboarding.identity.regionalGate").font(.footnote).foregroundStyle(.secondary)
                Button("merchant.onboarding.identity.recheck") { Task { await model.checkIdentity() } }
            case .unchecked, .unavailable:
                Text("merchant.onboarding.identity.unavailable")
                Button("merchant.onboarding.identity.recheck") { Task { await model.checkIdentity() } }
            }
        }
    }
    /// Parity apply P1: source index.wxml:246-249 offers 重新提交 in place; it re-opens the same reviewed confirm.
    private var resubmitButton: some View {
        CYPillButton("merchant.onboarding.resubmit", style: .secondary) { model.prepare() }
            .disabled(model.isBusy)
            .accessibilityIdentifier("merchant.onboarding.resubmit")
    }
    @ViewBuilder private var submissionSection: some View {
        switch model.coordinator.submission {
        case .acknowledged:
            // MC7-02-5 (apply/index.wxml:253-300): 你的申请已提交, the receipt, the four-step timeline and 返回首页.
            Section {
                VStack(spacing: CYSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.largeTitle))
                        .foregroundStyle(CYColor.successText)
                        .accessibilityHidden(true)
                    Text("merchant.apply.submitted.title")
                        .cyText(.sectionTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CYSpacing.sm)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchant.onboarding.submitted")
                LabeledContent("merchant.onboarding.name", value: model.draft.name.isEmpty ? "—" : model.draft.name)
                LabeledContent("merchant.onboarding.phone", value: model.draft.phone.isEmpty ? "—" : model.draft.phone)
            }
            MerchantApplyTimelineSection(steps: MerchantApplyTimelineStep.submitted)
            Section {
                Button("merchant.apply.submitted.home") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("merchant.onboarding.submitted.home")
            }
        case .outcomeUnknown:
            Section { Text("merchant.onboarding.outcomeUnknown").accessibilityIdentifier("merchant.onboarding.outcomeUnknown") }
        case .rejected(let failure):
            Section {
                Text("merchant.onboarding.rejectedByServer")
                if let message = failure.message, !message.isEmpty { Text(message) }
                resubmitButton
            }
        case .notSent: Section { Text("merchant.onboarding.notSent"); resubmitButton }
        case .checking, .submitting:
            Section { CYSkeleton().accessibilityLabel(Text("merchant.onboarding.working")) }
        default: EmptyView()
        }
    }
    @ViewBuilder private func statusSection(_ application: MerchantOnboardingApplication) -> some View {
        Section("merchant.onboarding.serverStatus") {
            CYStatusChip(LocalizedStringKey(application.statusKey), tone: application.accountStatus == 2 || application.status == 2 ? .danger : application.status == 1 ? .success : .warning)
                .accessibilityIdentifier("merchant.onboarding.status")
            Text(LocalizedStringKey(application.explanationKey))
            if let reason = application.displayedReason { Text(reason) }
            if !application.name.isEmpty { LabeledContent("merchant.onboarding.name", value: application.name) }
            if !application.createTime.isEmpty { LabeledContent("merchant.onboarding.submittedAt", value: application.createTime) }
            // MC7-02-5 / MC7-02-6: 联系电话 and a tappable 店铺地址 (opens Maps), as the MP status card shows.
            LabeledContent("merchant.onboarding.phone", value: application.phone.isEmpty ? "—" : application.phone)
            MerchantApplyAddressRow(name: application.name, address: application.address)
        }
        MerchantApplyTimelineSection(steps: MerchantApplyTimelineStep.status(application))
    }
    private var refreshButton: some View {
        CYPillButton("merchant.onboarding.checkAgain", style: .tertiary) { Task { await model.load() } }
            .disabled(model.isBusy).accessibilityIdentifier("merchant.onboarding.refresh")
    }
}

// MARK: - Identity step (owner 2026-11-16; verify-r1 Q2 changed)

/// 真实姓名 and 身份证号. The ID field takes 18 characters (digits, last may be X), has no autofill or suggestions, and
/// once you leave it shows only the masked form (110***********1234); tap to edit. Errors sit under the field they
/// belong to. The value is never logged (see `MerchantIdentityNumber`) and is redacted in system snapshots.
struct MerchantOnboardingIdentitySection: View {
    @ObservedObject var model: MerchantOnboardingModel
    private enum Field: Hashable { case name, idCard }
    @FocusState private var focus: Field?
    @State private var touchedName = false
    @State private var touchedID = false
    @Environment(\.cyPalette) private var palette

    // Each field reports its own problem (the draft's identityBlocker() stops at the first one).
    private var nameError: String? {
        guard touchedName || isIdentityError else { return nil }
        var probe = model.draft
        probe.idCardNumber = MerchantIdentityNumber("11010519491231002X")
        return probe.identityBlocker()
    }
    private var idError: String? {
        guard touchedID || isIdentityError else { return nil }
        var probe = model.draft
        probe.realName = "姓名"
        return probe.identityBlocker()
    }
    /// The wizard's 继续 / 提交 tapped with a problem here: show both fields' errors at once.
    private var isIdentityError: Bool { model.errorKey?.hasPrefix("merchant.onboarding.identity.") == true && model.errorKey != "merchant.onboarding.identity.required" }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                TextField("merchant.onboarding.identity.realName", text: $model.draft.realName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .name)
                    .onSubmit { touchedName = true; focus = .idCard }
                    .accessibilityIdentifier("merchant.onboarding.identity.realName")
                fieldError(nameError, id: "realName")
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                // While masked, the raw field is not in the view tree at all, so neither VoiceOver nor UI tooling can
                // read the number; tapping the masked row brings the field back and focuses it.
                ZStack(alignment: .leading) {
                    if showsMasked {
                        Button { editingID = true } label: {
                            HStack {
                                Text(verbatim: model.draft.idCardNumber.masked)
                                    .cyText(.numericBody)
                                    .foregroundStyle(palette.textPrimary)
                                Spacer(minLength: CYSpacing.sm)
                                Image(systemName: "pencil").foregroundStyle(palette.textSecondary).accessibilityHidden(true)
                            }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("merchant.onboarding.identity.idCard"))
                        .accessibilityValue(Text("merchant.onboarding.identity.idCardEntered"))
                        .accessibilityHint(Text("merchant.onboarding.identity.idCardEditHint"))
                        .accessibilityIdentifier("merchant.onboarding.identity.idCardMasked")
                    } else {
                        TextField("merchant.onboarding.identity.idCard", text: idBinding)
                            .textContentType(nil)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .cyText(.numericBody)
                            .focused($focus, equals: .idCard)
                            .onAppear { if editingID { focus = .idCard } }
                            .accessibilityIdentifier("merchant.onboarding.identity.idCard")
                    }
                }
                .privacySensitive()
                fieldError(idError, id: "idCard")
            }
        } header: {
            Text("merchant.onboarding.identity.title")
        } footer: {
            Label { Text("merchant.onboarding.identity.privacy") } icon: { Image(systemName: "lock.fill") }
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .accessibilityIdentifier("merchant.onboarding.identity.privacy")
        }
        .onChange(of: focus) { old, _ in
            if old == .name { touchedName = true }
            if old == .idCard { touchedID = true; editingID = false }
        }
        consentSection
    }

    // MARK: PIPL consent (Figma `182:7628` unchecked, `406:9580` checked)

    @Environment(\.locale) private var locale
    @State private var showsRule = false
    private static let ruleURL = URL(string: "questify-legal://merchant-identity-rule")!

    /// 我已阅读并同意《个人信息处理规则》: the rule is a link; tapping anywhere else on the row toggles the box.
    /// Starts unchecked; 继续 stays disabled with the hint 勾选同意后才能继续 until it is checked.
    private var consentText: AttributedString {
        var prefix = AttributedString(appLocalized("merchant.onboarding.identity.consent.prefix", locale: locale))
        prefix.foregroundColor = palette.textSecondary
        var rule = AttributedString(appLocalized("merchant.onboarding.identity.consent.rule", locale: locale))
        rule.link = Self.ruleURL
        rule.foregroundColor = palette.info
        rule.underlineStyle = .single
        return prefix + rule
    }

    private var consentSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Image(systemName: model.draft.identityConsent ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(model.draft.identityConsent ? palette.textPrimary : palette.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(consentText)
                    .cyText(.meta)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
            .onTapGesture { model.draft.identityConsent.toggle() }
            .sensoryFeedback(.selection, trigger: model.draft.identityConsent)
            .environment(\.openURL, OpenURLAction { url in
                guard url == Self.ruleURL else { return .systemAction }
                showsRule = true
                return .handled
            })
            .accessibilityRepresentation {
                Toggle(isOn: $model.draft.identityConsent) { Text("merchant.onboarding.identity.consent.label") }
            }
            .accessibilityAction(named: Text("merchant.onboarding.identity.consent.openRule")) { showsRule = true }
            .accessibilityIdentifier("merchant.onboarding.identity.consent")
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.xs, bottom: 0, trailing: CYSpacing.xs))
        }
        .sheet(isPresented: $showsRule) {
            Group {
                NavigationStack {
                    SettingsLegalDocumentView(type: .privacyPolicy, market: RegionalLaunchConfiguration.market,
                                              reader: SettingsBundledLegalReader(privacyPolicyApproved:
                                                RegionalLaunchConfiguration.composition.reviewed?.legalCatalogApproved == true))
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showsRule = false } label: { Image(systemName: "xmark") }
                                    .accessibilityLabel(Text("action.close"))
                            }
                        }
                }
                .presentationDragIndicator(.visible)
            }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }

    @State private var editingID = false
    private var showsMasked: Bool { !editingID && focus != .idCard && !model.draft.idCardNumber.normalized.isEmpty }

    /// Digits and X only, at most 18; lower-case x becomes X.
    private var idBinding: Binding<String> {
        Binding(get: { model.draft.idCardNumber.rawValue }, set: { new in
            let cleaned = String(new.uppercased().filter { ($0.isASCII && $0.isNumber) || $0 == "X" }.prefix(18))
            if cleaned != model.draft.idCardNumber.rawValue { model.draft.idCardNumber = MerchantIdentityNumber(cleaned) }
        })
    }

    @ViewBuilder private func fieldError(_ key: String?, id: String) -> some View {
        if let key {
            Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle.fill") }
                .cyText(.meta)
                .foregroundStyle(CYColor.dangerText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("merchant.onboarding.identity.error.\(id)")
        }
    }
}

/// Figma 182:7693: N equal segments, filled up to the current step. Announced as "第 4 步，共 5 步".
struct MerchantOnboardingProgressBar: View {
    let step: Int
    let count: Int
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            ForEach(1...max(count, 1), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= step ? palette.textPrimary : palette.borderSubtle)
                    .frame(height: 4)
            }
        }
        .animation(CYMotion.resolve(.easeOut(duration: 0.22), reduceMotion: reduceMotion), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("merchant.onboarding.progress \(min(step, count)) \(count)"))
        .accessibilityIdentifier("merchant.onboarding.progress")
    }
}
