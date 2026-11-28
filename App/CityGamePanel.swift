import SwiftUI

/// W20 resident CITY business section on the official CITY read surface. The shipped China
/// composition injects a factory under the owner-approved CITY lease; without the lease
/// there is no factory and the section is not shown. DEBUG fixtures inject a coordinator.
struct CityGameSlot: View {
    let snapshot: CityReadSnapshot
    let factory: (@MainActor (CityReadSnapshot) -> CityGameCoordinator?)?
    var boardLayout = false
    @State private var model: CityGameCoordinator?
    @State private var resolved = false
    var body: some View {
        // The task needs a concrete host even before model/resolved has content.
        VStack(alignment: .leading, spacing: 0) {
            // Without a coordinator the section is not shown at all, rather than saying it is unavailable.
            if let model { CityGamePanel(model: model, read: snapshot, boardLayout: boardLayout) }
        }
        .task {
            guard !resolved else { return }
            model = factory?(snapshot); resolved = true
            await model?.load()
        }
        .onDisappear { model?.invalidate() }
    }
}

struct CityGamePanel: View {
    let model: CityGameCoordinator
    let read: CityReadSnapshot
    /// Night-city board layout (ring of tiles + turn HUD + verdict). Default keeps the plain list.
    var boardLayout = false
    @State private var selectedProperty: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("cityGame.title", tableName: "CityGame").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
            phaseText.cyText(.meta).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("cityGame.phase")
            if model.phase == .loading || model.phase == .quoting || model.phase == .sending { CYLoadingState() }
            if let notice = model.notice { noticeText(notice).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("cityGame.notice") }
            if let outcome = model.lastOutcome { outcomeText(outcome).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("cityGame.outcome") }
            if model.phase == .unknown { unknownSection }
            if let review = model.review, model.phase == .review { reviewCard(review) }
            if let snapshot = model.snapshot { boardContent(snapshot) }
            if model.phase == .unavailable || model.phase == .ready {
                Button { Task { if model.phase == .ready { await model.refresh() } else { await model.load() } } } label: { Text("cityGame.refresh", tableName: "CityGame").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    .accessibilityIdentifier("cityGame.refresh")
            }
            Text("cityGame.privacy", tableName: "CityGame").cyText(.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cityGameGroupBox()
        .accessibilityElement(children: .contain)
        .cyHaptic(.success, trigger: outcomeApplied)
        .accessibilityIdentifier("cityGame.panel")
    }

    @ViewBuilder private func boardContent(_ snapshot: CityGameSnapshot) -> some View {
        if let notice = model.boardNotice {
            Group {
                if notice == .notJoined { Text("cityGame.board.notJoined", tableName: "CityGame") }
                else { lifecycleText(snapshot.lifecycle) }
            }.fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("cityGame.boardNotice")
        }
        if snapshot.team != nil {
            InGameChannelRowButton(
                scope: .cityTeam(teamID: nil, boardID: snapshot.boardId),
                titleKey: "ingame.channel.city",
                subtitleKey: "ingame.channel.citySubtitle",
                accessibilityID: "ingame.channel.cityGame.entry",
                reloadTrigger: snapshot.boardId
            )
        }
        if boardLayout { boardSection(snapshot) }
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            statTile("cityGame.rules.actions", value: { () -> String? in
                if let remaining = snapshot.rules.actionsRemaining, let total = snapshot.rules.actionsPerRound { return "\(remaining) / \(total)" }
                return nil
            }()).accessibilityIdentifier("cityGame.actions")
            statTile("cityGame.rules.holdings", value: snapshot.rules.holdingLimit.map { "\(snapshot.heldCount) / \($0)" })
            statTile("cityGame.points.balance", value: snapshot.memberPoints.map { String($0) }).accessibilityIdentifier("cityGame.points")
        }
        if snapshot.memberPoints == 0, snapshot.neutralTasksAvailable {
            Text("cityGame.points.zero", tableName: "CityGame").cyText(.bodyCompact).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("cityGame.zeroPoints")
        }
        if model.canRoll {
            Button { model.prepareRoll() } label: { Label { Text("cityGame.roll", tableName: "CityGame") } icon: { Image(systemName: "dice") }.frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cityGame.roll")
        }
        if snapshot.properties.isEmpty { Text("cityGame.properties.empty", tableName: "CityGame").cyText(.body).foregroundStyle(CYColor.textSecondary) }
        if boardLayout {
            if let selected = snapshot.properties.first(where: { $0.propertyId == selectedProperty }) { propertyRow(selected) }
        } else {
            ForEach(snapshot.properties) { property in propertyRow(property) }
        }
    }

    /// Verdict once closed, otherwise turn HUD + ring. The die shows the server-rolled face from the last receipt.
    @ViewBuilder private func boardSection(_ snapshot: CityGameSnapshot) -> some View {
        if snapshot.lifecycle == .closed || snapshot.lifecycle == .archived {
            CYCityVerdict(held: snapshot.heldCount, holdingLimit: snapshot.rules.holdingLimit, points: snapshot.memberPoints)
        }
        CYCityTurnHUD(roundSeq: snapshot.roundSeq, actionsRemaining: snapshot.rules.actionsRemaining,
                      actionsPerRound: snapshot.rules.actionsPerRound,
                      face: model.lastReceipt?.diceFace,
                      rolling: model.phase == .sending && model.review?.kind == .roll)
        if !snapshot.properties.isEmpty {
            CYCityBoardRing(properties: snapshot.properties, title: { title(for: $0) }, selection: $selectedProperty)
                .frame(maxWidth: 420).frame(maxWidth: .infinity)
            if selectedProperty == nil {
                Text("cityGame.board.selectHint", tableName: "CityGame").cyText(.caption).foregroundStyle(CYColor.textTertiary)
            }
        }
    }

    @ViewBuilder private func propertyActions(_ property: CityPropertyState) -> some View {
        ForEach(model.actions(for: property), id: \.rawValue) { kind in
            Button { Task { await model.prepare(kind, property: property) } } label: { actionText(kind) }
                .buttonStyle(.bordered).controlSize(.small)
                .accessibilityIdentifier("cityGame.action.\(kind.rawValue).\(property.propertyId)")
        }
    }

    @ViewBuilder private func propertyRow(_ property: CityPropertyState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title(for: property)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                chip(roleText(property.role), tone: .neutral)
                chip(statusText(property.status), tone: property.status == .available ? .success : property.status == .safetyBlocked ? .danger : property.status == .held ? .info : .warning)
            }
            if property.heldByMyTeam { Text("cityGame.property.mine", tableName: "CityGame").cyText(.meta) }
            if let until = property.protectedUntilMillis {
                LabeledContent { Text(Date(timeIntervalSince1970: Double(until) / 1000), format: .dateTime.month().day().hour().minute()) } label: { Text("cityGame.property.protectedUntil", tableName: "CityGame") }.cyText(.meta)
            }
            if let challenge = property.challenge { challengeText(challenge).cyText(.meta) }
            if property.taskAttemptKept { Text("cityGame.property.taskKept", tableName: "CityGame").cyText(.meta).fixedSize(horizontal: false, vertical: true) }
            ForEach(property.services) { offer in
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: offer.title).cyText(.bodyCompact)
                        if let fee = offer.memberPointsFee {
                            if fee == 0 { Text("cityGame.service.free", tableName: "CityGame").cyText(.meta) }
                            else { LabeledContent { Text(verbatim: String(fee)) } label: { Text("cityGame.service.fee", tableName: "CityGame") }.cyText(.meta) }
                        } else { Text("cityGame.service.feeUnpublished", tableName: "CityGame").cyText(.meta) }
                    }
                    Spacer(minLength: 0)
                    if model.canAcceptService(offer, on: property) {
                        Button { Task { await model.prepare(.acceptServiceVisit, property: property, service: offer) } } label: { Text("cityGame.service.accept", tableName: "CityGame") }.buttonStyle(.bordered)
                            .accessibilityIdentifier("cityGame.service.\(offer.serviceId)")
                    }
                }
            }
            // ADA 1128 (d2-city): one prominent action per page (开始本轮); each property's actions are compact
            // bordered buttons on the trailing edge, stacked when they do not fit on one line.
            if !model.actions(for: property).isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CYSpacing.sm) {
                        Spacer(minLength: 0)
                        propertyActions(property)
                    }
                    VStack(alignment: .trailing, spacing: CYSpacing.sm) {
                        propertyActions(property)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cityGameGroupBox()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cityGame.property.\(property.propertyId)")
    }

    @ViewBuilder private func reviewCard(_ review: CityGameReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("cityGame.review.title", tableName: "CityGame").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
            actionText(review.kind)
            if let propertyId = review.propertyId, let property = model.snapshot?.properties.first(where: { $0.propertyId == propertyId }) {
                Text(verbatim: title(for: property))
            }
            if let service = review.serviceTitle { Text(verbatim: service) }
            if let quote = review.quote {
                LabeledContent { Text(verbatim: String(quote.memberPointsCost)) } label: { Text("cityGame.review.cost", tableName: "CityGame") }
                    .accessibilityIdentifier("cityGame.review.cost")
                LabeledContent { Text(verbatim: String(quote.actionCost)) } label: { Text("cityGame.review.actionCost", tableName: "CityGame") }
                LabeledContent { Text("cityGame.review.payerYou", tableName: "CityGame") } label: { Text("cityGame.review.payer", tableName: "CityGame") }
                LabeledContent { Text(verbatim: String(quote.beneficiaryMemberIds.count)) } label: { Text("cityGame.review.beneficiaries", tableName: "CityGame") }
                LabeledContent { Text(Date(timeIntervalSince1970: Double(quote.expiresAtMillis) / 1000), format: .dateTime.hour().minute().second()) } label: { Text("cityGame.review.expires", tableName: "CityGame") }
                Text("cityGame.review.noTeammate", tableName: "CityGame").cyText(.meta).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("cityGame.review.free", tableName: "CityGame").cyText(.meta).fixedSize(horizontal: false, vertical: true)
            }
            if !model.reviewAffordable {
                Text("cityGame.review.insufficient", tableName: "CityGame").cyText(.bodyCompact).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cityGame.review.insufficient")
            }
            Button { Task { await model.confirm() } } label: { Text("cityGame.review.confirm", tableName: "CityGame").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!model.reviewAffordable).accessibilityIdentifier("cityGame.confirm")
            Button { model.cancelReview() } label: { Text("cityGame.review.cancel", tableName: "CityGame").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                .accessibilityIdentifier("cityGame.cancel")
        }
        .cityGameGroupBox()
        .accessibilityElement(children: .contain).accessibilityIdentifier("cityGame.review")
    }

    // N-ORIENT (r10): system Buttons (borderedProminent primary, bordered secondary) replace CYPillButton;
    // MP subpackageCity city game panel actions keep the same order and identifiers.
    @ViewBuilder private var unknownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("cityGame.unknown.explain", tableName: "CityGame").cyText(.bodyCompact).fixedSize(horizontal: false, vertical: true)
            Button { Task { await model.readBack() } } label: { Text("cityGame.unknown.readBack", tableName: "CityGame").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                .accessibilityIdentifier("cityGame.readBack")
            if model.canRetryExact {
                Button { Task { await model.retryExact() } } label: { Text("cityGame.unknown.retry", tableName: "CityGame").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    .accessibilityIdentifier("cityGame.retry")
            }
        }
    }

    /// Number tile: tabular figure, muted label; unknown shows an em dash, never 0.
    private func statTile(_ label: LocalizedStringKey, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: value ?? "—").cyText(.sectionTitle, weight: .bold, monospacedDigit: true)
                .foregroundStyle(CYColor.textPrimary).minimumScaleFactor(0.7).lineLimit(1)
            Text(label, tableName: "CityGame").cyText(.caption).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func chip(_ text: Text, tone: CYStatusTone) -> some View {
        // N-ORIENT (r10): plain secondary caption, no drawn capsule (MP subpackageCity status text).
        text.font(.caption).foregroundStyle(.secondary)
    }

    private var outcomeApplied: Bool {
        if case .applied? = model.lastOutcome { return true }
        return false
    }

    private func title(for property: CityPropertyState) -> String {
        read.points?.first(where: { $0.pointId == property.pointId })?.title ?? property.propertyId
    }

    private var phaseText: Text {
        switch model.phase {
        case .disabled: return Text("cityGame.phase.disabled", tableName: "CityGame")
        case .idle, .ready: return Text("cityGame.phase.ready", tableName: "CityGame")
        case .loading: return Text("cityGame.phase.loading", tableName: "CityGame")
        case .unavailable: return Text("cityGame.phase.unavailable", tableName: "CityGame")
        case .quoting: return Text("cityGame.phase.quoting", tableName: "CityGame")
        case .review: return Text("cityGame.phase.review", tableName: "CityGame")
        case .sending: return Text("cityGame.phase.sending", tableName: "CityGame")
        case .unknown: return Text("cityGame.phase.unknown", tableName: "CityGame")
        case .invalidated: return Text("cityGame.phase.invalidated", tableName: "CityGame")
        }
    }

    private func noticeText(_ notice: CityGameCoordinator.Notice) -> Text {
        switch notice {
        case .unavailable: return Text("cityGame.notice.unavailable", tableName: "CityGame")
        case .invalidQuote: return Text("cityGame.notice.invalidQuote", tableName: "CityGame")
        case .payerMismatch: return Text("cityGame.notice.payerMismatch", tableName: "CityGame")
        case .quoteExpired: return Text("cityGame.notice.quoteExpired", tableName: "CityGame")
        case .insufficientPoints: return Text("cityGame.review.insufficient", tableName: "CityGame")
        case .busy: return Text("cityGame.notice.busy", tableName: "CityGame")
        case .noReceiptYet: return Text("cityGame.notice.noReceiptYet", tableName: "CityGame")
        case .unknownOutcome: return Text("cityGame.notice.unknownOutcome", tableName: "CityGame")
        case .boardNotOpen: return Text("cityGame.notice.boardNotOpen", tableName: "CityGame")
        case .notJoined: return Text("cityGame.board.notJoined", tableName: "CityGame")
        case .refreshed: return Text("cityGame.notice.refreshed", tableName: "CityGame")
        }
    }

    private func outcomeText(_ outcome: CityPendingAction.Outcome) -> Text {
        switch outcome {
        case .applied: return Text("cityGame.outcome.applied", tableName: "CityGame")
        case .alreadyApplied: return Text("cityGame.outcome.alreadyApplied", tableName: "CityGame")
        case .refresh(let kept):
            return kept ? Text("cityGame.outcome.conflictKept", tableName: "CityGame") : Text("cityGame.outcome.conflict", tableName: "CityGame")
        case .requote: return Text("cityGame.outcome.requote", tableName: "CityGame")
        case .rejected: return Text("cityGame.outcome.rejected", tableName: "CityGame")
        case .blocked: return Text("cityGame.outcome.blocked", tableName: "CityGame")
        case .unknown: return Text("cityGame.notice.unknownOutcome", tableName: "CityGame")
        }
    }

    private func actionText(_ kind: CityActionKind) -> Text {
        switch kind {
        case .roll: return Text("cityGame.roll", tableName: "CityGame")
        case .acceptTask: return Text("cityGame.action.acceptTask", tableName: "CityGame")
        case .submitEvidence: return Text("cityGame.action.submitEvidence", tableName: "CityGame")
        case .acquireProperty: return Text("cityGame.action.acquire", tableName: "CityGame")
        case .acceptServiceVisit: return Text("cityGame.service.accept", tableName: "CityGame")
        case .completeServiceVisit: return Text("cityGame.action.completeService", tableName: "CityGame")
        case .startChallenge: return Text("cityGame.action.challenge", tableName: "CityGame")
        }
    }

    private func roleText(_ role: CityPropertyRole) -> Text {
        role == .neutral ? Text("cityGame.role.neutral", tableName: "CityGame") : Text("cityGame.role.operable", tableName: "CityGame")
    }

    private func statusText(_ status: CityPropertyStatus) -> Text {
        switch status {
        case .available: return Text("cityGame.status.available", tableName: "CityGame")
        case .held: return Text("cityGame.status.held", tableName: "CityGame")
        case .protected: return Text("cityGame.status.protected", tableName: "CityGame")
        case .paused: return Text("cityGame.status.paused", tableName: "CityGame")
        case .safetyBlocked: return Text("cityGame.status.safetyBlocked", tableName: "CityGame")
        }
    }

    private func challengeText(_ state: CityChallengeState) -> Text {
        switch state {
        case .offered: return Text("cityGame.challenge.offered", tableName: "CityGame")
        case .accepted: return Text("cityGame.challenge.accepted", tableName: "CityGame")
        case .evidenceReady: return Text("cityGame.challenge.evidenceReady", tableName: "CityGame")
        case .resolved: return Text("cityGame.challenge.resolved", tableName: "CityGame")
        case .cancelled: return Text("cityGame.challenge.cancelled", tableName: "CityGame")
        case .expired: return Text("cityGame.challenge.expired", tableName: "CityGame")
        case .suspended: return Text("cityGame.challenge.suspended", tableName: "CityGame")
        }
    }

    private func lifecycleText(_ lifecycle: CityBoardLifecycle) -> Text {
        switch lifecycle {
        case .frozen: return Text("cityGame.lifecycle.frozen", tableName: "CityGame")
        case .closing: return Text("cityGame.lifecycle.closing", tableName: "CityGame")
        case .closed, .archived: return Text("cityGame.lifecycle.closed", tableName: "CityGame")
        case .draft, .review, .ready: return Text("cityGame.lifecycle.notOpen", tableName: "CityGame")
        case .open: return Text("cityGame.notice.boardNotOpen", tableName: "CityGame")
        }
    }
}

private extension View {
    /// N-ORIENT (r10): the drawn `cyDomainCard` → system `GroupBox` (system grouped fill and corner radius).
    /// MP subpackageCity city game panel cards keep their content and order.
    func cityGameGroupBox() -> some View { GroupBox { self } }
}
