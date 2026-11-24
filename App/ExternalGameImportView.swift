import SwiftUI
import UniformTypeIdentifiers
#if canImport(QuestifyCore)
import QuestifyCore
#endif
#if canImport(WebKit)
import WebKit
#endif

// MARK: - DESIGNED: External Game Import UI & Sandboxed WKWebView Runner (Inside Play Theme Backpack .game Tab)

@available(macOS 14.0, *)
@MainActor struct ExternalGameLibrarySection: View {
    @Environment(\.locale) private var locale
    @Environment(\.externalGameSession) private var environmentSession
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @Bindable var store: ExternalGameStore
    private let injectedSession: ExternalGameSessionBridge?
    @State private var review: ExternalGameReviewModel
    @State private var showingImportSheet = false
    @State private var showingFileImporter = false
    @State private var submitForReview = false
    @State private var showSubmissions = false
    @State private var ageTarget: InstalledExternalGame?
    @State private var reportGame: InstalledExternalGame?
    @State private var importError: String?
    // Screens r4 · Figma 247:17370 (CF-62): delete is immediate with C2's undo toast; the files go when the toast does.
    @State private var importMode = "url"
    @State private var pendingRemoval: [String: UUID] = [:]
    @StateObject private var undoCenter = ProjectEditUndoCenter()
    @Environment(\.undoManager) private var undoManager
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    init(store: ExternalGameStore, session: ExternalGameSessionBridge? = nil) {
        _store = Bindable(wrappedValue: store)
        self.injectedSession = session
        _review = State(initialValue: ExternalGameReviewModel(store: store))
    }

