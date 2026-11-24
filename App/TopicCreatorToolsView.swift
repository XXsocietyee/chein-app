import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// G3 creator tools for one owned topic, the parts of `pages/publish/fabu`, `pages/member` and the
/// host workbench a creator sees: play window and prep items, route names, the attribute registry,
/// cloud-draft readback and publish, the topic share code, the host QR, invite chapters, and
/// PERK/TRAFFIC station terms. The paid REVSHARE tier and merchant-only actions are not shown.
@MainActor final class TopicCreatorToolsModel: ObservableObject {
    let service: TopicCreatorEditorService
    let topicID: Int64
    private let defaults: UserDefaults
    private let ownerKey: String
    @Published private(set) var detail: TopicAuthorDetail?
    @Published var setup = TopicPlaySetup(window: TopicPlayWindow(mode: .any), prepItems: [])
    @Published private(set) var stateKeys: [TopicStateKeyRow] = []
    @Published private(set) var registry: TopicAttributeRegistry?
    @Published private(set) var chapters: [TopicInviteChapter] = []
    @Published private(set) var shareCodeURL: String?
    @Published private(set) var hostQRURL: String?
    @Published private(set) var publishReceipt: TopicPublishReceipt?
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    /// True when the last publish result is unknown; retrying reuses the same request id.
    @Published private(set) var publishUnknown = false

    init(service: TopicCreatorEditorService, topicID: Int64, ownerKey: String, defaults: UserDefaults = .standard) {
        self.service = service; self.topicID = topicID; self.ownerKey = ownerKey; self.defaults = defaults
        publishUnknown = defaults.string(forKey: publishKey) != nil
    }

    private var publishKey: String { "creatorEditor.publishRequest.\(ownerKey).\(topicID)" }

    func load() async {
        await run {
            self.detail = try await self.service.authorEditDetail(topicID: self.topicID)
        }
        if let setup = try? await service.playSetup(topicID: topicID) { self.setup = setup }
        if let keys = try? await service.stateKeys(topicID: topicID) { stateKeys = keys }
        if let rows = try? await service.inviteChapters(topicID: topicID) { chapters = rows }
    }

    func savePlaySetup() async {
        if setup.window.mode == .custom {
            setup.window.start = setup.window.start ?? TopicPlayWindow.starts[0]
            setup.window.end = setup.window.end ?? TopicPlayWindow.ends[0]
        }
        await run { try await self.service.savePlaySetup(topicID: self.topicID, setup: self.setup) }
    }

    func createKey(kind: String, label: String) async {
        await run {
            _ = try await self.service.createNamedStateKey(topicID: self.topicID, kind: kind, label: label)
            self.stateKeys = try await self.service.stateKeys(topicID: self.topicID)
        }
    }

    func rename(_ row: TopicStateKeyRow, to label: String) async {
        await run {
            try await self.service.renameStateKey(topicID: self.topicID, row: row, label: label)
            self.stateKeys = try await self.service.stateKeys(topicID: self.topicID)
        }
    }

    func loadRegistry() async {
        guard let version = detail?.configVersion else { message = "creatorEditor.registry.saveFirst"; return }
        await run { self.registry = try await self.service.attributeBinding(topicID: self.topicID, configVersion: version) }
    }

    func loadShareCode() async { await run { self.shareCodeURL = try await self.service.shareCode(topicID: self.topicID) } }
    func loadHostQR() async { await run { self.hostQRURL = try await self.service.hostQRCode(topicID: self.topicID) } }

    func saveTerms(chapterID: Int64, mode: TopicChapterSupplyTerms.Mode, maxMerchant: Int, perkMinValue: String) async {
        await run {
            let value = perkMinValue.trimmingCharacters(in: .whitespaces)
            try await self.service.saveSupplyTerms(try TopicChapterSupplyTerms(chapterID: chapterID, mode: mode,
                maxMerchant: maxMerchant, perkMinValue: value.isEmpty ? nil : value))
            self.message = "creatorEditor.terms.saved"
        }
    }

    /// Server draft publish: read back the saved draft, then publish that version with a request id
    /// written down before the request leaves, as `_publishAttempt` is.
    func publish() async {
        guard detail?.isDraft == true else { return }
        await run {
            let saved = try await self.service.authorSavedDetail(topicID: self.topicID)
            let requestID = self.defaults.string(forKey: self.publishKey) ?? Self.makeRequestID()
            self.defaults.set(requestID, forKey: self.publishKey)
            do {
                self.publishReceipt = try await self.service.publishDraft(topicID: self.topicID, configVersion: saved.configVersion,
                    registryVersion: Self.registryVersion(saved.journeyRules), publishRequestID: requestID)
                self.defaults.removeObject(forKey: self.publishKey); self.publishUnknown = false
                self.detail = try? await self.service.authorEditDetail(topicID: self.topicID)
            } catch TopicCreatorEditorIssue.outcomeUnknown {
                self.publishUnknown = true
                throw TopicCreatorEditorIssue.outcomeUnknown
            } catch {
                self.defaults.removeObject(forKey: self.publishKey); self.publishUnknown = false
                throw error
            }
        }
    }

