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
    var body: some View {
        Group {
            if let model = session.nearbyMerchantCoordinator {
                NearbyMerchantView(model: model, publicMerchant: session.publicMerchantHomeContext)
            } else { Text("coopflow.nearby.unavailable") }
        }.id(session.sessionRevision).privacySensitive()
    }
}
@MainActor struct NearbyMerchantView: View {
    @Bindable var model: NearbyMerchantCoordinator
    var publicMerchant = PublicMerchantHomeContext()
    @State private var purposeAccepted = false
    @State private var operation: Task<Void, Never>?
    @State private var publicHomeSelection: NearbyMerchantCoordinator.PublicHomeSelection?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    var body: some View {
        let page = NearbyMerchantPage.resolve(phase: model.phase, rows: model.rows)
        List {
            Section {
                // Mini opens with the privacy gate, then the result cards: purpose + consent stay one quiet block.
                Text("nearbyMerchant.purpose").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                Toggle("nearbyMerchant.consent", isOn: $purposeAccepted)
                Button("nearbyMerchant.search") { operation = Task { await model.search(purposeAccepted: purposeAccepted) } }
                    .buttonStyle(.cyPrimary).listRowBackground(Color.clear)
                    .disabled(!purposeAccepted || !model.available || model.isBusy)
                    .accessibilityIdentifier("nearbyMerchant.search")
                if !model.available { Text("coopflow.nearby.unavailable").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                if model.isBusy { CYSkeleton(variant: .card) }
                if model.phase == .locationFailed { Text("nearbyMerchant.locationFailed").font(CYTypography.meta).foregroundStyle(CYColor.warningText) }
                if model.phase == .failed {
                    // Mini `cy-error` fill state: title, reason, one retry action (below).
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text("cooperation.nearby.failed").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("cooperation.nearby.failed.detail").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
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
                        Text("nearbyMerchant.locationDenied.title").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("nearbyMerchant.locationDenied.detail").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
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
                        Text("nearbyMerchant.permissionDenied.title").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("nearbyMerchant.permissionDenied.detail").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("nearbyMerchant.permissionDenied")
                }
            }
            if page.phase == .ready || page.phase == .empty {
                Section {
                    Text("nearbyMerchant.total \(page.totalText)").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("nearbyMerchant.total")
                    if page.phase == .empty {
                        CYEmptyStateView(systemImage: "mappin.slash", title: "cooperation.nearby.empty", description: "cooperation.nearby.empty.detail")
                            .accessibilityIdentifier("cooperation.nearby.empty")
                    }
                    ForEach(model.rows) { row in
                        if model.publicHomeSelection(rowID: row.id) != nil {
                            Button {
                                publicHomeSelection = model.publicHomeSelection(rowID: row.id)
                            } label: { card(row) }
                                .accessibilityIdentifier("nearbyMerchant.open.\(row.id)")
                        } else {
                            VStack(alignment: .leading) {
                                card(row); Text("nearbyMerchant.unlisted").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                                // Source: unregistered leads with a server-released phone offer "电话联系" (system dialer only).
                                if let phone = row.callablePhone, let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                                    Link(destination: url) { Label("cooperation.nearby.call", systemImage: "phone") }
                                        .buttonStyle(.bordered).accessibilityIdentifier("cooperation.nearby.call.\(row.id)")
                                }
                            }
                        }
                    }
                }
            }
        }.cyMiniListScreen().appNavigationTitle("cooperation.nearby.title").accessibilityIdentifier("nearbyMerchant.list")
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
            }
            // A sheet leaves the browser mounted; exiting the browser always retires it.
            .onDisappear { cancel() }
            .onChange(of: purposeAccepted) { _, accepted in if !accepted { cancel() } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { cancel() } }
            .onChange(of: model.available) { _, available in if !available { cancel() } }
    }
    private func cancel() {
        operation?.cancel(); operation = nil; publicHomeSelection = nil
        model.cancel(); purposeAccepted = false
    }
    private func card(_ row: NearbyMerchantRow) -> some View {
        // Mini `cy-merchant-card variant="venue"`: name, then address and distance as quiet meta.
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: row.name).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
            if let address = row.address { Text(verbatim: address).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
            if let distance = NearbyMerchantPage.distanceText(row.distance) { Text(verbatim: distance).font(CYTypography.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary) }
        }
    }
}
