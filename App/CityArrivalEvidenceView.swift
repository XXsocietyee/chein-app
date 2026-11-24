import SwiftUI

@MainActor struct CityArrivalEvidenceEntry: View {
    let board: CityReadBoard
    let factory: (@MainActor (CityReadBoard) -> CityArrivalEvidenceController)?
    var body: some View {
        if let factory { NavigationLink { CityArrivalEvidenceView(controller: factory(board)) } label: { Label { CityArrivalCopy.text("playerEntry") } icon: { Image(systemName: "checkmark.shield") } } }
        else { CityArrivalCopy.text("status.disabled") }
    }
}
enum CityArrivalCopy {
    static func text(_ key: String) -> Text { Text(LocalizedStringKey("cityArrival." + key), tableName: "CityArrivalEvidence") }
}
@MainActor struct CityArrivalEvidenceView: View {
    @State var controller: CityArrivalEvidenceController
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let live = controller.current && scenePhase == .active
        CYCardPage {
            CYArtCoverHeader(title: CityArrivalCopy.text("title"), subtitle: CityArrivalCopy.text("boundary"), symbol: "mappin.and.ellipse", seed: "arrival") { EmptyView() }
        } content: {
            CYNoteBanner(text: Text(LocalizedStringKey(controller.messageKey), tableName: "CityArrivalEvidence"), symbol: controller.busy ? "hourglass" : "info.circle")
            if live, let state = controller.player {
                CYNoteBanner(text: CityArrivalCopy.text("state." + state.status), symbol: "location.circle")
                if let binding = state.binding {
                    CYInfoCard { CYDetailsDisclosure(title: CityArrivalCopy.text("frozenBinding")) {
                        row("rulesRelease", binding.rulesReleaseId); row("round", binding.rules.roundId) } }
                }
                ForEach(state.points) { point in
                    CityArrivalPointCard(point: point, code: point.challenge.flatMap { controller.codes[$0.id] }, canWrite: controller.canWrite,
                                         busy: controller.busy, current: controller.current,
                                         issue: { controller.prepareIssue(point) }, submit: { controller.prepareSubmit(point) },
                                         readProof: { if let proof = point.evidence { Task { await controller.readProof(proof.id) } } })
                }
            }
            if live, let state = controller.merchant {
                CYInfoCard(title: CityArrivalCopy.text("role." + state.role), symbol: "storefront.fill") {
                    row("merchant", String(state.merchantId)); CityArrivalCopy.text("staffBoundary").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                if state.pending.isEmpty { CYEmptyState(systemImage: "tray", LocalizedStringKey("cityArrival.noPending"), tableName: "CityArrivalEvidence") }
                ForEach(state.pending) { challenge in CityArrivalStaffClaimRow(controller: controller, challenge: challenge) }
            }
            if live, let proof = controller.proof {
                CYInfoCard(title: CityArrivalCopy.text("originalEvidence"), symbol: "checkmark.seal.fill") {
                    CityArrivalCopy.text("evidence." + proof.timeStatus).cyText(.body).foregroundStyle(CYColor.textPrimary)
                    CityArrivalCopy.text("evidenceBoundary").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    CYDetailsDisclosure(title: CityArrivalCopy.text("evidenceId")) {
                        row("evidenceId", proof.id); row("requestId", proof.requestId); row("challengeId", proof.challengeId)
                        row("subject", String(proof.memberId)); row("point", proof.pointId); row("merchant", String(proof.merchantId)); row("place", String(proof.placeId))
                        row("round", proof.roundId); row("rulesRelease", proof.rulesReleaseId)
                        row("reviewer", String(proof.reviewerMemberId)); row("reason", proof.reason); row("recordedAt", proof.createdAt); row("expires", proof.expiresAt)
                    }
                }
            }
            if live, let pending = controller.pendingRequestID {
                CYInfoCard(title: CityArrivalCopy.text("unknownHint"), symbol: "clock.badge.questionmark") {
                    row("requestId", pending.uuidString)
                    CYPillButton(LocalizedStringKey("cityArrival.recover"), tableName: "CityArrivalEvidence") { Task { await controller.recover() } }.disabled(controller.busy || !controller.current)
                }
            }
            if live, let receipt = controller.receipt {
                CYInfoCard(title: CityArrivalCopy.text(receipt.succeeded ? "receiptRecorded" : "receiptRejected"), symbol: receipt.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill") {
                    row("requestId", receipt.requestId)
                    if let proof = receipt.evidence {
                        CYPillButton(LocalizedStringKey("cityArrival.readEvidence"), style: .secondary, tableName: "CityArrivalEvidence") { Task { await controller.readProof(proof.id) } }.disabled(controller.busy || !controller.current)
                    }
                }
            }
            CYPillButton(LocalizedStringKey("cityArrival.reload"), style: .tertiary, systemImage: "arrow.clockwise", tableName: "CityArrivalEvidence") { Task { await controller.load() } }.disabled(controller.busy)
        }
        .navigationTitle(CityArrivalCopy.text("title")).navigationBarTitleDisplayMode(.inline)
        .task { await controller.load() }
        .onChange(of: controller.current) { _, current in if !current { controller.invalidate() } }
        .onChange(of: scenePhase) { _, phase in controller.invalidate(); if phase == .active { Task { await controller.load() } } }
        .onDisappear { controller.invalidate() }
        .sheet(item: Binding(get: { controller.current && scenePhase == .active ? controller.confirmation : nil }, set: { if $0 == nil { controller.cancelConfirmation() } })) { captured in Group {
            NavigationStack {
                Form {
                    Text(verbatim: captured.pointTitle); CityArrivalCopy.text("confirm." + captured.command.kind.rawValue)
                    if let reason = captured.command.reason { row("reason", reason) }
                    CityArrivalCopy.text("noAutomaticEffects")
                    Button { Task { await controller.confirm(captured) } } label: { CityArrivalCopy.text("confirmNow") }.disabled(!controller.canWrite)
                    Button { controller.cancelConfirmation() } label: { CityArrivalCopy.text("cancel") }
                }.cyGroupedSurface().navigationTitle(CityArrivalCopy.text("confirmTitle")).navigationBarTitleDisplayMode(.inline)
            }
        }.cySheet(detents: [.large]) }
    }
    private func row(_ key: String, _ value: String) -> some View { LabeledContent { Text(verbatim: value).textSelection(.enabled) } label: { CityArrivalCopy.text(key) } }
}
@MainActor private struct CityArrivalStaffClaimRow: View {
    let controller: CityArrivalEvidenceController
    let challenge: CityArrivalChallenge
    @State private var code = ""
    @State private var reason = ""
    var body: some View {
        CYInfoCard(title: Text(verbatim: challenge.pointTitle ?? challenge.pointId), symbol: "person.badge.key.fill") {
            TextField(text: $code) { CityArrivalCopy.text("enterPresentedCode") }.textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(CYSpacing.md).frame(minHeight: 48).background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            TextField(text: $reason, axis: .vertical) { CityArrivalCopy.text("enterReason") }
                .padding(CYSpacing.md).frame(minHeight: 48).background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            CYPillButton(LocalizedStringKey("cityArrival.staffConfirm"), tableName: "CityArrivalEvidence") { controller.prepareReview(challenge, confirms: true, code: code, reason: reason) }.disabled(!controller.canWrite)
            CYPillButton(LocalizedStringKey("cityArrival.staffReject"), style: .tertiary, tableName: "CityArrivalEvidence") { controller.prepareReview(challenge, confirms: false, code: "", reason: reason) }.disabled(!controller.canWrite)
            CYDetailsDisclosure(title: CityArrivalCopy.text("challengeId")) {
                LabeledContent { Text(verbatim: challenge.id) } label: { CityArrivalCopy.text("challengeId") }
                LabeledContent { Text(verbatim: String(challenge.memberId)) } label: { CityArrivalCopy.text("subject") }
                LabeledContent { Text(verbatim: challenge.expiresAt) } label: { CityArrivalCopy.text("expires") }
            }
        }
        .onDisappear { code = ""; reason = "" }
        .onChange(of: controller.current) { _, current in if !current { code = ""; reason = "" } }
    }
}

