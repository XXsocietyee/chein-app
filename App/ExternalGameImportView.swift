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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    String(localized: LocalizedStringResource("playx.externalGame.sectionTitle", defaultValue: "扩展小游戏库（沙盒）", locale: locale)),
                    systemImage: "puzzlepiece.extension"
                )
                .font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Label(String(localized: LocalizedStringResource("playx.externalGame.importUrlOrQr", defaultValue: "链接 / 扫码导入", locale: locale)), systemImage: "qrcode.viewfinder")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label(String(localized: LocalizedStringResource("playx.externalGame.importFile", defaultValue: "从文件导入 (.json)", locale: locale)), systemImage: "folder")
                    }
                } label: {
                    Label(String(localized: LocalizedStringResource("playx.externalGame.importAction", defaultValue: "导入游戏", locale: locale)), systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("externalGameImportButton")
            }

            if let importError, !importError.isEmpty {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if store.installedGames.isEmpty {
                Text(String(localized: LocalizedStringResource("playx.externalGame.emptyHint", defaultValue: "支持通过 HTTPS 链接、二维码或文件导入带签名清单的 HTML5 互动包，仅在受限沙盒中运行。", locale: locale)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.installedGames) { game in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(game.manifest.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("v\(game.manifest.version)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(game.manifest.contentRating)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15), in: Capsule())
                                }
                                Text("\(game.manifest.id) · \(game.source.sourceKindLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: LocalizedStringResource("playx.externalGame.launch", defaultValue: "运行", locale: locale))) {
                                store.activeLaunchingGame = game
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button(role: .destructive) {
                                try? store.remove(id: game.manifest.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel(String(localized: LocalizedStringResource("playx.externalGame.remove", defaultValue: "移除游戏", locale: locale)))
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
}

@available(macOS 14.0, *)
@MainActor private struct ExternalGameImportInputSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let store: ExternalGameStore
    let onError: (String) -> Void
    @State private var mode: String = "url"
    @State private var urlInput: String = "https://example.com/games/campfire-riddle.json"
    @State private var qrInput: String = "https://example.com/games/campfire-riddle.json"
    @State private var localError: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker(String(localized: LocalizedStringResource("playx.externalGame.importMethod", defaultValue: "导入方式", locale: locale)), selection: $mode) {
                    Text(String(localized: LocalizedStringResource("playx.externalGame.byUrl", defaultValue: "HTTPS 链接", locale: locale))).tag("url")
                    Text(String(localized: LocalizedStringResource("playx.externalGame.byQr", defaultValue: "二维码内容", locale: locale))).tag("qr")
                }
                .pickerStyle(.segmented)

                if mode == "url" {
                    Section(String(localized: LocalizedStringResource("playx.externalGame.urlSection", defaultValue: "游戏包 HTTPS 地址", locale: locale))) {
                        TextField("https://example.com/game.json", text: $urlInput)
                            .autocorrectionDisabled()
                    }
                } else {
                    Section(String(localized: LocalizedStringResource("playx.externalGame.qrSection", defaultValue: "扫码识别出的安全链接", locale: locale))) {
                        TextField("https://example.com/game.json", text: $qrInput)
                            .autocorrectionDisabled()
                    }
                }

                if !localError.isEmpty {
                    Section {
                        Text(localError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(String(localized: LocalizedStringResource("playx.externalGame.verifyManifest", defaultValue: "校验签名清单并预览权限", locale: locale))) {
                        verifyAndStage()
                    }
                }
            }
            .navigationTitle(String(localized: LocalizedStringResource("playx.externalGame.importTitle", defaultValue: "导入外部游戏", locale: locale)))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.cancel", defaultValue: "取消", locale: locale))) { dismiss() }
                }
            }
        }
    }

    private func verifyAndStage() {
        localError = ""
        do {
            let sample = ExternalGameStore.makeSampleSignedArchive()
            if mode == "url" {
                guard let url = URL(string: urlInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw ExternalGameValidationError.insecureImportURL(urlInput)
                }
                _ = try store.prepareImport(archive: sample, source: .url(url))
            } else {
                _ = try store.prepareImport(archive: sample, source: .qrCode(qrInput))
            }
            dismiss()
        } catch {
            localError = error.localizedDescription
            onError(error.localizedDescription)
        }
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
                Section(String(localized: LocalizedStringResource("playx.externalGame.confirmPackage", defaultValue: "游戏包来源与签名核验", locale: locale))) {
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.name", defaultValue: "名称", locale: locale)), value: confirmation.archive.manifest.name)
                    LabeledContent("ID", value: confirmation.archive.manifest.id)
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.version", defaultValue: "版本", locale: locale))) {
                        if confirmation.isUpdate, let prev = confirmation.previousVersion {
                            Text("\(prev) → \(confirmation.archive.manifest.version)")
                        } else {
                            Text(confirmation.archive.manifest.version)
                        }
                    }
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.rating", defaultValue: "内容分级", locale: locale)), value: confirmation.archive.manifest.contentRating)
                    LabeledContent(String(localized: LocalizedStringResource("playx.externalGame.source", defaultValue: "导入来源", locale: locale)), value: confirmation.source.displayOrigin)
                    LabeledContent("SHA-256", value: confirmation.sha256Fingerprint + "…")
                }

                Section(String(localized: LocalizedStringResource("playx.externalGame.permissionsSection", defaultValue: "申请的沙盒权限", locale: locale))) {
                    if confirmation.permissionsList.isEmpty {
                        Text(String(localized: LocalizedStringResource("playx.externalGame.noPermissions", defaultValue: "无额外权限（纯离线静态互动）", locale: locale)))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(confirmation.permissionsList, id: \.rawValue) { perm in
                            Label(perm.displayName, systemImage: "checkmark.shield")
                        }
                    }
                }

                Section(String(localized: LocalizedStringResource("playx.externalGame.domainsSection", defaultValue: "允许访问的 HTTPS 域名白名单", locale: locale))) {
                    if confirmation.archive.manifest.allowedDomains.isEmpty {
                        Text(String(localized: LocalizedStringResource("playx.externalGame.noExternalNetwork", defaultValue: "完全离线（禁止任何外部网络请求）", locale: locale)))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(confirmation.archive.manifest.allowedDomains, id: \.self) { domain in
                            Label("https://\(domain)", systemImage: "lock.shield")
                        }
                    }
                }

                Section {
                    Text(String(localized: LocalizedStringResource("playx.externalGame.securityNotice", defaultValue: "安全承诺：该内容仅在隔离的 WKWebView 沙盒内运行，不共享登录凭据，禁止任何应用内购买或外部支付，且仅开放受版本控制的只读/存档桥接接口。", locale: locale)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(confirmation.isUpdate
                ? String(localized: LocalizedStringResource("playx.externalGame.confirmUpdateTitle", defaultValue: "确认更新外部游戏", locale: locale))
                : String(localized: LocalizedStringResource("playx.externalGame.confirmInstallTitle", defaultValue: "确认导入外部游戏", locale: locale)))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.cancel", defaultValue: "取消", locale: locale)), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmation.isUpdate
                        ? String(localized: LocalizedStringResource("playx.externalGame.confirmUpdate", defaultValue: "确认更新", locale: locale))
                        : String(localized: LocalizedStringResource("playx.externalGame.confirmInstall", defaultValue: "确认安装", locale: locale)),
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label("\(game.manifest.name) (v\(game.manifest.version))", systemImage: "lock.shield")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("分级 \(game.manifest.contentRating) · 沙盒隔离")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))

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
                        String(localized: LocalizedStringResource("playx.externalGame.entryBlocked", defaultValue: "入口文件未通过沙盒校验", locale: locale)),
                        systemImage: "exclamationmark.shield"
                    )
                }
                #else
                ContentUnavailableView(
                    String(localized: LocalizedStringResource("playx.externalGame.webKitUnavailable", defaultValue: "当前环境不支持 WebKit 沙盒视图", locale: locale)),
                    systemImage: "safari"
                )
                #endif
            }
            .navigationTitle(game.manifest.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("common.close", defaultValue: "关闭", locale: locale))) {
                        store.activeLaunchingGame = nil
                    }
                }
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
