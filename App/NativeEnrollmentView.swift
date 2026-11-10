import SwiftUI
import CryptoKit

@MainActor struct NativeEnrollmentView: View {
    @Bindable var model: NativeEnrollmentCoordinator
    let privacyURL: URL?
    private enum Review: String, Identifiable { case create, enroll, revoke; var id: String { rawValue } }
    private enum Primary { case refresh, resume, create, enroll, retryEnroll }
    @State private var review: Review?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Form {
            Section {
                CYHeroHeader("nativeEnrollment.title") {
                    CYCoverArt(seed: "native-enrollment", symbol: "checkmark.shield", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .accessibilityHidden(true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                Text("nativeEnrollment.boundary")
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYListRow("nativeEnrollment.app", trailing: .value(shown(model.scope.appID))) { CYRowIcon(systemImage: "app") }
                CYListRow("nativeEnrollment.environment", trailing: .value(shown(model.scope.environment))) { CYRowIcon(systemImage: "server.rack") }
                CYListRow("nativeEnrollment.account", trailing: .value(String(model.scope.accountID))) { CYRowIcon(systemImage: "person") }
                if let key = model.record?.deviceKeyID {
                    CYListRow("nativeEnrollment.fingerprint", trailing: .value(fingerprint(key))) { CYRowIcon(systemImage: "touchid") }
                }
                CYStatusChip(LocalizedStringKey("nativeEnrollment.phase." + model.phase), tone: phaseTone, systemImage: phaseSymbol)
                    .accessibilityIdentifier("nativeEnrollment.phase")
                if let issue = model.issue {
                    CYStatusChip(LocalizedStringKey("nativeEnrollment.issue." + issue.rawValue), tone: .danger, systemImage: "exclamationmark.triangle")
                        .accessibilityIdentifier("nativeEnrollment.issue")
                }
                if let privacyURL { Link("nativePlatform.privacy", destination: privacyURL) }
            }
            Section {
                pill("nativeEnrollment.refresh", .refresh, systemImage: "arrow.clockwise") { Task { await model.load() } }
                    .accessibilityIdentifier("nativeEnrollment.refresh")
                if model.canResumePreparation {
                    pill("nativeEnrollment.resumeKey", .resume, systemImage: "key") { Task { await model.prepareSavedKey() } }
                        .accessibilityIdentifier("nativeEnrollment.resumeKey")
                }
                if model.canCreate && !model.canResumePreparation {
                    pill(model.record == nil ? "nativeEnrollment.create" : "nativeEnrollment.createNew", .create, systemImage: "plus") { review = .create }
                        .accessibilityIdentifier("nativeEnrollment.create")
                }
                if model.canSubmit {
                    Text("nativeEnrollment.proofLocal")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    pill("nativeEnrollment.enroll", .enroll, systemImage: "checkmark.circle") { review = .enroll }
                        .accessibilityIdentifier("nativeEnrollment.enroll")
                }
                if model.canRetryEnrollment {
                    Text("nativeEnrollment.recoveryProof")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    pill("nativeEnrollment.retryEnroll", .retryEnroll, systemImage: "arrow.clockwise") { Task { await model.retryExactEnrollment() } }
                        .accessibilityIdentifier("nativeEnrollment.retryEnroll")
                }
                if model.canRevoke {
                    Button("nativeEnrollment.revoke", role: .destructive) { review = .revoke }
                        .accessibilityIdentifier("nativeEnrollment.revoke")
                }
                if model.canRetryRevocation {
                    Text("nativeEnrollment.recoveryRevoke")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("nativeEnrollment.retryRevoke", role: .destructive) { review = .revoke }
                        .accessibilityIdentifier("nativeEnrollment.retryRevoke")
                }
                if working {
                    CYSkeleton()
                        .accessibilityLabel(Text("nativePlatform.working"))
                    Text("nativePlatform.working")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(CYTypography.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .accessibilityIdentifier("nativeEnrollment.host")
        .cyAnimation(value: model.phase)
        .task { await model.load() }
        .sheet(item: $review) { action in
            NavigationStack {
                Form {
                    Section {
                        CYHeroHeader("nativeEnrollment.reviewTitle")
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    Section {
                        Text(LocalizedStringKey("nativeEnrollment.review." + action.rawValue))
                            .font(CYTypography.body)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("nativeEnrollment.noHardwareProof")
                            .font(CYTypography.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if action == .create {
                            Text("nativeEnrollment.keyDurability")
                                .font(CYTypography.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if action == .revoke {
                            Text("nativeEnrollment.revokeConsequence")
                                .font(CYTypography.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CYListRow("nativeEnrollment.account", trailing: .value(String(model.scope.accountID))) { CYRowIcon(systemImage: "person") }
                        CYListRow("nativeEnrollment.app", trailing: .value(shown(model.scope.appID))) { CYRowIcon(systemImage: "app") }
                        if let privacyURL { Link("nativePlatform.privacy", destination: privacyURL) }
                        if action == .revoke {
                            Button(LocalizedStringKey("nativeEnrollment.confirm." + action.rawValue), role: .destructive) { confirm(action) }
                                .accessibilityIdentifier("nativeEnrollment.confirm")
                        } else {
                            CYPillButton(LocalizedStringKey("nativeEnrollment.confirm." + action.rawValue), systemImage: "checkmark.circle") { confirm(action) }
                                .accessibilityIdentifier("nativeEnrollment.confirm")
                        }
                    }
                }
                .font(CYTypography.body)
                .cyGroupedSurface()
                .cyHeroScreen()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("nativePlatform.cancel") { review = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { review = nil; model.suspend() }
            if phase == .active { Task { await model.load() } }
        }
        .onDisappear { review = nil; model.pauseWork() }
    }
    private var enrollmentPrimary: Primary {
        if model.canSubmit { return .enroll }
        if model.canRetryEnrollment { return .retryEnroll }
        if model.canResumePreparation { return .resume }
        if model.canCreate && !model.canResumePreparation { return .create }
        return .refresh
    }
    private var working: Bool { ["generating", "preparing", "attesting", "enrolling", "revoking"].contains(model.phase) }
    private var phaseTone: CYStatusTone {
        switch model.phase {
        case "active": return .success
        case "failed", "revoked", "disabled": return .danger
        case "unknown", "stale", "recovery": return .warning
        case "generating", "preparing", "attesting", "enrolling", "revoking", "review": return .info
        default: return .neutral
        }
    }
    private var phaseSymbol: String {
        switch model.phase {
        case "active": return "checkmark.seal"
        case "failed", "revoked", "disabled": return "exclamationmark.triangle"
        case "unknown", "stale", "recovery": return "questionmark.circle"
        case "generating", "preparing", "attesting", "enrolling", "revoking", "review": return "clock"
        default: return "circle"
        }
    }
    private func pill(_ title: LocalizedStringKey, _ kind: Primary, systemImage: String, action: @escaping () -> Void) -> some View {
        CYPillButton(title, style: enrollmentPrimary == kind ? .primary : .secondary, systemImage: systemImage, action: action)
    }
    /// Blank scope text is unknown. A real account id, including 0, stays a number.
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func confirm(_ action: Review) {
        review = nil
        Task {
            switch action {
            case .create: await model.prepareNewKey()
            case .enroll: await model.submitReviewed()
            case .revoke:
                if model.canRetryRevocation { await model.retryExactRevocation() }
                else { await model.revokeReviewed() }
            }
        }
    }
    private func fingerprint(_ key: String) -> String { SHA256.hash(data: Data(key.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined() }
}
