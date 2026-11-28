import SwiftUI
import UIKit

private struct WithdrawalSupportReaderKey: EnvironmentKey {
    static let defaultValue: WithdrawalSupportReader? = nil
}
extension EnvironmentValues {
    var withdrawalSupportReader: WithdrawalSupportReader? {
        get { self[WithdrawalSupportReaderKey.self] }
        set { self[WithdrawalSupportReaderKey.self] = newValue }
    }
}

@MainActor struct WithdrawalSupportContactView: View {
    @Environment(\.withdrawalSupportReader) private var reader
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var configuration: WithdrawalSupportSnapshot?
    @State private var loadedScope: WalletCommerceScope?
    @State private var issue: String?
    @State private var busy = false
    @State private var copyToast: LocalizedStringKey?
    @State private var actions = WithdrawalSupportActionFence()
    private var generation: UUID { actions.id }
    private struct ReaderKey: Equatable {
        let id: ObjectIdentifier?
        let scope: WalletCommerceScope?
    }
    private var readerKey: ReaderKey { .init(id: reader.map { ObjectIdentifier($0) }, scope: reader?.scope) }
    var body: some View {
        let offered = generation
        return NavigationStack {
            // CLB-r11-nat-settlement-01 (MP settlement wxml:43-46 → utils/withdraw-cs): plain Form; the title and
            // explanation are the Section header and footer, copy is a Button, the missing config an orange Label.
            Form {
                Section {
                    if busy { ProgressView("wallet.loading") }
                    if let configuration, loadedScope == reader?.scope {
                        LabeledContent("withdrawal.support.weChat") { Text(verbatim: configuration.contact.weChatID) }
                        Button { Task { await copy(configuration, offered: offered) } } label: {
                            Label("withdrawal.support.copyWeChat", systemImage: "doc.on.doc")
                        }
                        .disabled(busy).accessibilityIdentifier("withdrawal.support.copyWeChat")
                    } else if !busy {
                        Label("withdrawal.support.unconfigured", systemImage: "exclamationmark.bubble")
                            .foregroundStyle(CYColor.warningText)
                            .accessibilityIdentifier("withdrawal.support.unconfigured")
                    }
                    if let issue { Text(LocalizedStringKey(issue)).accessibilityIdentifier("withdrawal.support.status") }
                    Button("wallet.retry") { Task { await load(offered: offered) } }.disabled(busy)
                } header: {
                    Text("withdrawal.support.contact")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("withdrawal.support.explanation")
                        if configuration != nil, loadedScope == reader?.scope { Text("withdrawal.support.manualContact") }
                    }
                }
            }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { clear(); dismiss() }.accessibilityIdentifier("withdrawal.support.close") } }
        }
        .task(id: readerKey) { await load(offered: offered) }
        .onChange(of: scenePhase) { _, phase in
            clear()
            if phase == .active {
                let offered = generation
                Task { await load(offered: offered) }
            }
        }
        .onDisappear { clear() }
        .cyToast(message: $copyToast, tone: .success)
        .cyDomainSheet(detents: [.half, .full])
    }
    private func clear() {
        actions.invalidate(); configuration = nil; loadedScope = nil; issue = nil; busy = false; copyToast = nil
    }
    private func load(offered: UUID) async {
        guard scenePhase == .active, actions.accepts(offered), !Task.isCancelled else { return }
        clear(); let ticket = generation; let scope = reader?.scope; busy = true
        defer { if ticket == generation { busy = false } }
        do {
            guard let reader else { throw WithdrawalSupportFailure.unavailable }
            let value = try await reader.read()
            guard ticket == generation, scope == reader.scope, !Task.isCancelled else { return }
            configuration = value; loadedScope = scope
        } catch {
            guard ticket == generation, !Task.isCancelled else { return }
            // 1128 gap #11: a signed-out or switched account says so instead of "未配置".
            issue = (error as? WithdrawalSupportFailure) == .staleSession ? "withdrawal.support.signedOut" : "withdrawal.support.unconfigured"
        }
    }
    private func copy(_ displayed: WithdrawalSupportSnapshot, offered: UUID) async {
        guard scenePhase == .active, !Task.isCancelled, !busy, let reader, loadedScope == reader.scope,
              let ticket = actions.begin(offered: offered) else { return }
        let scope = reader.scope; busy = true; issue = nil
        defer { if ticket == generation { busy = false } }
        do {
            let contact = try await reader.contactForCopy(displayed)
            guard ticket == generation, scope == reader.scope, !Task.isCancelled else { return }
            // Contact only: no balance, account ID, token, draft amount, or diagnostics.
            UIPasteboard.general.setItems([["public.utf8-plain-text": contact]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
            issue = "localCopy.copied"
            copyToast = "localCopy.copied"
            UIAccessibility.post(notification: .announcement, argument: appLocalized("localCopy.copied", locale: locale))
        } catch {
            guard ticket == generation, !Task.isCancelled else { return }
            configuration = nil; loadedScope = nil; issue = "withdrawal.support.unconfigured"
        }
    }
}
