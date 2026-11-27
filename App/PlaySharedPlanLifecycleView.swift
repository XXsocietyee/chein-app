import SwiftUI

@MainActor struct PlaySharedPlanLifecycleView: View {
    @Bindable var model: PlaySharedPlanLifecycle
    var operationDestination: (PlaySharedPlanLifecycle, PlaySharedPlanOperationTicket) -> AnyView? = { _, _ in nil }
    @State private var selectedEnding: String?
    @State private var quantities: [String: String] = [:]
    @State private var acceptance = Set<String>()
    @State private var acceptanceDirty = false
    @State private var offered: PlaySharedPlanReview?
    @State private var shownOperation: PlaySharedPlanOperationTicket?
    private let rowActions: [PlaySharedPlanAction] = [.propose, .withdraw, .vote, .consensus, .confirm, .start, .cancel, .execute]
    private let globalActions: [PlaySharedPlanAction] = [.openVote, .nextVote, .change, .rejectAll]
    @Environment(\.locale) private var locale
    var body: some View {
        Form {
            Section("sharedPlan.section.status") {
                if let p = model.projection {
                    Text("sharedPlan.round \(p.round)").cyText(.meta)
                    Text(p.team.captain ? "sharedPlan.captain.yes" : "sharedPlan.captain.no")
                    Text(policyKey(p.policy)) + Text(verbatim: " · ") + Text(phaseKey(p.phase))
                    if !p.team.writable { Text("sharedPlan.readOnly").cyText(.meta) }
                } else { Text("sharedPlan.loading") }
                if model.busy { ProgressView() }
                if let message = model.message { Text(LocalizedStringKey(message)).accessibilityIdentifier("sharedPlan.message") }
                Button(model.pending == nil ? "sharedPlan.refresh" : "sharedPlan.checkResult") { reset(); Task { await model.load() } }
                    .disabled(model.busy || !model.isCurrent).accessibilityIdentifier("sharedPlan.refresh")
                if !model.writesEnabled { Text("sharedPlan.writesOff").cyText(.meta) }
            }
            if let command = model.pending {
                Section("sharedPlan.section.pending") {
                    Text(LocalizedStringKey(command.action.title))
                    Text("sharedPlan.round \(command.identity.round)").cyText(.meta)
                    Text("sharedPlan.pending.note")
                }
            }
            if let receipt = model.receipt {
                Section("sharedPlan.section.receipt") {
                    Text(LocalizedStringKey(receipt.action.title)) + Text(verbatim: " · ") + Text(outcomeKey(receipt.outcome))
                    if let reason = receipt.reason { Text(reason) }
                    if receipt.outcome == "APPLIED", receipt.action == .execute { result(receipt.result["result"], label: "sharedPlan.result.execute") }
                    else { Text("sharedPlan.receipt.note").cyText(.meta) }
                }
            }
            if let p = model.projection {
                Section("sharedPlan.section.materials") {
                    ForEach(p.team.items) { item in
                        LabeledContent {
                            Text("sharedPlan.material \(item.available.map(String.init) ?? "—") \(item.locked.map(String.init) ?? "—")")
                        } label: { Text(item.name) }
                    }
                    Text("sharedPlan.materials.note").cyText(.meta)
                }
                Section("sharedPlan.section.plans") {
                    ForEach(p.rows) { row in
                        Button {
                            model.invalidateReview(); selectedEnding = row.endingKey
                            quantities = Dictionary(uniqueKeysWithValues: row.cost.map { cost in (cost.itemID, String(row.ownIntent.first { $0.itemID == cost.itemID }?.quantity ?? 0)) })
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                                Text(row.title).cyText(.cardTitle)
                                if row.selected { Label("sharedPlan.selected", systemImage: "checkmark.seal").cyText(.bodyCompact) }
                                Text(row.summary).font(.subheadline).foregroundStyle(.secondary)
                                Text("sharedPlan.needs \(amounts(row.cost, p))").cyText(.bodyCompact)
                                Text(row.conditionsMet ? "sharedPlan.conditions.met" : "sharedPlan.conditions.unmet").cyText(.bodyCompact).foregroundStyle(.secondary)
                            }.modifier(SharedPlanSelectionMark(selected: selectedEnding == row.endingKey))
                        }.disabled(model.busy || model.pending != nil).accessibilityIdentifier("sharedPlan.row.\(row.endingKey)")
                    }
                    if p.rows.isEmpty { ContentUnavailableView("sharedPlan.empty", systemImage: "flag.checkered") }
                }
                if let row = p.rows.first(where: { $0.endingKey == selectedEnding }) {
                    Section(row.title) {
                        Text("sharedPlan.ownIntent \(amounts(row.ownIntent, p))")
                        Text(intentStatusKey(row))
                        ForEach(row.confirmed.keys.sorted(), id: \.self) { team in Text("sharedPlan.confirmedTeam \(team) \(amounts(row.confirmed[team] ?? [], p))").cyText(.meta) }
                        if let reason = row.reason { Text(reason).cyText(.meta) }
                        if p.allows(.intent, row: row) {
                            ForEach(row.cost, id: \.itemID) { cost in
                                LabeledContent {
                                    TextField("0–999", text: Binding(
                                        get: { quantities[cost.itemID] ?? "0" }, set: { quantities[cost.itemID] = $0; model.invalidateReview() }))
                                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                        .accessibilityLabel(Text("sharedPlan.pledgeAmount \(name(cost.itemID, p))"))
                                        .disabled(!model.canInteract || !model.writesEnabled)
                                } label: {
                                    VStack(alignment: .leading, spacing: Theme.Space.s1) {
                                        Text(name(cost.itemID, p))
                                        Text("sharedPlan.needCount \(cost.quantity)").cyText(.bodyCompact).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Button(LocalizedStringKey(PlaySharedPlanAction.intent.title)) { prepare(.intent, row: row) }.disabled(!enabled(.intent, p, row))
                            Text("sharedPlan.intent.note").cyText(.meta)
                        }
                        ForEach(rowActions) { action in
                            if p.allows(action, row: row) {
                                Button(LocalizedStringKey(action.title)) { prepare(action, row: row) }.disabled(!enabled(action, p, row))
                                    .accessibilityIdentifier("sharedPlan.action.\(action.rawValue)")
                            }
                        }
                        if row.started, row.operationNodeID != nil {
                            Button("sharedPlan.openTask") { Task { await model.prepareOperation(endingKey: row.endingKey) } }
                                .disabled(!model.canInteract || !model.writesEnabled || !p.team.writable).accessibilityIdentifier("sharedPlan.operation")
                            Text("sharedPlan.openTask.note").cyText(.meta)
                        }
                    }
                }
                Section("sharedPlan.section.vote") {
                    if p.ownVote != .null { Text("sharedPlan.ownVote \(planName(p.ownVote["planKey"].text ?? "", p))"); Text(signatureKey(p.ownVote)) }
                    if p.ownAcceptance != .null {
                        Text("sharedPlan.ownAcceptance \(acceptanceText(p))")
                        Text(signatureKey(p.ownAcceptance))
                    }
                    if let vote = p.consensus[String(p.team.teamID)].text { Text("sharedPlan.consensus \(planName(vote, p))"); Text("sharedPlan.consensus.note").cyText(.meta) }
                    if p.ownRejectedAll { Text("sharedPlan.rejectedAll") }
                    ForEach(globalActions) { action in
                        if p.allows(action) { Button(LocalizedStringKey(action.title)) { prepare(action) }.disabled(!enabled(action, p)) }
                    }
                    if p.allows(.vote) { Button("sharedPlan.rejectRound") { prepare(.vote) }.disabled(!enabled(.vote, p)) }
                    if p.allows(.accept) {
                        Text("sharedPlan.accept.note")
                        ForEach(p.rows.filter { $0.proposalKey != nil }) { row in
                            Toggle(row.title, isOn: Binding(get: { acceptance.contains(row.proposalKey!) }, set: { value in
                                if value { acceptance.insert(row.proposalKey!) } else { acceptance.remove(row.proposalKey!) }; acceptanceDirty = true; model.invalidateReview()
                            })).tint(.green).disabled(!enabled(.accept, p, row))
                        }
                        Button(LocalizedStringKey(PlaySharedPlanAction.accept.title)) { prepare(.accept) }.disabled(!enabled(.accept, p))
                    }
                }
                if p.result != .null { Section("sharedPlan.section.result") { result(p.result, label: "sharedPlan.result.title") } }
            }
        }.cyGroupedSurface()
        .modifier(SharedPlanFormAppearance())
        .privacySensitive()
        .task { await model.load() }
        .onChange(of: model.review) { _, value in offered = value }
        .onChange(of: model.operationTicket) { _, value in shownOperation = value }
        .onChange(of: model.projection) { previous, next in
            if previous?.round != next?.round || !acceptanceDirty {
                acceptance = Set((next?.ownAcceptance["planKeys"].array ?? []).compactMap(\.text)); acceptanceDirty = false
            }
            if previous?.round != next?.round { model.invalidateReview() }
        }
        .cySheet(item: $offered, onDismiss: { model.invalidateReview() }) { review in
            NavigationStack {
                Form {
                    Section(LocalizedStringKey(review.command.action.title)) {
                        Text(LocalizedStringKey(review.title)); Text(LocalizedStringKey(review.command.action.consequence))
                        Text("sharedPlan.round \(review.command.identity.round)").cyText(.meta)
                        reviewChoices(review)
                        Text("sharedPlan.review.note")
                    }
                    Button(role: [.withdraw, .change, .rejectAll, .cancel].contains(review.command.action) ? .destructive : nil) {
                        Task { await model.commit(review); offered = nil }
                    } label: {
                        Text("sharedPlan.confirmAction \(actionTitle(review.command.action))")
                    }.buttonStyle(.borderedProminent).disabled(!model.canInteract || !model.writesEnabled || model.review != review)
                }.cyGroupedSurface().modifier(SharedPlanFormAppearance()).cyPageTitle("sharedPlan.review.title").interactiveDismissDisabled(model.busy)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { offered = nil } } }
            }
            .cyDomainSheet(detents: [.half, .full])
            .themeDomain(.player)
        }
        .cySheet(item: $shownOperation, onDismiss: { Task { await model.closeOperation() } }) { ticket in
            PlaySharedPlanOperationSurface(model: model, ticket: ticket, makeDestination: operationDestination)
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.player)
        }
    }
    private func enabled(_ action: PlaySharedPlanAction, _ p: PlaySharedPlanProjection, _ row: PlaySharedPlanRow? = nil) -> Bool { model.canInteract && model.writesEnabled && p.allows(action, row: row) }
    private func prepare(_ action: PlaySharedPlanAction, row: PlaySharedPlanRow? = nil) {
        let funding = quantities, accepted = acceptance
        Task { await model.prepare(action, endingKey: row?.endingKey, quantities: funding, acceptance: accepted) }
    }
    private func reset() { selectedEnding = nil; quantities = [:]; acceptance = []; acceptanceDirty = false; offered = nil; model.invalidateReview() }
    @ViewBuilder private func reviewChoices(_ review: PlaySharedPlanReview) -> some View {
        let payload = review.command.payload
        if let key = payload["proposalKey"].text {
            LabeledContent("sharedPlan.review.plan", value: planName(key, review.source)).fixedSize(horizontal: false, vertical: true)
        }
        if let choices = payload["proposalKeys"].array {
            let names = choices.compactMap(\.text).map { planName($0, review.source) }
            if names.isEmpty { Text("sharedPlan.review.acceptNone") }
            else { Text("sharedPlan.review.accept \(ListFormatter.localizedString(byJoining: names))").fixedSize(horizontal: false, vertical: true) }
        }
        if let amounts = payload["amounts"].array {
            if amounts.isEmpty { Text("sharedPlan.review.clearIntent") }
            ForEach(Array(amounts.enumerated()), id: \.offset) { _, row in
                if let item = row["itemId"].text, let quantity = row["quantity"].integer {
                    LabeledContent(name(item, review.source), value: "×\(quantity)").monospacedDigit()
                }
            }
        }
    }
    private func actionTitle(_ action: PlaySharedPlanAction) -> String { appLocalized(String.LocalizationValue(action.title), locale: locale) }
    private func name(_ id: String, _ p: PlaySharedPlanProjection) -> String { p.team.items.first { $0.id == id }?.name ?? id }
    private func amounts(_ values: [PlaySharedPlanAmount], _ p: PlaySharedPlanProjection) -> String {
        values.isEmpty ? "—" : ListFormatter.localizedString(byJoining: values.map { "\(name($0.itemID, p)) × \($0.quantity)" })
    }
    private func planName(_ key: String, _ p: PlaySharedPlanProjection) -> String {
        key == "REJECT" ? appLocalized("sharedPlan.rejectRound", locale: locale) : p.rows.first { $0.proposalKey == key }?.title ?? key
    }
    private func acceptanceText(_ p: PlaySharedPlanProjection) -> String {
        let keys = (p.ownAcceptance["planKeys"].array ?? []).compactMap(\.text)
        return keys.isEmpty ? appLocalized("sharedPlan.acceptNone", locale: locale) : ListFormatter.localizedString(byJoining: keys.map { planName($0, p) })
    }
    private func intentStatusKey(_ row: PlaySharedPlanRow) -> LocalizedStringKey {
        if row.ownConfirmed { return "sharedPlan.intent.locked" }
        if row.signatureCurrent { return "sharedPlan.intent.signed" }
        if row.ownIntent.isEmpty { return "sharedPlan.intent.none" }
        return "sharedPlan.intent.captainChanged"
    }
    private func outcomeKey(_ value: String) -> LocalizedStringKey { value == "APPLIED" ? "sharedPlan.outcome.applied" : "sharedPlan.outcome.failed" }
    private func signatureKey(_ value: PlayWireValue) -> LocalizedStringKey { value["ownSignatureCurrent"].bool == true ? "sharedPlan.signature.current" : "sharedPlan.signature.stale" }
    private func phaseKey(_ value: String) -> LocalizedStringKey {
        let known: Set<String> = ["FUNDING", "VOTING", "TIED", "ACCEPTANCE", "CONSENSUS", "SELECTED", "EXECUTED", "FALLBACK"]
        return known.contains(value) ? LocalizedStringKey("sharedPlan.phase." + value) : "sharedPlan.notUpdated"
    }
    private func policyKey(_ value: String) -> LocalizedStringKey {
        let known: Set<String> = ["MAJORITY", "UNANIMOUS", "MAJORITY_ACCEPTANCE"]
        return known.contains(value) ? LocalizedStringKey("sharedPlan.policy." + value) : "sharedPlan.notUpdated"
    }
    @ViewBuilder private func result(_ value: PlayWireValue, label: LocalizedStringKey) -> some View {
        if let title = value["title"].text { Text(title) } else { Text(label) }
        Text(value["summary"].text ?? "")
        Text(value["terminal"].bool == true ? "sharedPlan.result.terminal" : "sharedPlan.result.continue")
    }
}
@MainActor private struct PlaySharedPlanOperationSurface: View {
    let model: PlaySharedPlanLifecycle
    let ticket: PlaySharedPlanOperationTicket
    let makeDestination: (PlaySharedPlanLifecycle, PlaySharedPlanOperationTicket) -> AnyView?
    @Environment(\.dismiss) private var dismiss
    @State private var destination: AnyView?
    var body: some View {
        NavigationStack {
            Group {
                if model.operationIsCurrent(ticket), let destination { destination }
                else { ContentUnavailableView("sharedPlan.task.unavailable", systemImage: "lock", description: Text("sharedPlan.task.unavailable.detail")) }
            }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("sharedPlan.task.back") { dismiss() } } }
        }.task {
            do { try await model.validateOperation(ticket); guard !Task.isCancelled else { return }; destination = makeDestination(model, ticket) }
            catch { destination = nil }
        }
    }
}

/// G04 content appearance only. Native Form/List rows, navigation and disabled
/// controls keep their system behavior; no authority or lifecycle is supplied here.
private struct SharedPlanFormAppearance: ViewModifier {
    @Environment(\.themeDomain) private var domain
    func body(content: Content) -> some View {
        content
            .font(Theme.Font.body)
            .tint(Theme.Color.accent(in: domain))
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bgPage(in: domain))
    }
}

private struct SharedPlanSelectionMark: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s3) {
            content.frame(maxWidth: .infinity, alignment: .leading)
            if selected {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
