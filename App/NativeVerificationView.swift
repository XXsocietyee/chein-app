import SwiftUI

private struct NativeVerificationDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}
extension EnvironmentValues {
    var nativeVerificationDestination: (@MainActor () -> AnyView)? {
        get { self[NativeVerificationDestinationKey.self] }
        set { self[NativeVerificationDestinationKey.self] = newValue }
    }
}
@MainActor struct SessionNativeVerificationView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NativeVerificationView(flow: session.nativeVerificationFlow, cameraEnabled: session.verificationCameraEnabled,
            records: { AnyView(MerchantBusinessPage(reader: session.merchantBusinessReader,
                journal: session.merchantBusinessJournal, query: .redemptions(filter: "all", page: 1))) },
            pledge: session.makeRewardPledgeEntry())
            .id(session.sessionRevision)
    }
}
/// Input, exact-purpose review, any server choice and result/readback are distinct states.
/// Camera/media/provider acceptance is independent of read access and mutation authority.
@MainActor struct NativeVerificationView: View {
    @Bindable var flow: NativeVerificationWorkflow
    var cameraEnabled = false
    let records: @MainActor () -> AnyView
    var pledge: RewardPledgeEntry? = nil
    @State private var raw = ""
    @State private var camera = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                Text("verification.boundary").font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("verification.screen")
                if let key = flow.issueKey, outcome?.isFailure != true { Text(LocalizedStringKey(key)).accessibilityIdentifier("verification.issue") }
                if let detail = flow.issueDetail, outcome?.isFailure != true { Text(verbatim: detail).accessibilityIdentifier("verification.issue.place") }
                if flow.phase == .loading { ProgressView("verification.loading") }
                if let access = flow.access, flow.current {
                    LabeledContent("verification.merchant") { Text(verbatim: access.name ?? String(access.merchantID)) }
                }
            }
            if flow.current {
                if flow.needsReadback {
                    Section("verification.unknownTitle") {
                        Text("verification.unknownBody")
                        NavigationLink { records() } label: { Label("verification.records", systemImage: "list.bullet.rectangle") }
                            .accessibilityIdentifier("verification.readback")
                        Text("verification.readbackDoesNotUnlock").font(.footnote).foregroundStyle(.secondary)
                    }
                } else if flow.phase == .submitting {
                    ProgressView("verification.submitting").accessibilityIdentifier("verification.submitting")
                } else if case .failed(let key)? = outcome {
                    failureSection(key)
                } else if let result = flow.result {
                    resultSection(result)
                }
                if flow.canCapture {
                    Section("verification.capture") {
                        Button("verification.scan", systemImage: "qrcode.viewfinder") { camera = true }
                            .disabled(!cameraEnabled).accessibilityIdentifier("verification.scan")
                        if !cameraEnabled { Text("verification.cameraUnavailable").font(.footnote).foregroundStyle(.secondary) }
                        SecureField("verification.code", text: $raw)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("verification.code")
                        Button("verification.review") { capture() }
                            .disabled(raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("verification.review")
                    }
                }
            }
            Section {
                if let pledge, pledge.current()?.preview == true, flow.access?.allows("merchant:verify") == true {
                    NavigationLink { RewardPledgeStaffHost(entry: pledge) } label: { Text("rewards.pledge.redeem") }
                        .accessibilityIdentifier("rewards.pledge.merchant")
                } else if pledge?.current()?.draft != true {
                    Text("rewards.unavailable").accessibilityIdentifier("rewards.pledge.merchantClosed")
                }
                if let pledge, pledge.current()?.draft == true, flow.access?.allows("merchant:coupon:manage") == true {
                    NavigationLink { RewardPledgeMerchantHost(entry: pledge) } label: { Text("rewards.pledge.draft") }
                        .accessibilityIdentifier("rewards.pledge.supplyEntry")
                }
                if let pledge, flow.access?.allows("merchant:coupon:manage") == true,
                   pledge.current()?.manage == true || pledge.current()?.hold == true || pledge.current()?.withdrawVersion == true || pledge.current()?.stats == true {
                    NavigationLink { RewardPledgeMerchantHost(entry: pledge) } label: { Text("rewards.pledge.stats") }
                        .accessibilityIdentifier("rewards.pledge.manageEntry")
                }
                if let pledge, pledge.current()?.freeze == true, flow.access?.allows("merchant:basic:read") == true {
                    NavigationLink { RewardPledgeReviewHost(entry: pledge) } label: { Text("rewards.pledge.freeze") }
                        .accessibilityIdentifier("rewards.pledge.reviewEntry")
                }
                if !flow.current { Button("verification.refreshAccess") { Task { await flow.activate() } }.disabled(flow.phase == .loading) }
                NavigationLink { records() } label: { Label("verification.records", systemImage: "list.bullet.rectangle") }
                if !flow.canDispatch { Text("verification.dispatchDisabled").font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("verification.title").navigationBarTitleDisplayMode(.inline)
        .privacySensitive().scrollDismissesKeyboard(.interactively)
        .task(id: flow.scope) { raw = ""; await flow.activate() }
        .cySheet(isPresented: $camera) {
            NativeQRScanner { value in raw = ""; Task { await flow.prepare(raw: value) } }
        }
        .cySheet(item: Binding(get: { flow.review }, set: { if $0 == nil { flow.cancelReview() } })) { review in
            NativeVerificationReviewView(review: review, canConfirm: flow.canConfirm,
                confirm: { Task { await flow.confirm(review) } }, cancel: { flow.cancelReview() })
        }
        .onChange(of: scenePhase) { _, phase in
            // Camera permission dialogs can temporarily make the scene inactive.
            // Preserve that presentation; backgrounding or session loss still tears it down.
            if phase == .background { raw = ""; camera = false; flow.deactivate() }
            else if phase == .active, !flow.current { Task { await flow.activate() } }
        }
        .onDisappear { raw = ""; camera = false; flow.deactivate() }
    }
    private func capture() { let captured = raw; raw = ""; Task { await flow.prepare(raw: captured) } }
    private var outcome: NativeVerificationOutcome? {
        NativeVerificationOutcome.make(phase: flow.phase, outcome: flow.result?.outcome, issueKey: flow.issueKey)
    }
    /// F-18: a confirmed redemption that the server refused, or that failed on the way, ends on a result card too.
    @ViewBuilder private func failureSection(_ key: String) -> some View {
        Section {
            Label(LocalizedStringKey(key), systemImage: "exclamationmark.circle")
                .accessibilityIdentifier(NativeVerificationOutcome.failed(key).identifier)
            if let detail = flow.issueDetail { Text(verbatim: detail).font(.footnote).accessibilityIdentifier("verification.issue.place") }
        } header: { Text("verification.result").accessibilityIdentifier("verification.result") }
    }
    @ViewBuilder private func resultSection(_ result: MerchantRedemptionResult) -> some View {
        Section {
            if let message = result.message { Text(verbatim: message).accessibilityIdentifier("verification.result.message") }
            switch result.outcome {
            case .redeemed:
                Label("verification.reportedRedeemed", systemImage: "checkmark.circle")
                    .accessibilityIdentifier(NativeVerificationOutcome.redeemed.identifier)
                Text("verification.receiptBoundary").font(.footnote)
            case .failed:
                Label("verification.rejected", systemImage: "exclamationmark.circle")
                    .accessibilityIdentifier(NativeVerificationOutcome.rejected.identifier)
            case .needsChoice:
                Text("verification.choose")
                ForEach(result.choices) { choice in
                    Button { flow.prepareChoice(choice.target) } label: {
                        if let name = choice.name { Text(verbatim: name) }
                        else { Text(verbatim: choice.id) }
                    }.disabled(flow.phase != .choosing).accessibilityIdentifier("verification.choice." + choice.id)
                }
                Button("action.cancel", role: .cancel) { flow.cancelChoice() }
            }
        } header: { Text("verification.result").accessibilityIdentifier("verification.result") }
    }
}
/// F-18: the confirmed end state of a redemption, each with a stable accessibility id so a run can assert it.
/// `nil` while nothing has been confirmed (capturing, reviewing, submitting, or awaiting a records readback).
enum NativeVerificationOutcome: Equatable {
    case redeemed, rejected, choose
    /// The confirm failed before or without a server verdict (refused code, network, session); `key` is the issue copy.
    case failed(String)

    static func make(phase: NativeVerificationWorkflow.Phase, outcome: MerchantRedemptionResult.Outcome?, issueKey: String?) -> Self? {
        switch phase {
        case .result:
            if let issueKey { return .failed(issueKey) }
            switch outcome {
            case .redeemed?: return .redeemed
            case .failed?: return .rejected
            case .needsChoice?: return .choose
            case nil: return .failed("verification.failed")
            }
        case .choosing:
            return outcome == .needsChoice ? .choose : nil
        default:
            return nil
        }
    }

    var identifier: String {
        switch self {
        case .redeemed: return "verification.result.redeemed"
        case .rejected: return "verification.result.rejected"
        case .choose: return "verification.result.choose"
        case .failed: return "verification.result.failed"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor private struct NativeVerificationReviewView: View {
    let review: NativeVerificationReview
    let canConfirm: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("verification.review") {
                    LabeledContent("verification.merchant") { Text(verbatim: review.merchantName ?? String(review.merchantID)) }
                    LabeledContent("verification.kind") { Text(LocalizedStringKey("verification.kind." + review.kind.rawValue)) }
                    if let name = review.choiceName { LabeledContent("verification.selected") { Text(verbatim: name) } }
                    Text("verification.reviewEffect")
                    Text("verification.reviewPrivacy").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("verification.confirm", action: confirm).disabled(!canConfirm)
                        .accessibilityIdentifier("verification.confirm")
                    if !canConfirm { Text("verification.dispatchDisabled").font(.footnote) }
                }
            }.navigationTitle("verification.review").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel", action: cancel) } }
        }.presentationDetents([.large]).privacySensitive()
    }
}