/// One arrival point: 3-step progress (request code, show it in person, confirmed) with a single action for the current step.
struct CityArrivalPointCard: View {
    let point: CityArrivalPoint
    let code: String?
    let canWrite: Bool
    let busy: Bool
    let current: Bool
    let issue: () -> Void
    let submit: () -> Void
    let readProof: () -> Void
    @Environment(\.locale) private var locale
    private var step: Int { point.evidence != nil ? 2 : point.challenge?.state == "ISSUED" ? 1 : 0 }
    var body: some View {
        CYInfoCard {
            Text(verbatim: point.title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            CYStepIndicator(titles: [ChannelCopy.text("申请到场码", "Request code", locale: locale),
                                     ChannelCopy.text("当面出示", "Show in person", locale: locale),
                                     ChannelCopy.text("已确认", "Confirmed", locale: locale)], current: step)
            if let code {
                VStack(spacing: CYSpacing.xs) {
                    Text(verbatim: code).cyText(.data2XL).foregroundStyle(CYColor.textPrimary)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    CityArrivalCopy.text("showOnlyInPerson").cyText(.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(CYSpacing.lg)
                .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            if !point.canIssue { CityArrivalCopy.text("sourceUnavailableHint").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            CityArrivalCopy.text("singlePerson").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            switch step {
            case 0: CYPillButton(LocalizedStringKey("cityArrival.issue"), systemImage: "qrcode", tableName: "CityArrivalEvidence", action: issue).disabled(!canWrite || !point.canIssue)
            case 1: CYPillButton(LocalizedStringKey("cityArrival.submitSelf"), systemImage: "checkmark.circle", tableName: "CityArrivalEvidence", action: submit).disabled(!canWrite || code == nil)
            default: CYPillButton(LocalizedStringKey("cityArrival.readEvidence"), style: .secondary, systemImage: "doc.text.magnifyingglass", tableName: "CityArrivalEvidence", action: readProof).disabled(busy || !current)
            }
            CYDetailsDisclosure(title: CityArrivalCopy.text("challengeWindow")) {
                CYFactRow(label: CityArrivalCopy.text("challengeWindow"), value: String(point.rules.challengeTtlSeconds))
                CYFactRow(label: CityArrivalCopy.text("evidenceWindow"), value: String(point.rules.evidenceTtlSeconds))
                CYFactRow(label: CityArrivalCopy.text("attemptLimit"), value: String(point.rules.maxChallenges))
                CYFactRow(label: CityArrivalCopy.text("attempts"), value: String(point.attemptVersion))
                CYFactRow(label: CityArrivalCopy.text("assuranceReason"), value: point.rules.assuranceReason)
                CYFactRow(label: CityArrivalCopy.text("merchant"), value: String(point.merchantId))
                CYFactRow(label: CityArrivalCopy.text("place"), value: String(point.placeId))
                if let challenge = point.challenge {
                    CYFactRow(label: CityArrivalCopy.text("challengeId"), value: challenge.id)
                    CYFactRow(label: CityArrivalCopy.text("expires"), value: challenge.expiresAt)
                }
            }
        }
    }
}
