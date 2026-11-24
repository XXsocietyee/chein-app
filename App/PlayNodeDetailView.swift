import SwiftUI

@MainActor
struct PlayNodeDetailView: View {
    let nodeID: Int
    let model: PlayViewModel
    @State private var answer = ""
    @StateObject private var reviewOwner: PlayAnswerReviewPresentation
    @State private var answerReviewIssue: PlayLoadIssue?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.externalGameSession) private var externalGameSession
    @State private var extGameStore = ExternalGameStore()
    @State private var extReviewModel: ExternalGameReviewModel?
    @State private var launchingExtGame: InstalledExternalGame?
    @State private var isLaunchingExtGame = false
    @State private var extGameIssue: String?
    init(nodeID: Int, model: PlayViewModel) {
        self.nodeID = nodeID; self.model = model
        _reviewOwner = StateObject(wrappedValue: PlayAnswerReviewPresentation(model: model))
    }
    var body: some View {
        Group {
            if model.reader.identity == nil {
                PlayIssueView(issue: .init(APIError.unauthorized))
            } else if model.isLoading {
                CYSkeleton().padding(CYSpacing.pageHorizontal).accessibilityLabel(Text("play.loading"))
            } else if let issue = model.visibleIssue {
                VStack {
                    if let receipt = model.visibleReceipt { PlayReceiptView(receipt: receipt).padding() }
                    PlayIssueView(issue: issue) { Task { await model.load(keepingReceipt: true) } }
                }
            } else if let snapshot = model.visibleSnapshot,
                      snapshot.availability != .registrationRequired,
                      let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }) {
                detail(node, snapshot: snapshot)
            } else {
                CYEmptyState(systemImage: "lock", "play.node.unavailable", detail: "play.node.unavailable.detail")
            }
        }
        .privacySensitive()
        .appNavigationTitle("play.node.title")
        .navigationBarTitleDisplayMode(.inline)
        .background { PlayAnswerReviewRoot(owner: reviewOwner).frame(width: 0, height: 0) }
        .background {
            if let offered = reviewOwner.review {
                PlayAnswerReviewPresenter(owner: reviewOwner, offered: offered).id(offered.id)
            }
        }
        .onAppear { reviewOwner.appear(active: scenePhase == .active) }
        .onDisappear { reviewOwner.disappear(); if !reviewOwner.hasVisibleVisit { answer = "" } }
        .onChange(of: scenePhase) { _, value in reviewOwner.sceneChanged(active: value == .active) }
        .onChange(of: model.reader.identity) { _, _ in reviewOwner.reset(); answer = "" }
        .onChange(of: nodeID) { _, _ in reviewOwner.reset(); answer = "" }
        .onChange(of: model.visibleSnapshot) { _, _ in answer = ""; answerReviewIssue = nil; reviewOwner.discardInvalidUnclaimedReview() }
        .onChange(of: reviewOwner.readGeneration) { _, _ in reviewOwner.discardInvalidUnclaimedReview() }
        .sheet(isPresented: Binding(get: { launchingExtGame != nil }, set: { if !$0 { launchingExtGame = nil } })) {
            if let game = launchingExtGame {
                ExternalGameRunnerSheet(
                    store: extGameStore,
                    game: game,
                    session: externalGameSession,
                    review: ensuredExtModel(),
                    nodeContext: ExternalGameNodePlayContext(nodeID: nodeID, topicID: nil, activityID: nil),
                    onResultSubmitted: { outcome in
                        if outcome.nodeCompleted {
                            Task { await model.load(keepingReceipt: true) }
                        }
                    }
                )
            }
        }
    }

    private func ensuredExtModel() -> ExternalGameReviewModel {
        if let extReviewModel { return extReviewModel }
        let m = ExternalGameReviewModel(store: extGameStore)
        extReviewModel = m
        return m
    }

    private func launchBoundExternalGame(_ gameID: String) async {
        guard !isLaunchingExtGame else { return }
        isLaunchingExtGame = true
        extGameIssue = nil
        defer { isLaunchingExtGame = false }
        let rm = ensuredExtModel()
        if let installed = extGameStore.installedGames.first(where: { $0.manifest.id == gameID }) {
            launchingExtGame = installed
            return
        }
        await rm.install(gameID: gameID, session: externalGameSession)
        if let installed = extGameStore.installedGames.first(where: { $0.manifest.id == gameID }) {
            launchingExtGame = installed
        } else {
            extGameIssue = rm.notice.isEmpty ? W8Text.t("无法下载或解锁此游戏。", "Could not load external game.") : rm.notice
        }
    }
    private func detail(_ node: PlayNode, snapshot: PlaySnapshot) -> some View {
        let availability = snapshot.answerAvailability(for: node)
        let selectedAnswer = model.acceptedChoice(for: nodeID) ?? answer
        let offeredAnswer = reviewOwner.capture(nodeID: nodeID)
        return Form {
            Section {
                PlayStationArtwork(image: PlayStationImageResolver.station(for: node, in: snapshot.result), title: node.name ?? "")
                    .accessibilityIdentifier("play.node.artwork")
                if let name = node.name, !name.isEmpty { Text(verbatim: name).cyText(.display).foregroundStyle(CYColor.textPrimary) }
                else { Text("play.node.untitled").cyText(.display).foregroundStyle(CYColor.textPrimary) }
                if node.addressHidden != true, let address = node.address, !address.isEmpty {
                    Label { Text(verbatim: address) } icon: { Image(systemName: "mappin.and.ellipse") }
                }
                CYStatusChip(LocalizedStringKey(snapshot.isDone(node) ? "play.node.completed" : snapshot.isLocked(node) ? "play.node.locked" : "play.node.open"),
                             tone: snapshot.isDone(node) ? .success : snapshot.isLocked(node) ? (node.weatherLocked == true ? .warning : .neutral) : .info,
                             systemImage: nodeStatusIcon(snapshot: snapshot, node: node).systemImage)
                    .accessibilityIdentifier("play.node.status")
                if !snapshot.isDone(node), snapshot.isLocked(node), node.weatherLocked == true {
                    CYStatusChip(
                        verbatim: CoreLoopCopy(locale: locale).t("需天气/时段条件解锁", "Weather Condition Gate"),
                        tone: .warning,
                        systemImage: "cloud.sun.rain.fill"
                    )
                    .accessibilityIdentifier("play.node.weatherLocked")
                }
                if let reason = snapshot.lockReason(node), !reason.isEmpty { Text(verbatim: reason) }
                if let note = snapshot.result.timeNote, snapshot.availability != .active, !note.isEmpty { Text(verbatim: note) }
                if let hours = node.businessTime, !hours.isEmpty { LabeledContent("play.businessTime") { Text(verbatim: hours) } }
                if let open = node.openStatus, !open.isEmpty { LabeledContent("play.openStatus") { Text(verbatim: open) } }
            }
            if snapshot.isStoryLocked(node) {
                Section {
                    CYStatusChip("playFree.story.locked", tone: .neutral, systemImage: "lock.fill")
                        .accessibilityLabel(Text("playFree.story.locked.a11y"))
                    Text("playFree.story.lockedCard").font(.subheadline)
                }
            } else if !snapshot.isLocked(node) {
                if let story = node.storyText, !story.isEmpty { Section("play.story") { Text(verbatim: story) } }
                if let description = node.description, !description.isEmpty { Section("play.description") { Text(verbatim: description) } }
                if let title = node.gameTitle, !title.isEmpty {
                    Section("play.task") {
                        Text(verbatim: title).cyText(.cardTitle)
                        if let rules = node.ruleInstructions, !rules.isEmpty { Text(verbatim: rules) }
                        if let materials = node.requiredMaterials, !materials.isEmpty { LabeledContent("play.materials") { Text(verbatim: materials) } }
                        if let duration = node.durationMinutes { LabeledContent("play.duration") { Text(verbatim: String(duration)) } }
                        if let players = node.players, !players.isEmpty { LabeledContent("play.players") { Text(verbatim: players) } }
                        if let difficulty = node.difficulty, !difficulty.isEmpty { LabeledContent("play.difficulty") { Text(verbatim: difficulty) } }
                    }
                }
                if let ext = node.externalGame {
                    Section(W8Text.t("节点挑战小游戏", "Node External Game")) {
                        Text(verbatim: ext.gameName ?? ext.gameID).cyText(.cardTitle)
                            .accessibilityIdentifier("play.node.externalGame.title")
                        if let minScore = ext.minScore, minScore > 0 {
                            Text(verbatim: W8Text.t("通关要求：得分 ≥ \(minScore)", "Min score: \(minScore)"))
                                .cyText(.meta)
                        }
                        if let extGameIssue {
                            Text(verbatim: extGameIssue).cyText(.meta).foregroundStyle(.red)
                        }
                        Button(isLaunchingExtGame ? W8Text.t("正在准备小游戏...", "Loading game...") : W8Text.t("启动外部小游戏", "Launch External Game")) {
                            Task { await launchBoundExternalGame(ext.gameID) }
                        }
                        .disabled(isLaunchingExtGame || externalGameSession == nil)
                        .accessibilityLabel(Text(verbatim: isLaunchingExtGame ? W8Text.t("正在准备小游戏", "Loading game") : W8Text.t("启动外部小游戏 \(ext.gameName ?? ext.gameID)", "Launch \(ext.gameName ?? ext.gameID)")))
                        .accessibilityIdentifier("play.node.externalGame.launch")
                    }
                    .accessibilityIdentifier("play.node.externalGame")
                }
                if let question = node.question, !question.isEmpty {
                    Section("play.question") {
                        Text(verbatim: question).accessibilityIdentifier("play.question")
                        if node.validationMethod == 3, let options = node.options {
                            ForEach(options.keys.sorted(), id: \.self) { key in
                                Button {
                                    guard availability.canAnswer, !model.isSubmitting, !model.needsProgressCheck else { return }
                                    answer = key
                                } label: {
                                    HStack(alignment: .top) {
                                        Image(systemName: selectedAnswer == key ? "largecircle.fill.circle" : "circle").foregroundStyle(selectedAnswer == key ? CYColor.textPrimary : CYColor.textTertiary)
                                        Text(verbatim: key + ". " + (options[key] ?? ""))
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .disabled(!availability.canAnswer || model.isSubmitting || model.needsProgressCheck)
                                .accessibilityAddTraits(selectedAnswer == key ? .isSelected : [])
                                .accessibilityIdentifier("play.option.\(key)")
                            }
                        } else if availability == .text {
                            TextField("play.answer.placeholder", text: $answer, axis: .vertical)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .disabled(model.isSubmitting || model.needsProgressCheck)
                                .accessibilityIdentifier("play.answer.input")
                        }
                    }
                }
            }
            if let receipt = model.visibleReceipt, receipt.nodeID == nodeID { Section { PlayReceiptView(receipt: receipt) } }
            Section {
                if answerReviewIssue != nil {
                    Text(verbatim: reviewLocalized("expired")).accessibilityIdentifier("play.answer.review.issue")
                }
                if let issue = model.actionIssue {
                    if let message = issue.message, !message.isEmpty { Text(verbatim: message) }
                    else { Text("play.answer.failed") }
                }
                if model.isSubmitting {
                    ProgressView("play.answer.submitting").accessibilityIdentifier("play.answer.submitting")
                } else if model.needsProgressCheck {
                    Text("play.answer.checkProgress").foregroundStyle(CYColor.textSecondary)
                    CYPillButton("play.answer.refreshProgress", style: .secondary) { Task { await model.load(keepingReceipt: true) } }
                        .listRowBackground(Color.clear)
                        .disabled(model.isLoading || model.isSubmitting)
                        .accessibilityIdentifier("play.answer.refreshProgress")
                } else if availability.canAnswer {
                    if model.reader.supportsAnswerSubmission {
                        Text("play.answer.instructions").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        CYPillButton(verbatim: reviewLocalized("review")) {
                            do {
                                try reviewOwner.prepare(answer: answer, offered: offeredAnswer)
                                answerReviewIssue = nil
                            } catch { answerReviewIssue = PlayLoadIssue(error) }
                        }
                        .listRowBackground(Color.clear)
                        .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSubmitting || !model.reader.canSubmitAnswer)
                        .accessibilityIdentifier("play.answer.submit")
                    } else { Text("play.answer.readOnly").foregroundStyle(.secondary) }
                } else {
                    Text(LocalizedStringKey(availability.detailKey)).foregroundStyle(.secondary)
                }
            }
            if let perk = node.perk {
                Section("playx.perk.title") {
                    if perk.included == true { Text("playx.perk.included") }
                    if let spend = perk.extraSpendText, !spend.isEmpty { Text(verbatim: spend) }
                    if perk.reserveRequired == true { Text("playx.perk.reserve") }
                }
            }
            if snapshot.isDone(node) {
                Section("play.result") {
                    if let xp = node.xp { LabeledContent("play.xp") { Text(verbatim: String(xp)) } }
                    else { Text("play.xp.unknown") }
                    if let score = node.puzzleScore { LabeledContent("play.puzzleScore") { Text(verbatim: String(score)) } }
                    if let presented = PlayCompletionModePresentation(raw: node.completionMode) {
                        LabeledContent("play.completionMode") { Text(LocalizedStringKey(presented.titleKey)) }
                    } else if let mode = node.completionMode, !mode.isEmpty {
                        LabeledContent("play.completionMode") { Text(verbatim: mode) }
                    }
                }
            }
        }
        .accessibilityIdentifier("play.nodeDetail")
    }
    private enum NodeStatusIcon {
        case done, weatherLocked, locked, open
        var systemImage: String {
            switch self {
            case .done: return "checkmark.seal.fill"
            case .weatherLocked: return "cloud.rain.fill"
            case .locked: return "lock.fill"
            case .open: return "play.circle"
            }
        }
    }

    private func nodeStatusIcon(snapshot: PlaySnapshot, node: PlayNode) -> NodeStatusIcon {
        if snapshot.isDone(node) { return .done }
        if snapshot.isLocked(node) { return node.weatherLocked == true ? .weatherLocked : .locked }
        return .open
    }

    private func reviewLocalized(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(key), table: "PlayAnswerReview", locale: locale))
    }
}
