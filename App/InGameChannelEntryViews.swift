import SwiftUI

/// Coordinates unread summary polling and channel resolution for one in-game channel entry point.
@MainActor final class InGameChannelEntryModel: ObservableObject {
    @Published private(set) var summary: InGameChannelSummary?
    @Published private(set) var activeChannel: InGameChannelRef?
    @Published private(set) var isOpening = false
    @Published var errorMessage: String?

    var unreadCount: Int? {
        guard let summary, summary.unread > 0 else { return nil }
        return summary.unread
    }

    var isMuted: Bool {
        (summary?.muted ?? activeChannel?.muted ?? 0) == 1
    }

    func refresh(scope: InGameChannelScope, host: InGameChannelHost?) async {
        guard let host, host.reader.isSummaryConfigured, host.reader.identity != nil, scope.isValid else {
            summary = nil
            return
        }
        do {
            let value = try await host.reader.channelSummary(scope)
            guard !Task.isCancelled else { return }
            summary = value
        } catch is CancellationError {
            return
        } catch {
            if errorMessage == nil {
                summary = nil
            }
        }
    }

    func open(scope: InGameChannelScope, host: InGameChannelHost?) async {
        guard !isOpening else { return }
        guard let host, host.reader.isConfigured, host.reader.identity != nil, scope.isValid else {
            errorMessage = ""
            return
        }
        isOpening = true
        errorMessage = nil
        defer { isOpening = false }
        do {
            let resolved = try await host.reader.resolveChannel(scope)
            guard !Task.isCancelled else { return }
            activeChannel = resolved
        } catch is CancellationError {
            return
        } catch let failure as MessagingReadFailure {
            errorMessage = failure.message ?? ""
        } catch {
            errorMessage = ""
        }
    }

    func dismiss() {
        activeChannel = nil
    }
}

/// Reusable sheet presenting `MessagingHistoryView` in a `.medium`/`.large` detent sheet so
/// play/roam/city canvases remain visible underneath.
@MainActor struct InGameChannelSheetView: View {
    let channel: InGameChannelRef
    let host: InGameChannelHost
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            let conversation = channel.asConversation
            MessagingHistoryView(
                conversationID: channel.conversationId,
                conversation: conversation,
                reader: host.messagingReader,
                sender: host.messageSender(channel.conversationId),
                mediaReader: host.mediaReader,
                expanded: host.expanded
            )
            .id(host.viewIdentity())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("ingame.channel.close")
                    }
                    .accessibilityIdentifier("ingame.channel.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .cyPlayerSheetGlass()
    }
}

/// Attaches summary refresh, channel sheet presentation, and failure alerts to any entry control.
@MainActor private struct InGameChannelPresentationModifier: ViewModifier {
    @ObservedObject var model: InGameChannelEntryModel
    let scope: InGameChannelScope
    let host: InGameChannelHost
    let reloadTrigger: AnyHashable

    func body(content: Content) -> some View {
        content
            .disabled(model.isOpening)
            .task(id: AnyHashable([AnyHashable(scope), AnyHashable(host.reader.identity), reloadTrigger])) {
                await model.refresh(scope: scope, host: host)
            }
            .sheet(
                item: Binding(get: { model.activeChannel }, set: { if $0 == nil { model.dismiss() } }),
                onDismiss: { Task { await model.refresh(scope: scope, host: host) } }
            ) { channel in
                InGameChannelSheetView(channel: channel, host: host) {
                    model.dismiss()
                }
            }
            .alert("ingame.channel.errorTitle", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("ingame.channel.close", role: .cancel) { model.errorMessage = nil }
            } message: {
                if let msg = model.errorMessage, !msg.isEmpty {
                    Text(verbatim: msg)
                } else {
                    Text("ingame.channel.errorBody")
                }
            }
    }
}

/// Compact toolbar button with unread badge overlay for Play, Roam, and City HUDs.
@MainActor struct InGameChannelToolbarButton: View {
    let scope: InGameChannelScope
    let titleKey: LocalizedStringKey
    let accessibilityID: String
    var reloadTrigger: AnyHashable = 0

    @Environment(\.inGameChannelHost) private var host
    @StateObject private var model = InGameChannelEntryModel()

    var body: some View {
        if let host, host.reader.isConfigured, host.reader.identity != nil, scope.isValid {
            Button {
                Task { await model.open(scope: scope, host: host) }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: model.isOpening ? "ellipsis.bubble" : "bubble.left.and.bubble.right")
                        .cyText(.bodyMedium)
                        .frame(minWidth: 32, minHeight: 32)
                    IMUnreadBadge(count: model.unreadCount, muted: model.isMuted)
                        .offset(x: 6, y: -4)
                }
            }
            .accessibilityLabel(Text(titleKey))
            .accessibilityIdentifier(accessibilityID)
            .modifier(InGameChannelPresentationModifier(model: model, scope: scope, host: host, reloadTrigger: reloadTrigger))
        }
    }
}

/// Inline card/row button with title, last-message preview, and unread badge for detail & board panels.
@MainActor struct InGameChannelRowButton: View {
    let scope: InGameChannelScope
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let accessibilityID: String
    var reloadTrigger: AnyHashable = 0

    @Environment(\.inGameChannelHost) private var host
    @Environment(\.cyPalette) private var palette
    @StateObject private var model = InGameChannelEntryModel()

    var body: some View {
        if let host, host.reader.isConfigured, host.reader.identity != nil, scope.isValid {
            Button {
                Task { await model.open(scope: scope, host: host) }
            } label: {
                HStack(spacing: CYSpacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .cyText(.sectionTitle)
                        .foregroundStyle(palette.brand)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack(spacing: CYSpacing.xs) {
                            Text(titleKey)
                                .cyText(.bodyMedium)
                                .foregroundStyle(palette.textPrimary)
                            if model.isMuted {
                                Image(systemName: "bell.slash")
                                    .cyText(.meta)
                                    .foregroundStyle(palette.textTertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                        if let preview = model.summary?.lastMsgText, !preview.isEmpty {
                            Text(verbatim: preview)
                                .cyText(.meta)
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(1)
                        } else {
                            Text(subtitleKey)
                                .cyText(.meta)
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: CYSpacing.sm)
                    IMUnreadBadge(count: model.unreadCount, muted: model.isMuted)
                    if model.isOpening {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(CYTypography.meta.weight(.semibold))
                            .foregroundStyle(palette.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, CYSpacing.xs)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(titleKey))
            .accessibilityIdentifier(accessibilityID)
            .modifier(InGameChannelPresentationModifier(model: model, scope: scope, host: host, reloadTrigger: reloadTrigger))
        }
    }
}