    static func makeRequestID() -> String {
        "pub" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(37)
    }

    /// `journeyRules.attributeBinding.registryVersion`, sent only when the rules bind the registry.
    static func registryVersion(_ rules: String?) -> String? {
        guard let data = rules?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let binding = object["attributeBinding"] as? [String: Any],
              let version = binding["registryVersion"] as? String,
              version.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil else { return nil }
        return version
    }

    private func run(_ body: @escaping () async throws -> Void) async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await body() } catch { message = Self.messageKey(error) }
    }

    static func messageKey(_ error: Error) -> String {
        switch error as? TopicCreatorEditorIssue {
        case .rejected(let text): return text
        case .outcomeUnknown: return "creatorEditor.issue.unknown"
        case .unauthorized: return "creatorEditor.issue.signIn"
        case .disabled: return "creatorEditor.issue.disabled"
        default: return "creatorEditor.issue.unavailable"
        }
    }
}

/// Toolbar entry on an owned topic in the personal creator list. The merchant entry passes a scope
/// and gets nothing: merchant-only workbench parts stay hidden.
@MainActor struct TopicCreatorToolsToolbar: View {
    @ObservedObject var session: AppSession
    let topicID: Int
    let entryScope: String?
    var body: some View {
        if entryScope == nil, topicID > 0, let service = CreatorEditorProduction.topicEditor(session: session),
           let account = session.currentRuntimeDependencyContext?.session.accountID {
            NavigationLink {
                TopicCreatorToolsView(model: TopicCreatorToolsModel(service: service, topicID: Int64(topicID), ownerKey: String(account)))
            } label: {
                Label { Text("creatorEditor.title", tableName: "CreatorEditorUI") } icon: { Image(systemName: "slider.horizontal.3") }
            }
            .accessibilityIdentifier("creatorEditor.entry")
        }
    }
}

@MainActor struct TopicCreatorToolsView: View {
    @Environment(\.analyticsEventClient) private var analytics
    @StateObject var model: TopicCreatorToolsModel
    @Environment(\.locale) private var locale
    @State private var newKeyLabel = ""
    @State private var newKeyKind = "clue"
    @State private var renaming: TopicStateKeyRow?
    @State private var renameText = ""
    @State private var newPrep = ""
    @State private var termsChapter: Int64?
    @State private var termsMode = TopicChapterSupplyTerms.Mode.perk
    @State private var termsMax = 0
    @State private var termsPerk = ""
    @State private var toastMessage: String?

    var body: some View {
        Form {
            if let message = model.message {
                Section { Text(LocalizedStringKey(message), tableName: "CreatorEditorUI").foregroundStyle(.secondary) }
                    .accessibilityIdentifier("creatorEditor.message")
            }
            draftSection
            playSetupSection
            stateKeySection
            registrySection
            shareSection
            chaptersSection
        }
        .navigationTitle(Text("creatorEditor.title", tableName: "CreatorEditorUI")).navigationBarTitleDisplayMode(.inline)
        .disabled(model.busy)
        .task { await model.load() }
        .refreshable { await model.load() }
        .cyPromptModalOverlay(
            isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
            title: String(localized: LocalizedStringResource("creatorEditor.keys.rename", table: "CreatorEditorUI", locale: locale)),
            text: $renameText,
            placeholder: String(localized: LocalizedStringResource("creatorEditor.keys.name", table: "CreatorEditorUI", locale: locale)),
            validationMessage: renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? MerchantAreaCopy.text("请输入名称", "Enter a name", locale)
                : nil,
            cancelTitle: String(localized: LocalizedStringResource("creatorEditor.cancel", table: "CreatorEditorUI", locale: locale)),
            confirmTitle: String(localized: LocalizedStringResource("creatorEditor.save", table: "CreatorEditorUI", locale: locale)),
            onCancel: { renaming = nil },
            onConfirm: {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if let row = renaming {
                    Task { await model.rename(row, to: renameText) }
                }
                renaming = nil
                toastMessage = MerchantCloseCopy.text("已重命名", "Renamed", locale)
            }
        )
        .cyToast(verbatimMessage: $toastMessage)
        .cyDomainScreen(.topicEditor)
    }