    private var session: ExternalGameSessionBridge? { injectedSession ?? environmentSession }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            // Screens r4 · Figma 247:17370 (CF-62): title 小游戏库, one "＋" pull-down (链接 / 扫码 / 文件) and "⋯"
            // (提交审核 / 我的提交) as 44 pt circles in the app's own neutral tint; no blue text actions.
            HStack(alignment: .center, spacing: CYSpacing.sm) {
                ConfigR4Text.text("config.games.title")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CYSpacing.sm)
                Menu {
                    Button { importMode = "url"; showingImportSheet = true } label: {
                        Label { ConfigR4Text.text("config.games.importLink") } icon: { Image(systemName: "link") }
                    }
                    Button { importMode = "qr"; showingImportSheet = true } label: {
                        Label { ConfigR4Text.text("config.games.importScan") } icon: { Image(systemName: "qrcode.viewfinder") }
                    }
                    Button { showingFileImporter = true } label: {
                        Label(String(localized: LocalizedStringResource("playx.externalGame.importFile", defaultValue: "Import from File (.json)", locale: locale)), systemImage: "folder")
                    }
                } label: {
                    headerCircle("plus")
                }
                .accessibilityLabel(String(localized: LocalizedStringResource("playx.externalGame.importAction", defaultValue: "Import Game", locale: locale)))
                .accessibilityHint(String(localized: LocalizedStringResource("playx.externalGame.importUrlOrQr", defaultValue: "Link / Scan to Import", locale: locale)))
                .accessibilityIdentifier("externalGameImportButton")
                Menu {
                    Button { submitForReview = true } label: {
                        Label { ConfigR4Text.text("config.games.submit") } icon: { Image(systemName: "paperplane") }
                    }
                    .accessibilityIdentifier("externalGame.submitReview")
                    Button { showSubmissions = true } label: {
                        Label { ConfigR4Text.text("config.games.mySubmissions") } icon: { Image(systemName: "tray.full") }
                    }
                } label: {
                    headerCircle("ellipsis")
                }
                .accessibilityLabel(ConfigR4Text.text("config.games.more"))
                .accessibilityIdentifier("externalGame.more")
            }
            ExternalGameCatalogSection(model: review, session: session) { showSubmissions = true }
            CYScreenOfflineWriteBanner(
                routes: ["/api/external-game/submissions"],
                session: offlineWriteSession.session
            )
            if !review.notice.isEmpty {
                Text(review.notice).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("externalGame.notice")
            }
            if let requestID = review.unconfirmedRequestID {
                Text(W8Text.t("结果未知，仍保留请求 \(requestID)。", "The result is unknown. Request \(requestID) is still saved."))
                    .cyText(.bodyCompact)
                    .accessibilityIdentifier("externalGame.unconfirmed")
            }

            if let importError, !importError.isEmpty {
                Label(importError, systemImage: "exclamationmark.triangle.fill")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("externalGameImportError")
            }

            if store.installedGames.isEmpty {
                CYEmptyStateView(
                    systemImage: "puzzlepiece.extension",
                    title: LocalizedStringKey(W8Text.t("还没有导入的游戏", "No imported games yet")),
                    description: LocalizedStringKey("playx.externalGame.emptyHint"))
            } else {
                ForEach(store.installedGames.filter { pendingRemoval[$0.manifest.id] == nil }) { game in
                    installedRow(game)
                        .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: pendingRemoval)
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: store.installedGames.map(\.manifest.id))
        .editorToast($undoCenter.toast)
        // CF-62: a confirmed install lands as a new row (slides in on `CYMotion.standard`) with one success tap.
        .sensoryFeedback(.success, trigger: store.installedGames.count) { old, new in new > old }
        .onAppear { undoCenter.attach(undoManager) }
        .onDisappear { for id in Array(pendingRemoval.keys) { commitRemoval(id, token: pendingRemoval[id]) } }
        .sheet(isPresented: $showingImportSheet) {
            ExternalGameImportInputSheet(store: store, initialMode: importMode, onError: { importError = $0 })
        }
        .sheet(item: $store.pendingConfirmation) { confirmation in
            ExternalGamePermissionConfirmationSheet(
                confirmation: confirmation,
                onConfirm: {
                    do {
                        _ = try store.confirmInstall()
                        importError = nil
                    } catch {
                        importError = error.localizedDescription
                    }
                },
                onCancel: {
                    store.cancelPendingImport()
                }
            )
        }
        .sheet(item: $store.activeLaunchingGame) { game in
            ExternalGameRunnerSheet(
                store: store,
                game: game,
                session: session,
                review: review,
                onReport: { reportGame = game }
            )
        }
        .navigationDestination(isPresented: $showSubmissions) {
            ExternalGameSubmissionsScreen(model: review, session: session)
        }
        .sheet(item: $ageTarget) { game in
            ExternalGameAgeGateSheet(game: game, onConfirm: {
                store.acceptAgeGate(game.manifest)
                ageTarget = nil
                store.activeLaunchingGame = game
            }, onCancel: { ageTarget = nil })
        }
        .sheet(item: $reportGame) { game in
            ExternalGameReportSheet(manifest: game.manifest, onSend: { draft in
                if draft.blocked { store.block(game.manifest) }
                Task { await review.report(draft, session: session) }
                reportGame = nil
            }, onCancel: { reportGame = nil })
        }
        .task(id: session?.token) { await review.reload(session: session) }
        .fileImporter(isPresented: $submitForReview, allowedContentTypes: [.json, .data], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            Task {
                await SessionOfflineSyncModel.shared.performWriteOptIn(
                    environmentSession: offlineWriteSession.session,
                    routes: ["/api/external-game/submissions"]
                ) {
                    await review.submit(archive: data, session: session)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    _ = try store.prepareImport(archiveData: data, source: .file(url))
                    importError = nil
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }

    private func headerCircle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .accessibilityHidden(true) // the enclosing Button carries the label
            .cyText(.bodyMedium)
            .foregroundStyle(palette.textPrimary)
            .frame(width: EditorKitMetric.closeVisual, height: EditorKitMetric.closeVisual)
            .background(Circle().fill(palette.brandSoft))
            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
    }

    /// One row: glyph tile, name, `v1.2 · 分级 12+` (no package id or source code), 运行 as the secondary pill, and
    /// "⋯" (举报, 删除游戏 in red, last). The same actions are on the row's context menu.
    private func installedRow(_ game: InstalledExternalGame) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: "puzzlepiece.extension")
                .cyText(.bodyMedium)
                .foregroundStyle(palette.textSecondary)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.bgRaised))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: game.manifest.name)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("config.games.meta \(game.manifest.version) \(game.manifest.contentRating)", tableName: ConfigR4Text.table)
                    .cyText(.meta)
                    .foregroundStyle(palette.textTertiary)
            }
            Spacer(minLength: CYSpacing.sm)
            Button(String(localized: LocalizedStringResource("playx.externalGame.launch", defaultValue: "Run", locale: locale))) {
                if store.ageGateNeedsConfirmation(game.manifest) {
                    ageTarget = game
                } else {
                    store.activeLaunchingGame = game
                }
            }
            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
            .accessibilityIdentifier("externalGame.run.\(game.manifest.id)")
            Menu { rowActions(game) } label: {
                Image(systemName: "ellipsis")
                    .cyText(.bodyMedium)
                    .foregroundStyle(palette.textSecondary)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(ConfigR4Text.text("config.games.more"))
            .accessibilityIdentifier("externalGame.rowMenu.\(game.manifest.id)")
        }
        .padding(CYSpacing.md)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.bgElevated))
        .contentShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .contextMenu { rowActions(game) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func rowActions(_ game: InstalledExternalGame) -> some View {
        Button { reportGame = game } label: {
            Label { ConfigR4Text.text("config.games.report") } icon: { Image(systemName: "exclamationmark.bubble") }
        }
        Divider()
        Button(role: .destructive) { remove(game) } label: {
            Label { ConfigR4Text.text("config.games.delete") } icon: { Image(systemName: "trash") }
        }
        .accessibilityLabel(String(localized: LocalizedStringResource("playx.externalGame.remove", defaultValue: "Remove Game", locale: locale)))
    }

    /// C2's one delete rule: the row goes at once with 已删除「X」 撤销 (5 s, shake / ⌘Z). The package and its save
    /// are removed only when the undo window closes (or the library goes away), so 撤销 really brings it back.
    private func remove(_ game: InstalledExternalGame) {
        let id = game.manifest.id, token = UUID()
        pendingRemoval[id] = token
        undoCenter.recordDelete(
            message: String(format: OpsR3Text.string("editor.deleted.item", locale: locale), game.manifest.name),
            actionName: ConfigR4Text.string("config.games.delete", locale: locale)
        ) {
            guard pendingRemoval[id] == token else { return false }
            pendingRemoval[id] = nil
            return true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((EditorMotionSpec.toastSeconds * 2.5 + 0.4) * 1_000_000_000))
            commitRemoval(id, token: token)
        }
    }

    private func commitRemoval(_ id: String, token: UUID?) {
        guard let token, pendingRemoval[id] == token else { return }
        pendingRemoval[id] = nil
        do {
            try store.remove(id: id)
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }
}

