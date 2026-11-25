import SwiftUI

/// A distinct official-event destination; never replace ActivityBrowserView with this screen.
@MainActor struct OfficialEventsBrowserView: View {
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator? = nil
    var onClose: (() -> Void)? = nil
    var onLogin: (() -> Void)? = nil
    var topicLinks: OfficialTopicLinks? = nil
    @StateObject private var sourceObservation = OfficialReadInvalidationObserver()
    @State private var bucket: OfficialEventBucket = .live
    @State private var keyword = ""
    @State private var publisherScope: UUID?
    @State private var canPublish = false
    private var query: OfficialEventBrowseQuery { .sourceList(bucket: bucket, keyword: keyword) }
    private var privateList: Bool { query.isPrivate }
    /// Round 4 copy (MP activity/list/index.wxml:32-33): the 我的 tab says 登录后查看我的活动 / 当前身份不能查看这些活动.
    private static func mineIssueLabel(_ issue: OfficialScreenIssue) -> LocalizedStringKey? {
        switch issue {
        case .unauthorized: return "official.mine.signInRequired"
        case .forbidden, .noPublisherPermission: return "official.mine.forbidden"
        default: return nil
        }
    }
    private var mineIssueLabelIfPrivate: ((OfficialScreenIssue) -> LocalizedStringKey?)? {
        privateList ? { Self.mineIssueLabel($0) } : nil
    }
    /// R7-PC-C3-1: no own NavigationStack. The deep link pushes this into the caller's stack; the 首页 sheet wraps it.
    var body: some View {
        Group {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    // Source order: search (hidden on "mine"), chip tabs, then the summary row.
                    if bucket.isSearchable {
                        TextField("official.search", text: $keyword)
                            .textFieldStyle(.plain).submitLabel(.search)
                            .padding(.horizontal, CYSpacing.lg)
                            .frame(minHeight: 44)
                            .background(CYColor.bgElevated, in: Capsule()).accessibilityIdentifier("official.search")
                    }
                    // Source `cy-tabs variant="chip"`: left-aligned capsules, the selected one solid.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CYSpacing.sm) {
                            ForEach(OfficialEventBucket.allCases) { value in
                                OfficialEventBucketChip(value: value, bucket: $bucket)
                            }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: bucket)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("official.filter"))
                    .accessibilityIdentifier("official.filter")
                }.padding(.horizontal)
                OfficialReadScreen(reader: reader, isPrivate: privateList, requestID: privateList ? "mine" : "public", onLogin: onLogin,
                                   issueLabel: mineIssueLabelIfPrivate,
                                   load: { if privateList { return try await reader.myEvents() }; return try await reader.events(city: nil) }) { rows in
                    eventList(rows)
                }
            }
            .cyPageTitle("official.title") // X2: pushed page, inline title
            .cyHideTabBar()
            .toolbar {
                if let onClose { ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) } }
                // The app has no WeChat capsule, so 我发布的 and 邀约 take the top-right slot.
                ToolbarItemGroup(placement: .topBarTrailing) { summaryLinks }
            }
            .task(id: reader.scope) { await checkPublisherPermission() }
            .onChange(of: reader.scope) { _, _ in keyword = "" }
        .onAppear { sourceObservation.bind(reader) }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in sourceObservation.bind(reader) }
        .onChange(of: sourceObservation.revision) { _, _ in
            guard sourceObservation.isBound(to: reader) else { return }
            keyword = ""
            if publisherScope != reader.scope { canPublish = false; publisherScope = nil }
        }
        .onDisappear { sourceObservation.stop() }
            .cyDomainScreen(.player)
            // Keep IDs on the search, filter, and action leaves. A VStack ID can
            // propagate to those controls and hide their individual identifiers.
        }
    }
    /// The mini-program puts these at the end of its summary row only because the WeChat capsule
    /// owns the top-right corner; here they are the page's two toolbar entries.
    @ViewBuilder private var summaryLinks: some View {
            if canPublish && publisherScope == reader.scope {
                NavigationLink { OfficialPublishedView(reader: reader, actions: actions, onLogin: onLogin) } label: {
                    Text("official.publishedLink")
                }.frame(minHeight: 44).accessibilityIdentifier("official.publishedLink")
            }
            NavigationLink { OfficialInboxView(reader: reader, actions: actions, publisher: canPublish && publisherScope == reader.scope, onLogin: onLogin) } label: {
                Text("official.inboxLink")
            }.frame(minHeight: 44).accessibilityIdentifier("official.inboxLink")
    }
    private func eventList(_ rows: [OfficialEvent]) -> some View {
        // pages/activity/list/index: the page model owns summary count, empty, and publish-link facts.
        let page = OfficialActivityListCoordinator.project(query: query, list: .success(rows),
                                                          canPublish: canPublish && publisherScope == reader.scope)
        let visible = page.visible
        return List {
            Section {
                Group {
                    if let count = page.summaryCount {
                        if query.isSearching { Text("official.summary.search \(query.trimmedKeyword) \(count)") }
                        else {
                            switch bucket {
                            case .live: Text("official.summary.live \(count)")
                            case .upcoming: Text("official.summary.upcoming \(count)")
                            case .ended: Text("official.summary.ended \(count)")
                            case .mine: Text("official.summary.mine \(count)")
                            }
                        }
                    } else {
                        Text(verbatim: page.summaryCountText)
                    }
                }.cyText(.caption).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("officialList.summary")
                if page.phase == .empty {
                    // R7-PC-C3-3 (MP list/index.js EMPTY_COPY): one title line per tab, no second line; the search keeps its hint.
                    CYEmptyState(systemImage: bucket == .upcoming && !query.isSearching ? "clock" : "sparkles",
                                 LocalizedStringKey(query.emptyTitleKey),
                                 detail: query.isSearching ? LocalizedStringKey(query.emptyDetailKey) : nil)
                        .listRowBackground(Color.clear)
                        .transition(.opacity)
                }
            }
            ForEach(visible) { event in
                NavigationLink { OfficialEventDetailView(id: event.id, reader: reader, actions: actions, onLogin: onLogin, topicLinks: topicLinks) } label: { OfficialEventCard(event: event) }
                    .buttonStyle(QuestifyCardButtonStyle()).questifyCardListRow()
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("official.event.\(event.id)")
            }
            Section { OfficialReadOnlyNotice(offline: reader.isOfflineExample) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.player)
    }
    private func checkPublisherPermission() async {
        let captured = reader.scope
        canPublish = false; publisherScope = nil
        guard reader.isConfigured, reader.isAuthenticated else { return }
        do {
            let allowed = try await reader.canPublish()
            guard !Task.isCancelled, reader.scope == captured else { return }
            canPublish = allowed; publisherScope = captured
        } catch { /* A failed capability check does not break public discovery or expose publishing. */ }
    }
}

/// One 官方活动 filter chip (split out so the chip row type-checks quickly).
@MainActor private struct OfficialEventBucketChip: View {
    let value: OfficialEventBucket
    @Binding var bucket: OfficialEventBucket
    var body: some View {
        let key = LocalizedStringKey(value.tabTitleKey)
        let selected = bucket == value
        let traits: AccessibilityTraits = selected ? [.isButton, .isSelected] : .isButton
        return CYFilterChip(key, isSelected: selected) { bucket = value }
            .pageTemplateControl(label: Text(key), traits: traits)
    }
}