    @ViewBuilder private var draftSection: some View {
        Section {
            if let detail = model.detail {
                LabeledContent { Text(verbatim: detail.name) } label: { Text("creatorEditor.draft.name", tableName: "CreatorEditorUI") }
                LabeledContent { Text(verbatim: String(detail.chapterCount)) } label: { Text("creatorEditor.draft.chapters", tableName: "CreatorEditorUI") }
                if detail.isDraft {
                    Button {
                        let topicName = model.detail?.name
                        let hadReceipt = model.publishReceipt != nil
                        Task {
                            await model.publish()
                            guard !hadReceipt, model.publishReceipt != nil else { return }
                            var properties: [String: PlayWireValue] = [:]
                            if let topicName { properties["name"] = .string(topicName) }
                            MiniProgramAnalytics.track(analytics, "topic_publish_success", bizType: "topic",
                                bizID: MiniProgramAnalytics.bizID(Int(exactly: model.topicID)), pagePath: "/pages/publish/fabu/index", properties: properties)
                        }
                    } label: {
                        if model.publishUnknown { Text("creatorEditor.publish.retry", tableName: "CreatorEditorUI") }
                        else { Text("creatorEditor.publish", tableName: "CreatorEditorUI") }
                    }.accessibilityIdentifier("creatorEditor.publish")
                } else {
                    Text("creatorEditor.draft.published", tableName: "CreatorEditorUI").foregroundStyle(.secondary)
                }
                if let receipt = model.publishReceipt {
                    if let state = receipt.reviewState { LabeledContent { Text(verbatim: state) } label: { Text("creatorEditor.publish.review", tableName: "CreatorEditorUI") } }
                    if let revision = receipt.contentRevisionNo { LabeledContent { Text(verbatim: "#" + revision) } label: { Text("creatorEditor.publish.revision", tableName: "CreatorEditorUI") } }
                }
            } else if model.busy {
                ProgressView()
            }
        } header: { Text("creatorEditor.draft", tableName: "CreatorEditorUI") }
    }

    @ViewBuilder private var playSetupSection: some View {
        Section {
            Picker(selection: $model.setup.window.mode) {
                ForEach(TopicPlayWindow.Mode.allCases, id: \.self) { mode in
                    Text(LocalizedStringKey("creatorEditor.window." + mode.rawValue), tableName: "CreatorEditorUI").tag(mode)
                }
            } label: { Text("creatorEditor.window", tableName: "CreatorEditorUI") }
            if model.setup.window.mode == .custom {
                Picker(selection: Binding(get: { model.setup.window.start ?? TopicPlayWindow.starts[0] }, set: { model.setup.window.start = $0 })) {
                    ForEach(TopicPlayWindow.starts, id: \.self) { Text(verbatim: $0).tag($0) }
                } label: { Text("creatorEditor.window.start", tableName: "CreatorEditorUI") }
                Picker(selection: Binding(get: { model.setup.window.end ?? TopicPlayWindow.ends[0] }, set: { model.setup.window.end = $0 })) {
                    ForEach(TopicPlayWindow.ends, id: \.self) { Text(verbatim: $0).tag($0) }
                } label: { Text("creatorEditor.window.end", tableName: "CreatorEditorUI") }
            }
            ForEach(Array(model.setup.prepItems.enumerated()), id: \.offset) { _, item in Text(verbatim: item) }
                .onDelete { model.setup.prepItems.remove(atOffsets: $0) }
            if model.setup.prepItems.count < TopicPlaySetup.maximumPrepItems {
                HStack {
                    TextField(text: $newPrep) { Text("creatorEditor.prep.add", tableName: "CreatorEditorUI") }
                    Button {
                        let item = newPrep.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !item.isEmpty { model.setup.prepItems.append(item); newPrep = "" }
                    } label: { Image(systemName: "plus.circle") }.accessibilityLabel(Text("creatorEditor.prep.add", tableName: "CreatorEditorUI"))
                }
            }
            Button { Task { await model.savePlaySetup() } } label: { Text("creatorEditor.save", tableName: "CreatorEditorUI") }
                .accessibilityIdentifier("creatorEditor.playSetup.save")
        } header: { Text("creatorEditor.playSetup", tableName: "CreatorEditorUI") }
    }

