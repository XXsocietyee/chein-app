import SwiftUI

struct SocialIssueView: View {
    let error: Error
    var retry: (() -> Void)? = nil
    private var message: LocalizedStringKey {
        switch error {
        case APIError.notConfigured: return "social.notConfigured"
        case APIError.unauthorized, SocialActionBlock.signIn: return "social.signIn"
        case SocialActionBlock.emptyText: return "social.emptyText"
        case SocialActionBlock.ownerRequired: return "social.ownerRequired"
        case SocialActionBlock.commentsClosed: return "social.commentsClosed"
        case SocialActionBlock.pending: return "social.unknown"
        case SocialActionBlock.changed, SocialActionBlock.cancelled: return "social.changed"
        default: return "social.failed"
        }
    }
    var body: some View {
        Group {
            if error is URLError {
                ContentUnavailableView {
                    Label { Text(message).accessibilityIdentifier("social.issue") } icon: { Image(systemName: "wifi.slash") }
                } actions: {
                    if let retry {
                        Button("action.retry", action: retry)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("social.issue.retry")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.circle")
                        .fixedSize(horizontal: false, vertical: true)
                    if case SocialAccountFailure.rejected(_, let text) = error, let text {
                        Text(verbatim: text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if let retry {
                        Button(action: retry) { Label("action.retry", systemImage: "arrow.clockwise") }
                            .buttonStyle(.bordered)
                    }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("social.issue")
            }
        }
    }
}
/// Includes the reader instance because its immutable deployment may have changed.
/// The extra revision retires role/credential ABA even when the visible identity repeats.
struct SocialReadPresentationKey: Hashable {
    let reader: ObjectIdentifier
    let request: String
    let identity: SocialAccountIdentity
    let revision: UInt64
    let configured: Bool
    let requiresSignIn: Bool
    @MainActor init(reader: any SocialAccountReading, request: String, requiresSignIn: Bool) {
        self.reader = ObjectIdentifier(reader); self.request = request; self.requiresSignIn = requiresSignIn
        identity = reader.identity; revision = reader.presentationRevision; configured = reader.isConfigured
    }
}
@MainActor struct SocialReadScreen<Value, Content: View>: View {
    let reader: any SocialAccountReading
    let requestKey: String
    var requiresSignIn = false
    let load: () async throws -> Value
    @ViewBuilder var content: (Value) -> Content
    @State private var value: Value?
    @State private var error: Error?
    @State private var busy = false
    @State private var generation = 0
    @State private var loadedKey: SocialReadPresentationKey?
    @State private var loads = SignedInContentDetailLoadOwner()
    @State private var presentChildren = 0
    private var key: SocialReadPresentationKey {
        .init(reader: reader, request: requestKey, requiresSignIn: requiresSignIn)
    }
    var body: some View {
        Group {
            if reader.isOfflineExample {
                CYOfflineBanner().accessibilityIdentifier("social.offline")
            }
            if requiresSignIn && reader.identity.accountID == nil { SocialIssueView(error: APIError.unauthorized) }
            else if !reader.isConfigured { SocialIssueView(error: APIError.notConfigured) }
            else if loadedKey != key || busy { ProgressView().padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).accessibilityElement(children: .ignore).accessibilityLabel(Text("social.loading")) }
            else if let error { SocialIssueView(error: error) { loadedKey = nil; loads.start { await reload() } } }
            else if let value { content(value) }
        }
        .task(id: key) { await loads.run { await reload() } }
        // Inside a List the Group's modifiers sit on each child, so a refresh that swaps the rows for the skeleton
        // fires the rows' onDisappear while the skeleton is already reading; cancelling there left the section blank
        // after pull-to-refresh (guide 玩法文档). Cancel only once no child of this screen is on screen.
        .onAppear { presentChildren += 1 }
        .onDisappear {
            presentChildren -= 1
            Task { @MainActor in
                await Task.yield()
                guard presentChildren <= 0 else { return }
                loads.cancel(); generation += 1; busy = false
            }
        }
    }
    /// Inside a List the Group's modifiers sit on each child, so a child swap (skeleton → content) re-runs the
    /// `.task(id:)`; reloading an answered key flipped back to the skeleton, whose disappearance cancelled the read
    /// and left an empty page (combined-r5 verify, A2-01 个人主页). An answered key keeps its answer; 重试 clears the key first.
    private func reload() async {
        if loadedKey == key, !busy, value != nil || error != nil { return }
        generation += 1; let run = generation, captured = key
        value = nil; error = nil; busy = false; loadedKey = captured
        guard reader.isConfigured, !requiresSignIn || captured.identity.accountID != nil else { return }
        busy = true
        defer { if generation == run { busy = false } }
        do {
            let loaded = try await load()
            try Task.checkCancellation()
            guard generation == run, key == captured else { return }; value = loaded
        } catch is CancellationError { }
        catch { if !Task.isCancelled, generation == run, key == captured { self.error = error } }
    }
}

struct SocialOptionalCount: View {
    let title: LocalizedStringKey
    let count: Int?
    var body: some View { LabeledContent(title, value: count.map(String.init) ?? "—") }
}
extension SocialGuideMode {
    var titleKey: LocalizedStringKey { switch self { case .classic: return "social.guide.classic"; case .free: return "social.guide.free"; case .roam: return "social.guide.roam" } }
    var detailKey: LocalizedStringKey { switch self { case .classic: return "social.guide.classicDetail"; case .free: return "social.guide.freeDetail"; case .roam: return "social.guide.roamDetail" } }
    var icon: String { switch self { case .classic: return "person.3"; case .free: return "map"; case .roam: return "figure.walk" } }
}
