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
    @Bindable var store: ExternalGameStore
    @State private var showingImportSheet = false
    @State private var showingFileImporter = false
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .center, spacing: CYSpacing.sm) {
                Label(
                    String(localized: LocalizedStringResource("playx.externalGame.sectionTitle", defaultValue: "Extended Mini-Game Library (Sandbox)", locale: locale)),
                    systemImage: "puzzlepiece.extension"
                )
                .font(CYTypography.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CYSpacing.sm)
                Menu {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Label(String(localized: LocalizedStringResource("playx.externalGame.importUrlOrQr", defaultValue: "Link / Scan to Import", locale: locale)), systemImage: "qrcode.viewfinder")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label(String(localized: LocalizedStringResource("playx.externalGame.importFile", defaultValue: "Import from File (.json)", locale: locale)), systemImage: "folder")
                    }
                } label: {
                    Label(String(localized: LocalizedStringResource("playx.externalGame.importAction", defaultValue: "Import Game", locale: locale)), systemImage: "square.and.arrow.down")
                        .font(CYTypography.label)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("externalGameImportButton")
            }

            if let importError, !importError.isEmpty {
                Label(importError, systemImage: "exclamationmark.triangle.fill")
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("externalGameImportError")
            }

            if store.installedGames.isEmpty {
                CYEmptyStateView(
                    systemImage: "puzzlepiece.extension",
                    title: LocalizedStringKey(W8Text.t("还没有导入的游戏", "No imported games yet")),
                    description: LocalizedStringKey("playx.externalGame.emptyHint"))
            } else {
                ForEach(store.installedGames) { game in
                    installedRow(game)
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ExternalGameImportInputSheet(store: store, onError: { importError = $0 })
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
            ExternalGameRunnerSheet(store: store, game: game)
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

    private func installedRow(_ game: InstalledExternalGame) -> some View {
        CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(game.manifest.name)
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    Text("v\(game.manifest.version) · \(game.manifest.contentRating)")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                    Text("\(game.manifest.id) · \(game.source.sourceKindLabel)")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
                Spacer(minLength: CYSpacing.sm)
                Button(String(localized: LocalizedStringResource("playx.externalGame.launch", defaultValue: "Run", locale: locale))) {
                    store.activeLaunchingGame = game
                }
                .buttonStyle(.cyPrimary(fullWidth: false))

                Button(role: .destructive) {
                    do {
                        try store.remove(id: game.manifest.id)
                        importError = nil
                    } catch {
                        importError = error.localizedDescription
                    }
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(String(localized: LocalizedStringResource("playx.externalGame.remove", defaultValue: "Remove Game", locale: locale)))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

@available(macOS 14.0, *)
@MainActor private struct ExternalGameImportInputSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let store: ExternalGameStore
    let onError: (String) -> Void
    @State private var mode: String = "url"
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
                        .font(CYTypography.body)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }

                if let check {
                    Section {
                        Label(ExternalGameLibraryPresentation.message(for: check),
                              systemImage: check == .validButNotDownloadable ? "info.circle" : "exclamationmark.triangle.fill")
                            .font(CYTypography.bodyCompact)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

@available(macOS 14.0, *)
@MainActor struct ExternalGamePermissionConfirmationSheet: View {
    @Environment(\.locale) private var locale
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
                        ForEach(confirmation.permissionsList, id: \.rawValue) { perm in
                            Label(perm.displayName, systemImage: "checkmark.shield")
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
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
            }
            .navigationTitle(confirmation.isUpdate
                ? String(localized: LocalizedStringResource("playx.externalGame.confirmUpdateTitle", defaultValue: "Confirm External Game Update", locale: locale))
                : String(localized: LocalizedStringResource("playx.externalGame.confirmInstallTitle", defaultValue: "Confirm Import of External Game", locale: locale)))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.cancel", defaultValue: "Cancel", locale: locale)), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmation.isUpdate
                        ? String(localized: LocalizedStringResource("playx.externalGame.confirmUpdate", defaultValue: "Confirm Update", locale: locale))
                        : String(localized: LocalizedStringResource("playx.externalGame.confirmInstall", defaultValue: "Confirm Install", locale: locale)),
                        action: onConfirm)
                }
            }
        }
    }
}

@available(macOS 14.0, *)
@MainActor private struct ExternalGameRunnerSheet: View {
    @Environment(\.locale) private var locale
    let store: ExternalGameStore
    let game: InstalledExternalGame
    @State private var confirmsBlock = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label("\(game.manifest.name) (v\(game.manifest.version))", systemImage: "lock.shield")
                        .font(CYTypography.label)
                        .foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    Text(W8Text.t("分级 \(game.manifest.contentRating) · 沙盒隔离", "Rated \(game.manifest.contentRating) · sandboxed"))
                        .font(CYTypography.meta)
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
            }
            .navigationTitle(game.manifest.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.close", defaultValue: "Close", locale: locale))) {
                        store.activeLaunchingGame = nil
                    }
                }
                // App Store 1.2 / 4.7: report and block the package and its creator from the runner itself.
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ShareLink(item: store.reportSummary(for: game.manifest)) {
                            Label(W8Text.t("举报此游戏包", "Report this game"), systemImage: "exclamationmark.bubble")
                        }
                        .accessibilityIdentifier("externalGame.report")
                        Button(role: .destructive) { confirmsBlock = true } label: {
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
}

#if canImport(WebKit)
#if os(iOS)
@available(iOS 17.0, *)
struct ExternalGameSandboxedWebView: UIViewRepresentable {
    let entryURL: URL
    let packageRoot: URL
    let manifest: ExternalGameManifest
    let onBridgeMessage: (Data) -> ExternalGameBridgeResponse

    func makeCoordinator() -> Coordinator {
        Coordinator(packageRoot: packageRoot, manifest: manifest, onBridgeMessage: onBridgeMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = context.coordinator.makeConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.loadFileURL(entryURL, allowingReadAccessTo: packageRoot)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: ExternalGameSandboxPolicy.bridgeName)
        uiView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
            let controller = WKUserContentController()
            controller.add(self, name: ExternalGameSandboxPolicy.bridgeName)
            config.userContentController = controller
            return config
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  ExternalGameSandboxPolicy.allowsNavigation(to: url, packageRoot: packageRoot, manifest: manifest) else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == ExternalGameSandboxPolicy.bridgeName else { return }
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
}
#elseif os(macOS)
@available(macOS 14.0, *)
struct ExternalGameSandboxedWebView: NSViewRepresentable {
    let entryURL: URL
    let packageRoot: URL
    let manifest: ExternalGameManifest
    let onBridgeMessage: (Data) -> ExternalGameBridgeResponse

    func makeCoordinator() -> Coordinator {
        Coordinator(packageRoot: packageRoot, manifest: manifest, onBridgeMessage: onBridgeMessage)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = context.coordinator.makeConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.loadFileURL(entryURL, allowingReadAccessTo: packageRoot)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: ExternalGameSandboxPolicy.bridgeName)
        nsView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
            let controller = WKUserContentController()
            controller.add(self, name: ExternalGameSandboxPolicy.bridgeName)
            config.userContentController = controller
            return config
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  ExternalGameSandboxPolicy.allowsNavigation(to: url, packageRoot: packageRoot, manifest: manifest) else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == ExternalGameSandboxPolicy.bridgeName else { return }
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
}
#endif
#endif
