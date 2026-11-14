import SwiftUI
import PhotosUI
import UIKit

/// Host in the existing NavigationStack and retain coordinator outside this view.
@MainActor
struct MerchantOnboardingView<Session: MerchantOnboardingObserving>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
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
                    Text("auth.notConfigured").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                }
            } else if !session.isSignedIn {
                VStack(spacing: CYSpacing.md) {
                    CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "merchant.onboarding.title")
                    Text("merchant.signIn").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                }
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
        .appNavigationTitle("merchant.onboarding.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsDiscardModal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                            Text(verbatim: MemberPopupCopy.text("返回", "Back", locale: locale))
                        }
                    }
                    .accessibilityIdentifier("merchant.onboarding.back")
                }
            }
        }
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
                toastMessage = MerchantCloseCopy.text("已提交入驻资料", "Onboarding submitted", locale)
            }
        )
        .cyToast(verbatimMessage: $toastMessage)
        .onChange(of: showSubmitConfirmation) { _, shown in
            if !shown, model.confirmation != nil, !model.isBusy { model.cancelConfirmation() }
        }
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
            } else { applicationForm }
        }
    }
    private var onboardingHero: some View {
        Section {
            CYHeroHeader("merchant.onboarding.title", subtitle: heroSubtitle)
                .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                .listRowBackground(Color.clear)
        }
    }
    private var heroSubtitle: LocalizedStringKey {
        switch model.step {
        case 1: return "merchant.onboarding.step.1"
        case 2: return "merchant.onboarding.step.2"
        case 3: return "merchant.onboarding.step.3"
        default: return "merchant.onboarding.step.4"
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
            default: reviewSection
            }
            if let error = model.errorKey {
                Section { Text(LocalizedStringKey(error)).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("merchant.onboarding.error") }
            }
            if model.isBusy || model.step > 1 {
                Section {
                    if model.isBusy {
                        CYSkeleton().accessibilityLabel(Text("merchant.onboarding.working"))
                    }
                    if model.step > 1 {
                        CYPillButton("merchant.onboarding.previous", style: .secondary) { model.step -= 1; model.errorKey = nil }
                            .disabled(model.isBusy || model.coordinator.submission.isLocked)
                    }
                }
            }
        }
        .disabled(model.isBusy)
        .scrollDismissesKeyboard(.interactively)
        // Source wizard: one pinned primary action, 继续 on steps 1-3 and 提交申请 on step 4.
        .questifyBottomAction {
            Group {
                if model.step < 4 {
                    CYPillButton("merchant.onboarding.next") { model.next() }
                        .accessibilityIdentifier("merchant.onboarding.next")
                } else {
                    CYPillButton("merchant.onboarding.reviewSubmit") {
                        model.prepare(); showSubmitConfirmation = model.confirmation != nil
                    }
                    .disabled(model.coordinator.identityGate != .registered || model.draft.blocker() != nil)
                    .accessibilityIdentifier("merchant.onboarding.submit")
                }
            }
            .disabled(model.isBusy || model.coordinator.submission.isLocked)
        }
    }
    private var basicSection: some View {
        Section("merchant.onboarding.step.1") {
            TextField("merchant.onboarding.name", text: $model.draft.name).accessibilityIdentifier("merchant.onboarding.name")
            TextField("merchant.onboarding.preference", text: $model.draft.preference)
            TextField("merchant.onboarding.phone", text: $model.draft.phone).keyboardType(.phonePad)
                .accessibilityIdentifier("merchant.onboarding.phone")
        }
    }
    private var businessSection: some View {
        Section("merchant.onboarding.step.2") {
            TextField("merchant.onboarding.address", text: $model.draft.address, axis: .vertical)
                .accessibilityIdentifier("merchant.onboarding.address")
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
                    .disabled(model.coordinator.identityGate != .registered)
                    .accessibilityIdentifier("merchant.onboarding.chooseLicense")
            }
            MerchantOnboardingBrandImagesEditor(model: model, pickerPresented: $showBrandPhotos,
                uploadConfirmationPresented: $showBrandUploadConfirmation)
        }
        .task { if model.coordinator.identityGate == .unchecked { await model.checkIdentity() } }
    }
    private var reviewSection: some View {
        Group {
            Section("merchant.onboarding.step.4") {
                reviewRow("merchant.onboarding.name", model.draft.name)
                reviewRow("merchant.onboarding.preference", model.draft.preference)
                reviewRow("merchant.onboarding.phone", model.draft.phone)
                reviewRow("merchant.onboarding.address", model.draft.address)
                reviewRow("merchant.onboarding.hours", displayHours(model.draft.businessTime))
                reviewRow("merchant.onboarding.description", model.draft.description)
                Label("merchant.onboarding.licenseUploaded", systemImage: "doc.badge.checkmark")
            }
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
    private func reviewRow(_ key: String, _ value: String) -> some View {
        CYListRow(LocalizedStringKey(key), trailing: .value(value.isEmpty ? "—" : value), card: true)
    }
    private var identitySection: some View {
        Section("merchant.onboarding.identity.title") {
            switch model.coordinator.identityGate {
            case .registered: CYStatusChip("merchant.onboarding.identity.registered", tone: .success, systemImage: "checkmark")
            case .checking: CYSkeleton().accessibilityLabel(Text("merchant.onboarding.identity.checking"))
            case .required:
                Text("merchant.onboarding.identity.required").accessibilityIdentifier("merchant.onboarding.identityGate")
                Text("merchant.onboarding.identity.regionalGate").font(.footnote).foregroundStyle(.secondary)
                Button("merchant.onboarding.identity.recheck") { Task { await model.checkIdentity() } }
            case .unchecked, .unavailable:
                Text("merchant.onboarding.identity.unavailable")
                Button("merchant.onboarding.identity.recheck") { Task { await model.checkIdentity() } }
            }
        }
    }
    @ViewBuilder private var submissionSection: some View {
        switch model.coordinator.submission {
        case .acknowledged:
            Section { Text("merchant.onboarding.submitted").accessibilityIdentifier("merchant.onboarding.submitted") }
        case .outcomeUnknown:
            Section { Text("merchant.onboarding.outcomeUnknown").accessibilityIdentifier("merchant.onboarding.outcomeUnknown") }
        case .rejected(let failure):
            Section {
                Text("merchant.onboarding.rejectedByServer")
                if let message = failure.message, !message.isEmpty { Text(message) }
            }
        case .notSent: Section { Text("merchant.onboarding.notSent") }
        case .checking, .submitting:
            Section { CYSkeleton().accessibilityLabel(Text("merchant.onboarding.working")) }
        default: EmptyView()
        }
    }
    private func statusSection(_ application: MerchantOnboardingApplication) -> some View {
        Section("merchant.onboarding.serverStatus") {
            CYStatusChip(LocalizedStringKey(application.statusKey), tone: application.accountStatus == 2 || application.status == 2 ? .danger : application.status == 1 ? .success : .warning)
                .accessibilityIdentifier("merchant.onboarding.status")
            Text(LocalizedStringKey(application.explanationKey))
            if let reason = application.displayedReason { Text(reason) }
            if !application.name.isEmpty { LabeledContent("merchant.onboarding.name", value: application.name) }
            if !application.createTime.isEmpty { LabeledContent("merchant.onboarding.submittedAt", value: application.createTime) }
        }
    }
    private var refreshButton: some View {
        CYPillButton("merchant.onboarding.checkAgain", style: .tertiary) { Task { await model.load() } }
            .disabled(model.isBusy).accessibilityIdentifier("merchant.onboarding.refresh")
    }
}
