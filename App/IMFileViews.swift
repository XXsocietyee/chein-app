import SwiftUI
import QuickLook
import CryptoKit

@MainActor struct IMFileComposeView: View {
    let owner: IMFileCoordinator
    let current: () -> Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var failed = false
    @State private var revision = 0
    private var available: Bool { current() && owner.isCurrent }
    private var fileSendIsPrimary: Bool {
        guard case .reviewing(.send(let intent)) = owner.expanded.visibleState else { return false }
        if case .file = intent.payload { return true }
        return false
    }
    var body: some View {
        let _ = revision
        Form { fileSections }.imFlowForm().cyHeroScreen().privacySensitive()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { dismiss() } } }
        .fileImporter(isPresented: $picking, allowedContentTypes: IMFilePicker.types, allowsMultipleSelection: false) { result in
            guard available else { return }
            do { let urls = try result.get(); guard urls.count == 1 else { throw IMFileFailure.invalid }; try owner.select(IMFilePicker.read(urls[0])); failed = false }
            catch { failed = true }
        }
        .onAppear { owner.onChange = { revision += 1 }; owner.expanded.onChange = { revision += 1 } }
        .onDisappear { owner.invalidate(); owner.onChange = nil; owner.expanded.onChange = nil; picking = false }
        .onChange(of: available) { _, value in if !value { picking = false; owner.invalidate() } }
        .onChange(of: scenePhase) { _, value in if value != .active { picking = false; owner.invalidate() } }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private var fileSections: some View {
            Section { IMScreenTitle(title: "d7.imFile.title") }
            if !available { IMFlowStateMessage(text: Text("d7.imCompose.unavailable"), symbol: "lock") }
            else {
                Section {
                    switch owner.visibleState {
                    case .empty, .draft:
                        if owner.canUpload {
                            Button { picking = true } label: { Label("d7.imFile.choose", systemImage: "doc.badge.plus") }
                        } else {
                            IMFlowStateMessage(text: Text("d7.imFile.unavailable"), symbol: "doc")
                        }
                        if case .draft(let file) = owner.visibleState {
                            LabeledContent { IMByteCountText(bytes: file.bytes.count) } label: { Text(verbatim: imShownName(file.name)).fixedSize(horizontal: false, vertical: true) }
                            Button("d7.imCompose.upload") { Task { if available { await owner.confirmUpload() } } }.imScreenPrimary(!fileSendIsPrimary)
                            Button("d7.imCompose.discard", role: .destructive) { owner.discardDraft() }
                        }
                    case .uploading: ProgressView("d7.imCompose.uploading")
                    case .unknown:
                        IMFlowStateMessage(text: Text("d7.imCompose.uploadUnknown"), symbol: "clock.arrow.circlepath")
                        if owner.canRecover { Button("d7.imCompose.checkStatus") { Task { await owner.recover() } } }
                        if owner.canUpload { Button("d7.chatInfo.tryAgain") { Task { if available { await owner.uploadUnchanged() } } } }
                    case .held:
                        IMFlowStateMessage(text: Text("d7.imCompose.inReview"), symbol: "clock")
                        if owner.canRecover { Button("d7.imCompose.refresh") { Task { await owner.recover() } } }
                        if owner.service.scanEnabled { Button("d7.imFile.rescan") { Task { if available { await owner.retryScan() } } } }
                    case .rejected:
                        IMFlowStateMessage(text: Text("d7.imFile.rejected"), symbol: "xmark.octagon", tone: .attention)
                        Button("d7.imCompose.discard", role: .destructive) { owner.discardRejected() }
                    case .ready(let file):
                        IMFlowStateMessage(text: Text("d7.imCompose.approved"), symbol: "checkmark.seal", tone: .success)
                        LabeledContent { IMByteCountText(bytes: file.size) } label: { Text(verbatim: imShownName(file.name)).fixedSize(horizontal: false, vertical: true) }
                        if owner.expanded.writer.canSendFile && owner.canRecover {
                            Button("d7.imCompose.continue") { Task { if available { await owner.reviewSend() } } }.imScreenPrimary(!fileSendIsPrimary)
                        }
                    case .closed: IMFlowStateMessage(text: Text("d7.imCompose.unavailable"), symbol: "lock")
                    }
                    if failed { IMFlowStateMessage(text: Text("d7.imFile.readFailed"), symbol: "exclamationmark.circle", tone: .attention) }
                }
                Section {
                    switch owner.expanded.visibleState {
                    case .reviewing(.send(let intent)):
                        if case .file = intent.payload {
                            IMMutationSummary(mutation: .send(intent))
                            Button("d7.imFile.send") { Task { if available { await owner.expanded.confirm() } } }.imScreenPrimary()
                            Button("action.cancel", role: .cancel) { owner.expanded.cancelReview() }
                        }
                    case .submitting: ProgressView("d7.imCompose.sending")
                    case .outcomeUnknown(.send(let intent)), .rejected(.send(let intent)):
                        if case .file = intent.payload {
                            IMFlowStateMessage(text: Text("d7.imCompose.sendUnknown"), symbol: "clock.arrow.circlepath")
                            if owner.expanded.canRecoverFile {
                                Button("d7.imCompose.checkSent") { Task { if available { await owner.expanded.recoverFile() } } }
                            }
                            Button("d7.chatInfo.tryAgain") { Task { if available { await owner.expanded.retryUnchanged() } } }
                        }
                    case .acknowledged(.sent(let message)):
                        if IMFileReference.read(message) != nil {
                            IMFlowStateMessage(text: Text("d7.imFile.sent"), symbol: "checkmark.circle", tone: .success)
                            Button("d7.imCompose.done") { owner.finishAcknowledged() }
                        }
                    default: EmptyView()
                    }
                }
            }
        }
}

