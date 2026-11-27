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
                Text("nativeEnrollment.boundary")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                fact("nativeEnrollment.app", shown(model.scope.appID), systemImage: "app")
                fact("nativeEnrollment.environment", shown(model.scope.environment), systemImage: "server.rack")
                fact("nativeEnrollment.account", String(model.scope.accountID), systemImage: "person")
                if let key = model.record?.deviceKeyID {
                    fact("nativeEnrollment.fingerprint", fingerprint(key), systemImage: "touchid")
                }
                Label(LocalizedStringKey("nativeEnrollment.phase." + model.phase), systemImage: phaseSymbol)
                    .foregroundStyle(phaseTone)
                    .accessibilityIdentifier("nativeEnrollment.phase")
                if let issue = model.issue {
                    Label(LocalizedStringKey("nativeEnrollment.issue." + issue.rawValue), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
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
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    pill("nativeEnrollment.enroll", .enroll, systemImage: "checkmark.circle") { review = .enroll }
                        .accessibilityIdentifier("nativeEnrollment.enroll")
                }
                if model.canRetryEnrollment {
                    Text("nativeEnrollment.recoveryProof")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("nativeEnrollment.retryRevoke", role: .destructive) { review = .revoke }
                        .accessibilityIdentifier("nativeEnrollment.retryRevoke")
                }
                if working {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("nativePlatform.working"))
                    Text("nativePlatform.working")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("nativeEnrollment.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .accessibilityIdentifier("nativeEnrollment.host")
        .task { await model.load() }
        .cySheet(item: $review) { action in
            NavigationStack {
                Form {
                    Section {
                        Text(LocalizedStringKey("nativeEnrollment.review." + action.rawValue))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("nativeEnrollment.noHardwareProof")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if action == .create {
                            Text("nativeEnrollment.keyDurability")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if action == .revoke {
                            Text("nativeEnrollment.revokeConsequence")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        fact("nativeEnrollment.account", String(model.scope.accountID), systemImage: "person")
                        fact("nativeEnrollment.app", shown(model.scope.appID), systemImage: "app")
                        if let privacyURL { Link("nativePlatform.privacy", destination: privacyURL) }
                        if action == .revoke {
                            Button(LocalizedStringKey("nativeEnrollment.confirm." + action.rawValue), role: .destructive) { confirm(action) }
                                .accessibilityIdentifier("nativeEnrollment.confirm")
                        } else {
                            Button { confirm(action) } label: {
                                Label(LocalizedStringKey("nativeEnrollment.confirm." + action.rawValue), systemImage: "checkmark.circle")
                            }
                            .accessibilityIdentifier("nativeEnrollment.confirm")
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(Text("nativeEnrollment.reviewTitle"))
                .navigationBarTitleDisplayMode(.inline)
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
    private var phaseTone: Color {
        switch model.phase {
        case "active": return .green
        case "failed", "revoked", "disabled": return .red
        case "unknown", "stale", "recovery": return .orange
        case "generating", "preparing", "attesting", "enrolling", "revoking", "review": return .accentColor
        default: return .secondary
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
    /// Form button row; the one next step the model expects reads semibold, as Settings marks its default action.
    private func pill(_ title: LocalizedStringKey, _ kind: Primary, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: systemImage) }
            .fontWeight(enrollmentPrimary == kind ? .semibold : .regular)
    }
    private func fact(_ title: LocalizedStringKey, _ value: String, systemImage: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
        } label: {
            Label(title, systemImage: systemImage)
        }
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
