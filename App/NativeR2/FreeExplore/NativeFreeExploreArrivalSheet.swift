import SwiftUI

/// Native r2 stop arrival unlock (spec §6 "Arrival unlock"): a medium sheet over the map with the store, the
/// unlock rule and one prominent 我已到达. The write is the existing `PlayArrivalService.arrive` (one when-in-use
/// fix, `PlayArrivalPolicy` radius, `/api/play/arrive` through the coordinator); an unknown result re-reads and is
/// never re-sent. Feedback stays in the sheet: a too-far result is a footer line, success is a sealed label plus
/// `.sensoryFeedback(.success)`.
@MainActor struct NativeFreeExploreArrivalSheet: View {
    @Bindable var model: PlayExperienceCoordinator
    @Bindable var arrival: PlayArrivalService
    let nodeID: Int
    let onOpenStore: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var node: PlayNode? {
        guard model.gameplayMode == .freeExploration else { return nil }
        return model.snapshot?.visibleNodes.first { $0.id == nodeID }
    }

    var body: some View {
        NavigationStack {
            List {
                if let node, let snapshot = model.snapshot {
                    Section {
                        LabeledContent {
                            Text(LocalizedStringKey(FreeExplorationPresentation.state(of: node, in: snapshot).titleKey))
                        } label: {
                            FreeExplorationStoreName(name: node.name).font(.headline)
                        }
                        if node.addressHidden != true, let address = node.address, !address.isEmpty {
                            Label { Text(verbatim: address) } icon: { Image(systemName: "mappin.and.ellipse") }
                        }
                        if let hours = node.businessTime, !hours.isEmpty {
                            LabeledContent("play.businessTime") { Text(verbatim: hours) }
                        }
                    } header: {
                        if arrival.phase == .succeeded {
                            Label("nativeR2.freeExplore.arrival.unlocked", systemImage: "checkmark.seal.fill")
                                .nativeR2BounceOnAppear()
                        } else {
                            Label("playFree.story.locked", systemImage: "lock.fill")
                                .accessibilityLabel(Text("playFree.story.locked.a11y"))
                        }
                    } footer: {
                        rule(node)
                    }
                    if let hook = node.cardHookLong, !hook.isEmpty {
                        Section { Text(verbatim: hook) }
                    }
                    statusSection
                } else if model.phase == .loading || model.phase == .submitting {
                    ProgressView("playx.loading").frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView("playFree.store.unavailable", systemImage: "storefront")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("nativeR2.freeExplore.arrival.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("nativeR2.freeExplore.close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { actions.padding() }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.success, trigger: arrival.phase == .succeeded, condition: CYHapticTransition.isOn)
        .accessibilityIdentifier("nativeR2.freeExplore.arrival")
    }

    /// The same rule copy as `FreeExplorationLockCard`.
    @ViewBuilder private func rule(_ node: PlayNode) -> some View {
        if node.visitCheck == .scan {
            Text("playFree.story.scanUnlock")
        } else if node.visitCheck == .online {
            Text("playFree.story.unlock.scan")
        } else {
            Text("playFree.story.unlock.gps \(node.visitRadius ?? PlayArrivalPolicy.visitDefaultRadiusMeters)")
        }
    }

    @ViewBuilder private var statusSection: some View {
        switch arrival.phase {
        case .idle:
            EmptyView()
        case .locating:
            Section { ProgressView("playArrival.locating") }
        case .submitting:
            Section { ProgressView("playArrival.submitting") }
        case .succeeded:
            Section { Label("playArrival.succeeded", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
        case .rejected(let rejection):
            Section {
                if let message = rejection.message, !message.isEmpty {
                    Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }
                } else {
                    Label(LocalizedStringKey(rejection.reason.localizationKey), systemImage: "exclamationmark.triangle")
                }
            } footer: {
                if let distance = rejection.distanceMeters { Text("playArrival.distance \(distance)") }
            }
        case .unknown:
            Section {
                Label("playArrival.unknown", systemImage: "questionmark.circle")
                Button("playArrival.reread") { Task { await arrival.reread() } }
            }
        case .unavailable:
            Section { Label("playArrival.unavailable", systemImage: "nosign") }
        case .locationUnavailable:
            Section {
                Label("playArrival.location.unavailable", systemImage: "location.slash")
            } footer: {
                Text("nativeR2.freeExplore.arrival.scanInstead")
            }
        }
    }

    @ViewBuilder private var actions: some View {
        if arrival.phase == .succeeded {
            Button { dismiss(); onOpenStore() } label: {
                Text("nativeR2.freeExplore.map.open").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("nativeR2.freeExplore.arrival.open")
        } else if arrival.offer(for: nodeID) != nil {
            Button {
                let context = model.interactionContext
                Task { await arrival.arrive(nodeID: nodeID, context: context) }
            } label: {
                Label("playArrival.action", systemImage: "location.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(arrival.isBusy || arrival.phase == .unknown)
            .accessibilityIdentifier("playArrival.action")
        } else {
            // Scan / online unlocks and stores that need no arrival continue on the store page.
            Button { dismiss(); onOpenStore() } label: {
                Text("nativeR2.freeExplore.map.open").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
