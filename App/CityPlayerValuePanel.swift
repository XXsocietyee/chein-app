import SwiftUI

@MainActor enum CityPlayerValueCopy {
    static func text(_ key: String) -> Text { Text(LocalizedStringKey("cityValue." + key), tableName: "CityValue") }
    static func string(_ key: String) -> String { String(localized: String.LocalizationValue("cityValue." + key), table: "CityValue") }
}

@MainActor struct CityPlayerValuePanel: View {
    let model: CityPlayerValueController
    var source: (CityPlayerValueVisit) -> CityPlayerValueNodeRuntime? = { _ in nil }
    @State private var sourceSelection: CityPlayerValueSourceSelection?
    @State private var sourceReturnVisitID: String?
    @Environment(\.scenePhase) private var phase
    @State private var bindReview = false
    @State private var bindTarget: Int64?
    @State private var reason: CityPlayerValueFeedback.Reason = .preferNotToSay
    @State private var rating = 50
    @State private var work: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CityPlayerValueCopy.text("title").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
            CityPlayerValueCopy.text("entryNotice").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            CityPlayerValueCopy.text("currentPageOnly").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            if !model.configured { CityPlayerValueCopy.text("disabled") }
            else {
                if model.busy { CYSkeleton() }
                if let issue = model.issue { CityPlayerValueCopy.text("issue." + issue) }
                ForEach(model.services) { reference in
                    Button { run { await model.select(reference) } } label: {
                        Text(verbatim: model.read.points.first { $0.pointId == reference.pointId }?.title ?? reference.pointId)
                            .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .cyDomainCard(radius: CYRadius.sm, padding: CYSpacing.md)
                    }.buttonStyle(.plain).disabled(model.busy).accessibilityIdentifier("cityValue.select.\(reference.pointId)")
                }
                if model.services.isEmpty && !model.busy && model.issue == nil { CityPlayerValueCopy.text("noServices") }
                if model.canBegin {
                    Button { bindTarget = model.selected?.poiId; bindReview = true } label: { CityPlayerValueCopy.text("bind").frame(maxWidth: .infinity) }
                        .buttonStyle(.cyPrimary(fullWidth: true)).accessibilityIdentifier("cityValue.bind")
                }
                if let visit = model.visit {
                    LabeledContent { CityPlayerValueCopy.text(visit.meaningfulAction == "OBSERVED" ? "observed" : "notObserved") } label: { CityPlayerValueCopy.text("meaningful") }
                    LabeledContent { CityPlayerValueCopy.text(visit.serviceSuccess == "OBSERVED" ? "observed" : "notObserved") } label: { CityPlayerValueCopy.text("success") }
                    CityPlayerValueCopy.text("missingSources").cyText(.bodyCompact)
                    if visit.closed { CityPlayerValueCopy.text("closed") }
                    else if model.canOpenSource {
                        Button {
                            sourceReturnVisitID = visit.visitId
                            sourceSelection = CityPlayerValueSourceSelection(visit: visit)
                        } label: { CityPlayerValueCopy.text("sourceAction") }
                        .accessibilityIdentifier("cityValue.sourceAction")
                    }
                    Button { run { await model.refreshVisit() } } label: { CityPlayerValueCopy.text("refreshVisit") }.disabled(model.busy)
                    if model.canFeedback {
                        Picker(CityPlayerValueCopy.string("reason"), selection: $reason) {
                            ForEach(CityPlayerValueFeedback.Reason.allCases, id: \.self) { value in CityPlayerValueCopy.text("reason." + value.rawValue).tag(value) }
                        }
                        Button { run { await model.feedback(.skip(reason)) } } label: { CityPlayerValueCopy.text("skip") }
                        Button { run { await model.feedback(.exit(reason)) } } label: { CityPlayerValueCopy.text("exit") }
                        if visit.serviceSuccess == "OBSERVED", visit.rating == nil {
                            Stepper(value: $rating, in: 0...100) { Text(verbatim: CityPlayerValueCopy.string("rating") + " \(rating) / 100") }
                            Button { run { await model.feedback(.rating(rating)) } } label: { CityPlayerValueCopy.text("sendRating") }
                        }
                    }
                    if let rating = visit.rating { Text(verbatim: CityPlayerValueCopy.string("rating") + " \(rating) / 100") }
                    if model.canRetryFeedback { Button { run { await model.retryFeedback() } } label: { CityPlayerValueCopy.text("retryExact") } }
                }
                Button { run { await model.load() } } label: { CityPlayerValueCopy.text("refresh") }.disabled(model.busy)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
            .accessibilityIdentifier("cityValue.player")
            .confirmationDialog(CityPlayerValueCopy.string("bindReview"), isPresented: $bindReview, titleVisibility: .visible) {
                Button(CityPlayerValueCopy.string("confirmBind")) { guard model.selected?.poiId == bindTarget else { return }; run { await model.begin() } }
                Button(CityPlayerValueCopy.string("cancel"), role: .cancel) {}
            }
            .cySheet(item: $sourceSelection, onDismiss: {
                guard let visitID = sourceReturnVisitID else { return }; sourceReturnVisitID = nil
                run { await model.sourceClosed(visitID: visitID) }
            }) { selected in Group {
                NavigationStack {
                    CityPlayerValueNodeHost(visit: selected.visit, factory: source)
                        .toolbar { ToolbarItem(placement: .cancellationAction) {
                            Button(CityPlayerValueCopy.string("close")) { sourceSelection = nil }
                        } }
                }
            }.cySheet(detents: [.large]) }
            .task { await model.load() }
            .onChange(of: phase) { _, value in if value != .active { stop() } }
            .onDisappear { stop() }
    }
    private func run(_ action: @escaping @MainActor () async -> Void) { guard phase == .active else { return }; work?.cancel(); work = Task { await action() } }
    private func stop() { bindReview = false; work?.cancel(); work = nil; model.suspend() }
}
