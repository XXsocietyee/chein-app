import SwiftUI

/// Declared H5 surface. Appearance does not open a container.
/// Open reports the missing original SDK and does not show a successful session.
@MainActor struct H5DeclaredSessionView: View {
    let frozen: H5FrozenCapability
    let host: String
    let capability: String
    let sdkVersion: String
    let launch: H5LaunchDescription?
    @State private var page = H5DeclaredSessionPage()
    @State private var requestID = ""
    @State private var moduleID = ""
    @State private var answer = ""
    @State private var message = ""

    var body: some View {
        Form {
            Section {
                CYListRow(verbatim: host, meta: capability, trailing: .value(sdkVersion)) { CYRowIcon(systemImage: "globe") }
                    .accessibilityElement(children: .combine)
            } header: { Text("h5.surface").accessibilityAddTraits(.isHeader) }
            Section {
                TextField("h5.request", text: $requestID)
                TextField("h5.module", text: $moduleID)
                TextField("h5.answer", text: $answer)
            }
            Section {
                Button("h5.admit") { admit() }
                Button("h5.compare") { compare() }
                Button("h5.rejectAnswers") { rejectAnswers() }
                Button("h5.importMetadata") { importMetadata() }
            } footer: {
                if !message.isEmpty { Text(LocalizedStringKey(message)).cyText(.meta) }
            }
        }
        .navigationTitle(Text("h5.title")).navigationBarTitleDisplayMode(.inline).formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            CYPillButton("h5.open", style: .primary) { message = page.openShell(launch: launch).capabilityText }
                .disabled(page.session.gate.phase != .admitted && page.session.gate.phase != .waitingSource)
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
        }
    }

    private func admit() {
        do {
            try page.admit(host: host, capability: capability, sdkVersion: sdkVersion, frozen: frozen)
            message = "h5.admitted"
        } catch let error as H5SessionFailure {
            message = error.capabilityText
        } catch {
            message = "h5.invalid"
        }
    }

    private func compare() {
        do {
            try page.compareServerHash(serverFrozenHash: frozen.contentHash, expectedHash: frozen.contentHash,
                                       originalRequestID: requestID)
            message = "h5.matched"
        } catch let error as H5AnswerProtectionFailure {
            message = error.capabilityText
        } catch {
            message = "h5.invalid"
        }
    }

    private func rejectAnswers() {
        message = page.rejectClientAnswers(["answer": answer]).capabilityText
    }

    private func importMetadata() {
        let object = ["id": moduleID, "version": frozen.packageVersion, "contentHash": frozen.contentHash, "schemaVersion": "1"]
        do {
            try page.importMetadata(object, entry: moduleID, originalRequestID: requestID)
            message = page.imports.gate.phase == .reviewPending ? "h5.reviewPending" : "h5.invalid"
        } catch let error as WorkshopModuleImportFailure {
            message = error.capabilityText
        } catch {
            message = "h5.invalid"
        }
    }
}

private extension H5AnswerProtectionFailure {
    var capabilityText: String {
        switch self {
        case .waitingSource(let capability): return capability
        case .answersMustNotShipInClientPack, .jsSelfReportRejected, .clientClockCannotSucceed: return "h5.answersRejected"
        case .hashMismatch: return "h5.hashMismatch"
        case .invalidCompare: return "h5.invalid"
        case .requestMismatch: return "h5.requestMismatch"
        }
    }
}

private extension WorkshopModuleImportFailure {
    var capabilityText: String {
        switch self {
        case .waitingSource(let capability): return capability
        case .answersOrHiddenCoordinatesForbidden, .jsExecutionForbidden, .runtimeWriteForbidden: return "h5.answersRejected"
        case .invalidManifest, .unknownModuleFormat, .notImported, .notValidated, .notPreviewed: return "h5.invalid"
        case .requestMismatch: return "h5.requestMismatch"
        }
    }
}

private extension H5SessionFailure {
    var capabilityText: String {
        switch self {
        case .waitingSource(let capability): return capability
        case .unsignedDomain: return "h5.unsignedDomain"
        case .capabilityNotGranted: return "h5.capabilityNotGranted"
        case .versionIncompatible: return "h5.versionIncompatible"
        case .arbitraryH5Forbidden: return "h5.arbitraryForbidden"
        case .notAdmitted: return "h5.notAdmitted"
        case .invalidSurface: return "h5.invalid"
        case .requestMismatch: return "h5.requestMismatch"
        }
    }
}