@available(macOS 14.0, *)
@MainActor private struct ExternalGameImportInputSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyPalette) private var palette
    let store: ExternalGameStore
    let onError: (String) -> Void
    @State private var mode: String

    init(store: ExternalGameStore, initialMode: String = "url", onError: @escaping (String) -> Void) {
        self.store = store
        self.onError = onError
        _mode = State(initialValue: initialMode == "qr" ? "qr" : "url")
    }
    @State private var linkInput: String = ""
    @State private var check: ExternalGameLinkCheck?

    var body: some View {
        NavigationStack {
            Form {
                Picker(String(localized: LocalizedStringResource("playx.externalGame.importMethod", defaultValue: "Import Method", locale: locale)), selection: $mode) {
                    Text(String(localized: LocalizedStringResource("playx.externalGame.byUrl", defaultValue: "HTTPS Link", locale: locale))).tag("url")
                    Text(String(localized: LocalizedStringResource("playx.externalGame.byQr", defaultValue: "QR Code Content", locale: locale))).tag("qr")
                }
                .pickerStyle(.segmented)

                Section(mode == "url"
                    ? String(localized: LocalizedStringResource("playx.externalGame.urlSection", defaultValue: "Package HTTPS Address", locale: locale))
                    : String(localized: LocalizedStringResource("playx.externalGame.qrSection", defaultValue: "Secure Link Found in QR Code", locale: locale))) {
                    TextField("https://example.com/game.json", text: $linkInput)
                        .cyText(.body)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }

                if let check {
                    Section {
                        Label(ExternalGameLibraryPresentation.message(for: check),
                              systemImage: check == .validButNotDownloadable ? "info.circle" : "exclamationmark.triangle.fill")
                            .cyText(.bodyCompact)
                            .foregroundStyle(check == .validButNotDownloadable ? CYColor.infoText : CYColor.dangerText)
                            .accessibilityIdentifier("externalGameLinkResult")
                    }
                }

                Section {
                    Button(String(localized: LocalizedStringResource("playx.externalGame.verifyManifest", defaultValue: "Verify Signed Manifest and Preview Permissions", locale: locale))) {
                        // Honest: a link is only checked for shape. No package is fetched or staged from it.
                        check = ExternalGameLibraryPresentation.checkLink(linkInput)
                        if let check, check != .validButNotDownloadable {
                            onError(ExternalGameLibraryPresentation.message(for: check))
                        }
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("externalGameLinkCheck")
                }
            }
            .navigationTitle(String(localized: LocalizedStringResource("playx.externalGame.importTitle", defaultValue: "Import External Game", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.cancel", defaultValue: "Cancel", locale: locale))) { dismiss() }
                }
            }
        }
        // CF-62: the app's own neutral tint (white on dark), not the stock blue.
        .tint(palette.textPrimary)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

@available(macOS 14.0, *)
@MainActor struct ExternalGamePermissionConfirmationSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    let confirmation: ExternalGamePendingConfirmation
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: LocalizedStringResource("playx.externalGame.confirmPackage", defaultValue: "Package Source and Signature Verification", locale: locale))) {
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.name", defaultValue: "Name", locale: locale)), value: confirmation.archive.manifest.name)
                    LabeledContent("ID", value: confirmation.archive.manifest.id)
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.version", defaultValue: "Version", locale: locale))) {
                        if confirmation.isUpdate, let prev = confirmation.previousVersion {
                            Text("\(prev) → \(confirmation.archive.manifest.version)")
                        } else {
                            Text(confirmation.archive.manifest.version)
                        }
                    }
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.rating", defaultValue: "Content Rating", locale: locale)), value: confirmation.archive.manifest.contentRating)
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.source", defaultValue: "Import Source", locale: locale)), value: confirmation.source.displayOrigin)
                    LabeledContent("SHA-256", value: confirmation.sha256Fingerprint + "…")
                }

                Section(String(localized: LocalizedStringResource("playx.externalGame.permissionsSection", defaultValue: "Requested Sandbox Permissions", locale: locale))) {
                    if confirmation.permissionsList.isEmpty {
                        Text(String(localized: LocalizedStringResource("playx.externalGame.noPermissions", defaultValue: "No extra permissions (offline static content only)", locale: locale)))
                            .foregroundStyle(CYColor.textSecondary)
                    } else {
                        // CF-62: permissions as icon rows (存档 / 触感 / 声音) with a check, not sentences in brackets.
                        ForEach(confirmation.permissionsList, id: \.rawValue) { perm in
                            HStack(spacing: CYSpacing.md) {
                                Image(systemName: Self.symbol(perm))
                                    .foregroundStyle(palette.textSecondary)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                Text(verbatim: perm.displayName)
                                    .cyText(.body)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: CYSpacing.sm)
                                Image(systemName: "checkmark")
                                    .cyText(.label)
                                    .foregroundStyle(palette.textPrimary)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section(String(localized: LocalizedStringResource("playx.externalGame.domainsSection", defaultValue: "Allowed HTTPS Domains", locale: locale))) {
                    if confirmation.archive.manifest.allowedDomains.isEmpty {
                        Text(String(localized: LocalizedStringResource("playx.externalGame.noExternalNetwork", defaultValue: "Fully offline (no external network requests allowed)", locale: locale)))
                            .foregroundStyle(CYColor.textSecondary)
                    } else {
                        ForEach(confirmation.archive.manifest.allowedDomains, id: \.self) { domain in
                            Label("https://\(domain)", systemImage: "lock.shield")
                        }
                    }
                }

                Section {
                    Text(String(localized: LocalizedStringResource("playx.externalGame.securityNotice", defaultValue: "Security commitment: this content runs only inside an isolated WKWebView sandbox, shares no sign-in credentials, allows no in-app purchases or external payments, and exposes only versioned read-only and save bridge interfaces.", locale: locale)))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
            }
            .navigationTitle(confirmation.isUpdate
                ? String(localized: LocalizedStringResource("playx.externalGame.confirmUpdateTitle", defaultValue: "Confirm External Game Update", locale: locale))
                : String(localized: LocalizedStringResource("playx.externalGame.confirmInstallTitle", defaultValue: "Confirm Import of External Game", locale: locale)))
            .accessibilityIdentifier("externalGame.permissions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.cancel", defaultValue: "Cancel", locale: locale)), action: onCancel)
                }
            }
            // CF-62: the confirm is the one white pill, pinned at the bottom; 取消 stays in the bar in the neutral tint.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CYFooterBar {
                    Button(action: onConfirm) {
                        Text(verbatim: confirmation.isUpdate
                            ? String(localized: LocalizedStringResource("playx.externalGame.confirmUpdate", defaultValue: "Confirm Update", locale: locale))
                            : String(localized: LocalizedStringResource("playx.externalGame.confirmInstall", defaultValue: "Confirm Install", locale: locale)))
                    }
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                    .accessibilityIdentifier("externalGame.confirmInstall")
                }
            }
        }
        .tint(palette.textPrimary)
        .presentationDetents([.large])
    }

    static func symbol(_ permission: ExternalGamePermission) -> String {
        switch permission {
        case .storage: return "externaldrive"
        case .haptics: return "iphone.radiowaves.left.and.right"
        case .audio: return "speaker.wave.2"
        }
    }
}