    @ViewBuilder private var stateKeySection: some View {
        Section {
            ForEach(model.stateKeys, id: \.id) { row in
                Button { renameText = row.label; renaming = row } label: {
                    LabeledContent { Image(systemName: "pencil").accessibilityHidden(true) } label: { Text(verbatim: row.label.isEmpty ? row.id : row.label) }
                }
            }
            Picker(selection: $newKeyKind) {
                Text("creatorEditor.keys.clue", tableName: "CreatorEditorUI").tag("clue")
                Text("creatorEditor.keys.tag", tableName: "CreatorEditorUI").tag("tag")
            } label: { Text("creatorEditor.keys.kind", tableName: "CreatorEditorUI") }
            HStack {
                TextField(text: $newKeyLabel) { Text("creatorEditor.keys.name", tableName: "CreatorEditorUI") }
                Button {
                    let label = newKeyLabel; newKeyLabel = ""
                    Task { await model.createKey(kind: newKeyKind, label: label) }
                } label: { Text("creatorEditor.keys.create", tableName: "CreatorEditorUI") }
                .disabled(newKeyLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: { Text("creatorEditor.keys", tableName: "CreatorEditorUI") }
    }

    @ViewBuilder private var registrySection: some View {
        Section {
            Button { Task { await model.loadRegistry() } } label: { Text("creatorEditor.registry.read", tableName: "CreatorEditorUI") }
            if let registry = model.registry {
                LabeledContent { Text(verbatim: registry.registryVersion) } label: { Text("creatorEditor.registry.version", tableName: "CreatorEditorUI") }
                ForEach(registry.definitions, id: \.stateKey) { row in
                    LabeledContent { Text(verbatim: "\(row.minValue)…\(row.maxValue) · \(row.initialValue)") } label: { Text(verbatim: row.label.isEmpty ? row.stateKey : row.label) }
                }
            }
        } header: { Text("creatorEditor.registry", tableName: "CreatorEditorUI") }
    }

    @ViewBuilder private var shareSection: some View {
        Section {
            Button { Task { await model.loadShareCode() } } label: { Text("creatorEditor.share.code", tableName: "CreatorEditorUI") }
            if let url = model.shareCodeURL { codeImage(url).accessibilityIdentifier("creatorEditor.share.image") }
            Button { Task { await model.loadHostQR() } } label: { Text("creatorEditor.share.host", tableName: "CreatorEditorUI") }
            if let url = model.hostQRURL { codeImage(url).accessibilityIdentifier("creatorEditor.host.image") }
        } header: { Text("creatorEditor.share", tableName: "CreatorEditorUI") }
    }

    @ViewBuilder private var chaptersSection: some View {
        if !model.chapters.isEmpty {
            Section {
                Picker(selection: $termsChapter) {
                    Text("creatorEditor.terms.pick", tableName: "CreatorEditorUI").tag(Int64?.none)
                    ForEach(model.chapters, id: \.id) { chapter in Text(verbatim: chapter.name).tag(Int64(chapter.id)) }
                } label: { Text("creatorEditor.terms.chapter", tableName: "CreatorEditorUI") }
                if let chapter = termsChapter {
                    Picker(selection: $termsMode) {
                        Text("creatorEditor.terms.perk", tableName: "CreatorEditorUI").tag(TopicChapterSupplyTerms.Mode.perk)
                        Text("creatorEditor.terms.traffic", tableName: "CreatorEditorUI").tag(TopicChapterSupplyTerms.Mode.traffic)
                    } label: { Text("creatorEditor.terms.mode", tableName: "CreatorEditorUI") }.pickerStyle(.segmented)
                    Stepper(value: $termsMax, in: 0...99) {
                        LabeledContent { Text(verbatim: String(termsMax)) } label: { Text("creatorEditor.terms.max", tableName: "CreatorEditorUI") }
                    }
                    if termsMode == .perk {
                        TextField(text: $termsPerk) { Text("creatorEditor.terms.perkMin", tableName: "CreatorEditorUI") }.keyboardType(.decimalPad)
                    }
                    Button { Task { await model.saveTerms(chapterID: chapter, mode: termsMode, maxMerchant: termsMax, perkMinValue: termsPerk) } } label: {
                        Text("creatorEditor.save", tableName: "CreatorEditorUI")
                    }.accessibilityIdentifier("creatorEditor.terms.save")
                }
            } header: { Text("creatorEditor.chapters", tableName: "CreatorEditorUI") } footer: {
                Text("creatorEditor.terms.footer", tableName: "CreatorEditorUI")
            }
        }
    }

    private func codeImage(_ raw: String) -> some View {
        AsyncImage(url: URL(string: raw).flatMap { $0.scheme == "https" ? $0 : nil }) { image in
            image.resizable().scaledToFit()
        } placeholder: { ProgressView() }
        .frame(maxWidth: 220, maxHeight: 220).frame(maxWidth: .infinity)
        .accessibilityLabel(Text("creatorEditor.share.image", tableName: "CreatorEditorUI"))
    }
}
