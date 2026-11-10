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
            Form {
                Section { CYHeroHeader("withdrawal.support.contact", subtitle: "withdrawal.support.explanation").listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }

                if busy { ProgressView("wallet.loading") }
                if let configuration, loadedScope == reader?.scope {
                    LabeledContent("withdrawal.support.weChat") { Text(verbatim: configuration.contact.weChatID) }
                    CYPillButton("withdrawal.support.copyWeChat", systemImage: "doc.on.doc") { Task { await copy(configuration, offered: offered) } }
                        .disabled(busy).accessibilityIdentifier("withdrawal.support.copyWeChat")
                    Text("withdrawal.support.manualContact")
                } else if !busy {
                    CYStatusChip("withdrawal.support.unconfigured", tone: .warning, systemImage: "exclamationmark.bubble")
                        .accessibilityIdentifier("withdrawal.support.unconfigured")
                }
                if let issue { Text(LocalizedStringKey(issue)).accessibilityIdentifier("withdrawal.support.status") }
                CYPillButton("wallet.retry", style: .tertiary) { Task { await load(offered: offered) } }.disabled(busy)
            }.cyGroupedSurface()
                .cyHeroScreen()
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
        .presentationDetents([.medium, .large])
    }
    private func clear() {
        actions.invalidate(); configuration = nil; loadedScope = nil; issue = nil; busy = false
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
            issue = "withdrawal.support.unconfigured"
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
            UIAccessibility.post(notification: .announcement, argument: appLocalized("localCopy.copied", locale: locale))
        } catch {
            guard ticket == generation, !Task.isCancelled else { return }
            configuration = nil; loadedScope = nil; issue = "withdrawal.support.unconfigured"
        }
    }
}