struct ExternalGameNodePlayContext: Equatable, Sendable {
    let nodeID: Int
    let topicID: Int?
    let activityID: Int?
}

@available(macOS 14.0, *)
@MainActor struct ExternalGameRunnerSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let store: ExternalGameStore
    let game: InstalledExternalGame
    var session: ExternalGameSessionBridge? = nil
    var review: ExternalGameReviewModel? = nil
    var nodeContext: ExternalGameNodePlayContext? = nil
    var onResultSubmitted: ((ExternalGameResultOutcome) -> Void)? = nil
    var onReport: () -> Void = {}
    @State private var confirmsBlock = false
    @State private var sessionTicket: ExternalGameSessionTicket?
    @State private var startedAt = Date()
    @State private var resultOutcome: ExternalGameResultOutcome?
    @State private var isSubmittingResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label("\(game.manifest.name) (v\(game.manifest.version))", systemImage: "lock.shield")
                        .cyText(.label)
                        .foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    Text(W8Text.t("分级 \(game.manifest.contentRating) · 沙盒隔离", "Rated \(game.manifest.contentRating) · sandboxed"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
                .padding(.horizontal, CYSpacing.md)
                .padding(.vertical, CYSpacing.sm)
                .background(CYColor.bgSurfaceSubtle)

                #if canImport(WebKit)
                if let entryURL = store.entryFileURL(for: game) {
                    ExternalGameSandboxedWebView(
                        entryURL: entryURL,
                        packageRoot: store.packageDirectory(for: game.manifest.id),
                        manifest: game.manifest,
                        onBridgeMessage: { data in
                            store.handleBridgeMessage(data, for: game.manifest.id)
                        }
                    )
                } else {
                    ContentUnavailableView(
                        String(localized: LocalizedStringResource("playx.externalGame.entryBlocked", defaultValue: "The entry file did not pass sandbox validation", locale: locale)),
                        systemImage: "exclamationmark.shield"
                    )
                }
                #else
                ContentUnavailableView(
                    String(localized: LocalizedStringResource("playx.externalGame.webKitUnavailable", defaultValue: "This environment does not support the WebKit sandbox view", locale: locale)),
                    systemImage: "safari"
                )
                #endif

                if session != nil {
                    HStack(spacing: CYSpacing.sm) {
                        if let outcome = resultOutcome {
                            let medalText = outcome.medalRank.map { W8Text.t(" · 勋章第\($0)名", " · Medal #\($0)") } ?? ""
                            let nodeText = outcome.nodeCompleted ? W8Text.t(" · 节点已通关", " · Node done") : ""
                            Text(verbatim: W8Text.t("结果已签名上报：+\(outcome.xpAwarded) 探索值\(medalText)\(nodeText)", "Signed result: +\(outcome.xpAwarded) XP\(medalText)\(nodeText)"))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textPrimary)
                                .accessibilityIdentifier("externalGame.signedResult")
                        } else if sessionTicket != nil {
                            Button(isSubmittingResult ? W8Text.t("正在签名提交...", "Submitting...") : W8Text.t("完成并签名上报结果", "Submit signed result")) {
                                Task {
                                    await reportSignedResult(passed: true, score: nil, digest: nil)
                                }
                            }
                            .cyText(.label)
                            .disabled(isSubmittingResult)
                            .accessibilityLabel(W8Text.t("完成并签名上报结果", "Submit signed result"))
                            .accessibilityHint(W8Text.t("把本次外部游戏成绩签名提交给服务器结算", "Submit the signed external game result to the server"))
                            .accessibilityIdentifier("externalGame.submitSignedResult")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, CYSpacing.md)
                    .padding(.vertical, CYSpacing.xs)
                    .background(CYColor.bgSurfaceSubtle)
                }
            }
            .task {
                startedAt = Date()
                if let session, let review, sessionTicket == nil {
                    sessionTicket = await review.startPlaySession(
                        gameID: game.manifest.id,
                        nodeID: nodeContext?.nodeID,
                        topicID: nodeContext?.topicID,
                        activityID: nodeContext?.activityID,
                        session: session
                    )
                }
            }
            .onChange(of: store.lastBridgeResultByGameID[game.manifest.id]) { _, reported in
                guard let reported, resultOutcome == nil else { return }
                Task {
                    await reportSignedResult(passed: reported.passed, score: reported.score, digest: reported.digest)
                }
            }
            .navigationTitle(game.manifest.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.close", defaultValue: "Close", locale: locale))) {
                        store.activeLaunchingGame = nil
                        dismiss()
                    }
                }
                // App Store 1.2 / 4.7: report and block the package and its creator from the runner itself.
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ShareLink(item: store.reportSummary(for: game.manifest)) {
                            Label(W8Text.t("举报此游戏包", "Report this game"), systemImage: "exclamationmark.bubble")
                        }
                        .accessibilityIdentifier("externalGame.report")
                        Button(action: onReport) {
                            Label(W8Text.t("向服务器举报", "Report to the server"), systemImage: "flag")
                        }
                        .accessibilityIdentifier("externalGame.reportServer")
                        Button(role: .destructive, action: { confirmsBlock = true }) {
                            Label(W8Text.t("屏蔽此游戏及创作者", "Block this game and its creator"), systemImage: "hand.raised")
                        }
                        .accessibilityIdentifier("externalGame.block")
                    } label: {
                        Label(W8Text.t("举报或屏蔽", "Report or block"), systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("externalGame.safetyMenu")
                }
            }
            .confirmationDialog(W8Text.t("屏蔽后将关闭并无法再导入或运行此游戏及其创作者的其他游戏包。", "Blocking closes this game and stops you importing or running it or other packages from its creator."),
                                isPresented: $confirmsBlock, titleVisibility: .visible) {
                Button(W8Text.t("屏蔽", "Block"), role: .destructive) { store.block(game.manifest) }
                Button(W8Text.t("取消", "Cancel"), role: .cancel) {}
            }
        }
    }

    private func reportSignedResult(passed: Bool, score: Int?, digest: String?) async {
        guard let session, let review, let ticket = sessionTicket, !isSubmittingResult else { return }
        isSubmittingResult = true
        defer { isSubmittingResult = false }
        let elapsed = max(0, Int64(Date().timeIntervalSince(startedAt) * 1000))
        if let outcome = await review.submitSignedResult(
            ticket: ticket,
            passed: passed,
            score: score,
            durationMs: elapsed,
            digest: digest,
            session: session
        ) {
            resultOutcome = outcome
            onResultSubmitted?(outcome)
        }
    }
}

