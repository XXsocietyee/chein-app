import SwiftUI
import UIKit

private struct CooperationNearbyDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}
extension EnvironmentValues {
    var cooperationNearbyDestination: (@MainActor () -> AnyView)? {
        get { self[CooperationNearbyDestinationKey.self] }
        set { self[CooperationNearbyDestinationKey.self] = newValue }
    }
}
@MainActor struct SessionNearbyMerchantsView: View {
    @ObservedObject var session: AppSession
    /// MC8-33-3: `?topicId=&topicName=` (or coop-list 再邀别人) scopes the page to one topic.
    var topic: CoopNearbyTopicContext? = nil
    var body: some View {
        Group {
            if session.account == nil {
                // MC7-33-8: a guest sees 登录后查看附近商家 + 登录 (MP coop/nearby/index.wxml:46), not plain text.
                List {
                    MerchantCoopSignInState(title: "merchantCoop.nearby.signIn", identifier: "nearbyMerchant.signIn")
                        .listRowBackground(Color.clear)
                }
                .cyMiniListScreen().cyPageTitle("cooperation.nearby.title")
            } else if let model = session.nearbyMerchantCoordinator {
                NearbyMerchantView(model: model, publicMerchant: session.publicMerchantHomeContext,
                                   topicScope: Self.topicScope(session: session, topic: topic))
            } else { Text("coopflow.nearby.unavailable") }
        }.id(session.sessionRevision).privacySensitive()
    }
}
@MainActor struct NearbyMerchantView: View {
    @Bindable var model: NearbyMerchantCoordinator
    var publicMerchant = PublicMerchantHomeContext()
    /// MC8-33-1/-2/-5: topic mode (邀请商家): invitable merge and 邀请补位. Nil keeps the plain 找商家 page.
    var topicScope: NearbyMerchantTopicScope? = nil
    @State private var invitable: [NearbyMerchantInvitableRow] = []
    @State private var invitableFailed = false
    @State private var purposeAccepted = false
    @State private var operation: Task<Void, Never>?
    @State private var publicHomeSelection: NearbyMerchantCoordinator.PublicHomeSelection?
    @State private var toastMessage: String?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    var body: some View {
        let page = NearbyMerchantPage.resolve(phase: model.phase, rows: model.rows)
        List {
            if let topicScope { Section { NearbyMerchantTopicHeader(topic: topicScope.topic) } }
            Section {
                // Mini opens with the privacy gate, then the result cards: purpose + consent stay one quiet block.
                Text("nearbyMerchant.purpose").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Toggle("nearbyMerchant.consent", isOn: $purposeAccepted)
                Button("nearbyMerchant.search") { operation = Task { await model.search(purposeAccepted: purposeAccepted) } }
                    .buttonStyle(.cyPrimary).listRowBackground(Color.clear)
                    .disabled(!purposeAccepted || !model.available || model.isBusy)
                    .accessibilityIdentifier("nearbyMerchant.search")
                if !model.available { Text("coopflow.nearby.unavailable").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                if model.isBusy { CYSkeleton(variant: .card) }
                if model.phase == .locationFailed { Text("nearbyMerchant.locationFailed").cyText(.meta).foregroundStyle(CYColor.warningText) }
                if model.phase == .failed {
                    // Mini `cy-error` fill state: title, reason, one retry action (below).
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text("cooperation.nearby.failed").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("cooperation.nearby.failed.detail").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("cooperation.nearby.failed")
                }
                if model.phase == .locationFailed || model.phase == .failed {
                    // Source `cy-error` retry: re-run the same explicit, consented search.
                    CYPillButton("nearbyMerchant.retry", style: .secondary) {
                        operation = Task { await model.search(purposeAccepted: purposeAccepted) }
                    }
                    .disabled(!purposeAccepted || !model.available || model.isBusy)
                    .accessibilityIdentifier("nearbyMerchant.retry")
                }
                if model.phase == .locationDenied {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text("nearbyMerchant.locationDenied.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("nearbyMerchant.locationDenied.detail").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        CYPillButton("nearbyMerchant.openSettings", style: .secondary) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.frame(minHeight: 44).accessibilityIdentifier("nearbyMerchant.openSettings")
                            .accessibilityLabel(Text("nearbyMerchant.openSettings"))
                            .accessibilityValue(Text("nearbyMerchant.locationDenied.title"))
                            .accessibilityHint(Text("nearbyMerchant.locationDenied.detail"))
                    }.accessibilityElement(children: .contain).accessibilityIdentifier("nearbyMerchant.locationDenied")
                }
                if model.phase == .permissionDenied {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("nearbyMerchant.permissionDenied.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("nearbyMerchant.permissionDenied.detail").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("nearbyMerchant.permissionDenied")
                }
            }
            if page.phase == .ready || page.phase == .empty {
                Section {
                    Text("nearbyMerchant.total \(page.totalText)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("nearbyMerchant.total")
                    if invitableFailed {
                        Text("merchantCoop.nearby.topic.failed").cyText(.meta).foregroundStyle(CYColor.warningText)
                            .accessibilityIdentifier("nearbyMerchant.topic.failed")
                    }
                    if page.phase == .empty {
                        // Image parity: MP cy-empty kind="empty" → MPAsset.EmptyState art via "tray".
                        CYEmptyState(systemImage: "tray", "cooperation.nearby.empty")
                            .accessibilityIdentifier("cooperation.nearby.empty")
                        // MC7-33-7: MP 刷新附近商家 re-runs the same consented search.
                        Button { operation = Task { await model.search(purposeAccepted: purposeAccepted) } } label: {
                            Label("merchantCoop.nearby.refresh", systemImage: "arrow.clockwise").frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .disabled(!purposeAccepted || !model.available || model.isBusy)
                        .accessibilityIdentifier("cooperation.nearby.refresh")
                    }
                    ForEach(model.rows) { row in
                        if model.publicHomeSelection(rowID: row.id) != nil {
                            Button {
                                publicHomeSelection = model.publicHomeSelection(rowID: row.id)
                            } label: { card(row) }
                                .accessibilityIdentifier("nearbyMerchant.open.\(row.id)")
                            if let topicScope, let member = row.memberID,
                               invitable.first(where: { $0.memberID == member })?.hasReplacement == true {
                                NearbyMerchantReplacementLink(scope: topicScope, memberID: member)
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Button {
                                    toastMessage = MerchantCloseCopy.text("这家还没在平台建档，先电话联系", "Not registered yet — call directly", locale)
                                } label: {
                                    card(row)
                                }
                                .buttonStyle(.plain)
                                Text("nearbyMerchant.unlisted").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                                // Source: unregistered leads with a server-released phone offer "电话联系" (system dialer only).
                                if let phone = row.callablePhone, let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                                    Link(destination: url) { Label("cooperation.nearby.call", systemImage: "phone") }
                                        .buttonStyle(.bordered).accessibilityIdentifier("cooperation.nearby.call.\(row.id)")
                                }
                            }
                        }
                    }
                    if let topicScope {
                        let nearbyMembers = Set(model.rows.compactMap(\.memberID))
                        NearbyMerchantInvitableOnlyRows(scope: topicScope, rows: invitable.filter { !nearbyMembers.contains($0.memberID) },
                                                        publicMerchant: publicMerchant)
                    }
                }
            }
        }.cyMiniListScreen().cyPageTitle(topicScope == nil ? "cooperation.nearby.title" : "merchantCoop.nearby.topic.title")
            .accessibilityIdentifier("nearbyMerchant.list")
            .modifier(NearbyMerchantInvitableLoader(scope: topicScope, ready: model.phase == .ready,
                                                    rows: $invitable, failed: $invitableFailed))
            .sheet(item: $publicHomeSelection) { selection in
                NavigationStack {
                    Group {
                        if model.isCurrent(selection), purposeAccepted {
                            PublicMerchantHomeView(target: selection.target, context: publicMerchant)
                        } else { Text("merchant.publicHome.unavailable") }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("action.close") {
                                guard publicHomeSelection?.id == selection.id else { return }
                                publicHomeSelection = nil
                            }
                                .accessibilityIdentifier("nearbyMerchant.closeHome")
                        }
                    }
                }
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
            }
            // A sheet leaves the browser mounted; exiting the browser always retires it.
            .onDisappear { cancel() }
            .onChange(of: purposeAccepted) { _, accepted in if !accepted { cancel() } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { cancel() } }
            .onChange(of: model.available) { _, available in if !available { cancel() } }
        .cyToast(verbatimMessage: $toastMessage)
        .cyDomainScreen(.merchant)
    }
    private func cancel() {
        operation?.cancel(); operation = nil; publicHomeSelection = nil
        model.cancel(); purposeAccepted = false
    }
    private func card(_ row: NearbyMerchantRow) -> some View {
        // Mini `cy-merchant-card variant="venue"`: name, then address and distance as quiet meta.
        // MC8-33-8: the MP card images (default cover + citylink brand, pin, chevron) via NearbyMerchantCardChrome.
        NearbyMerchantCardChrome {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: row.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            if let address = row.address { NearbyMerchantAddressLine(address: address) }
            if let member = row.memberID, let text = invitable.first(where: { $0.memberID == member })?.chapterText {
                NearbyMerchantChapterLine(text: text)
            }
            if let distance = NearbyMerchantPage.distanceText(row.distance) { Text(verbatim: distance).cyText(.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary) }
        }
        }
    }
}