@MainActor struct IMFilePreviewView: View {
    let message: MessagingMessage
    let owner: IMFileCoordinator
    let current: () -> Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var file: URL?
    @State private var generation = UUID()
    @State private var loading = false
    @State private var failed = false
    @State private var monitor: Task<Void, Never>?
    @State private var expiry: Task<Void, Never>?
    @ScaledMetric(relativeTo: .title) private var previewHeight: CGFloat = 360
    private var available: Bool { current() && owner.isCurrent && message.conversationID == owner.scope.conversationID && IMFileReference.read(message) != nil }
    var body: some View {
        Form { previewSections }.imFlowForm().privacySensitive().cyHeroScreen()
        .onDisappear { stop() }
        .onChange(of: available) { _, value in if !value { stop() } }
        .onChange(of: scenePhase) { _, value in if value != .active { stop() } }
        .onReceive(NotificationCenter.default.publisher(for: IMFileCoordinator.consumptionRetiredNotification)) { event in
            if let retired = event.object as? IMFileCoordinator, retired === owner { stop() }
        }
    }
    @ViewBuilder private var previewSections: some View {
            Section { IMScreenTitle(title: "d7.imFile.previewTitle") }
            if let reference = IMFileReference.read(message), available {
                Section {
                    LabeledContent { IMByteCountText(bytes: reference.size) } label: {
                        Label { Text(verbatim: imShownName(reference.name)).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "doc") }
                    }
                    if owner.service.previewEnabled && owner.service.previewStatusEnabled && file == nil {
                        Button { load() } label: { Label("d7.imFile.open", systemImage: "eye") }.imScreenPrimary().disabled(loading)
                    }
                }
                if let file {
                    Section {
                        IMFileNativePreview(url: file).id(generation)
                            .frame(maxWidth: .infinity, minHeight: previewHeight)
                            .listRowInsets(EdgeInsets())
                            .accessibilityLabel(Text("d7.imFile.previewTitle"))
                        Button { stop() } label: { Label("d7.imFile.closePreview", systemImage: "xmark.circle") }
                    }
                }
            } else { IMFlowStateMessage(text: Text("d7.imFile.messageUnavailable"), symbol: "lock") }
            if loading { ProgressView("d7.imCompose.loading") }
            if failed { IMFlowStateMessage(text: Text("d7.imFile.previewFailed"), symbol: "exclamationmark.circle", tone: .attention) }
        }
    private func load() {
        guard available, !loading else { return }
        stop(); let stamp = generation; loading = true; failed = false
        Task { @MainActor in
            do {
                let result = try await owner.service.preview(message: message, scope: owner.scope)
                guard available, generation == stamp, !Task.isCancelled else { return }
                // Extension comes from the server's detected, scanned and reviewed source, not an arbitrary URL.
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(result.reference.ext)
                try result.bytes.write(to: url, options: [.atomic, .completeFileProtection])
                guard QLPreviewController.canPreview(url as NSURL) else { try? FileManager.default.removeItem(at: url); throw IMFileFailure.unsupported }
                guard available, generation == stamp, ContinuousClock.now < result.deadline else { try? FileManager.default.removeItem(at: url); throw IMFileFailure.linkExpired }
                file = url; loading = false
                expiry = Task { @MainActor in
                    do { try await ContinuousClock().sleep(until: result.deadline) } catch { return }
                    guard generation == stamp else { return }; stop(); failed = true
                }
                monitor = Task { @MainActor in
                    while !Task.isCancelled, generation == stamp {
                        do {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                            guard generation == stamp else { return }
                            guard available else { throw IMFileFailure.stale }
                            try await owner.service.authorizePreview(message: message, scope: owner.scope)
                            guard generation == stamp else { return }
                            guard available, !Task.isCancelled else { throw IMFileFailure.stale }
                        } catch { guard generation == stamp else { return }; stop(); failed = true; return }
                    }
                }
            } catch { guard generation == stamp else { return }; stop(); failed = true }
        }
    }
    private func stop() {
        generation = UUID(); monitor?.cancel(); monitor = nil; expiry?.cancel(); expiry = nil; loading = false
        if let file { try? FileManager.default.removeItem(at: file) }; file = nil
    }
}

/// System document preview, never a WebView, external application launch, macro runner or archive extraction.
@MainActor private struct IMFileNativePreview: UIViewControllerRepresentable {
    let url: URL
    final class Source: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(_ url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
    func makeCoordinator() -> Source { Source(url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let view = QLPreviewController(); view.dataSource = context.coordinator; return view
    }
    func updateUIViewController(_ view: QLPreviewController, context: Context) { context.coordinator.url = url; view.reloadData() }
}