#if canImport(WebKit)
@MainActor
final class ExternalGameWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let packageRoot: URL
    let manifest: ExternalGameManifest
    let onBridgeMessage: (Data) -> ExternalGameBridgeResponse

    init(packageRoot: URL, manifest: ExternalGameManifest, onBridgeMessage: @escaping (Data) -> ExternalGameBridgeResponse) {
        self.packageRoot = packageRoot
        self.manifest = manifest
        self.onBridgeMessage = onBridgeMessage
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")
        config.setValue(false, forKey: "allowUniversalAccessFromFileURLs")
        let controller = WKUserContentController()
        controller.add(self, name: ExternalGameSandboxPolicy.bridgeName)
        config.userContentController = controller
        return config
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Never allow window.open() or target="_blank" to spawn un-sandboxed windows.
        nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame != nil,
              let url = navigationAction.request.url,
              ExternalGameSandboxPolicy.allowsNavigation(to: url, packageRoot: packageRoot, manifest: manifest) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == ExternalGameSandboxPolicy.bridgeName,
              message.frameInfo.isMainFrame else { return }
        if let frameURL = message.frameInfo.request.url,
           !ExternalGameSandboxPolicy.allowsNavigation(to: frameURL, packageRoot: packageRoot, manifest: manifest) {
            return
        }
        let rawData: Data
        if let str = message.body as? String {
            rawData = Data(str.utf8)
        } else if let dict = message.body as? [String: Any],
                  let serialized = try? JSONSerialization.data(withJSONObject: dict) {
            rawData = serialized
        } else {
            return
        }
        _ = onBridgeMessage(rawData)
    }
}

