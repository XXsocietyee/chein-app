import Foundation
import SwiftUI

@MainActor struct NativeWebhookInboundLogView: View {
    @ObservedObject var model: NativeWebhookViewModel
    @State private var filter: NativeWebhookInboundState?
    var body: some View {
        List {
            CYHeroHeader(verbatim: nativeWebhookLocalized("d7.webhook.inbound.title"))
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if let coordinator = model.coordinator, model.available, coordinator.selected != nil {
                Section {
                    Picker(nativeWebhookLocalized("d7.webhook.field.status"), selection: $filter) {
                        Text(nativeWebhookLocalized("d7.webhook.filter.all")).tag(Optional<NativeWebhookInboundState>.none)
                        ForEach(NativeWebhookInboundState.allCases, id: \.rawValue) { state in
                            Text(nativeWebhookInboundText(state)).tag(Optional(state))
                        }
                    }
                    .disabled(coordinator.busy).accessibilityIdentifier("webhook.inboundLogs.filter")
                }
                NativeWebhookStatusSection(model: model)
                Section {
                    if coordinator.inboundLogs.isEmpty && !coordinator.busy {
                        CYEmptyState(systemImage: "tray", LocalizedStringKey(nativeWebhookLocalized("d7.webhook.inbound.empty")))
                            .accessibilityIdentifier("webhook.inboundLogs.empty")
                    }
                    ForEach(coordinator.inboundLogs) { log in
                        VStack(alignment: .leading, spacing: Theme.Space.s2) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(nativeWebhookInboundText(log.state), systemImage: log.state == .unknown ? "clock.arrow.circlepath" : "arrow.down.doc")
                                    .cyText(.sectionTitle)
                                Spacer(minLength: Theme.Space.s2)
                                if let time = log.createdAt {
                                    Text(time.date, format: .dateTime.month().day().hour().minute()).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            if let code = log.reason { LabeledContent(nativeWebhookLocalized("d7.webhook.field.reason"), value: code) }
                            if let time = log.createTime { NativeWebhookTimeRow(label: nativeWebhookLocalized("d7.webhook.inbound.postedAt"), time: time) }
                        }
                        .padding(.vertical,Theme.Space.s2)
                        .accessibilityIdentifier("webhook.inbound.\(log.id.rawValue)")
                    }
                    if coordinator.hasMoreLogs {
                        CYPillButton(verbatim: nativeWebhookLocalized("d7.webhook.loadMore"), style: .secondary) { Task { await read(nextPage: true) } }
                            .disabled(coordinator.busy).accessibilityIdentifier("webhook.inboundLogs.more")
                    }
                }
                Section {
                    CYPillButton(verbatim: nativeWebhookLocalized("d7.webhook.reload"), style: .secondary) { Task { await read() } }
                        .disabled(coordinator.busy).accessibilityIdentifier("webhook.inboundLogs.refresh")
                }
            } else {
                CYEmptyState(systemImage: "exclamationmark.circle", LocalizedStringKey(nativeWebhookLocalized("d7.webhook.detail.loadFailed")), detail: LocalizedStringKey(nativeWebhookLocalized("d7.webhook.goBack")))
            }
        }
        .nativeChannelFlowPage()
        .cyHeroScreen()
        .task { await read() }
        .onChange(of: filter) { _, _ in Task { await read() } }
        .refreshable { await read() }
        .accessibilityIdentifier("webhook.inboundLogs")
    }
    private func read(nextPage: Bool = false) async {
        await model.coordinator?.logs(nextPage: nextPage, inboundFilter: filter)
    }
}