#if os(iOS)
@available(iOS 17.0, *)
struct ExternalGameSandboxedWebView: UIViewRepresentable {
    let entryURL: URL
    let packageRoot: URL
    let manifest: ExternalGameManifest
    let onBridgeMessage: (Data) -> ExternalGameBridgeResponse

    func makeCoordinator() -> ExternalGameWebViewCoordinator {
        ExternalGameWebViewCoordinator(packageRoot: packageRoot, manifest: manifest, onBridgeMessage: onBridgeMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = context.coordinator.makeConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.loadFileURL(entryURL, allowingReadAccessTo: packageRoot)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ExternalGameWebViewCoordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: ExternalGameSandboxPolicy.bridgeName)
        uiView.stopLoading()
    }
}
#elseif os(macOS)
@available(macOS 14.0, *)
struct ExternalGameSandboxedWebView: NSViewRepresentable {
    let entryURL: URL
    let packageRoot: URL
    let manifest: ExternalGameManifest
    let onBridgeMessage: (Data) -> ExternalGameBridgeResponse

    func makeCoordinator() -> ExternalGameWebViewCoordinator {
        ExternalGameWebViewCoordinator(packageRoot: packageRoot, manifest: manifest, onBridgeMessage: onBridgeMessage)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = context.coordinator.makeConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.loadFileURL(entryURL, allowingReadAccessTo: packageRoot)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: ExternalGameWebViewCoordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: ExternalGameSandboxPolicy.bridgeName)
        nsView.stopLoading()
    }
}
#endif
#endif
