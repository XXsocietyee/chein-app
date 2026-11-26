import SwiftUI
import UIKit

/// Supplied concretely by the ordinary session host, using existing readers/factories.
@MainActor struct RoamStampAlbumContinuation {
    let reader: any RoamExperienceReading
    let camera: () -> AnyView
}

/// Immutable result-page owner. The confirmed target still validates its original reader and account.
struct RoamCreatedStampReadOwner: Hashable {
    let target: RoamCreatedStampTarget
    let readerID: ObjectIdentifier
    let identity: RoamExperienceIdentity?
    @MainActor init(target: RoamCreatedStampTarget, reader: any RoamExperienceReading) {
        self.target = target; readerID = ObjectIdentifier(reader); identity = reader.identity
    }
}

/// Cancellation is checked before invoking refresh, because that original method resets its lookup.
/// Only reads live here. The original create receipt, upload and pending journal are untouched.
@MainActor final class RoamCreatedStampReadPresentation: ObservableObject {
    let lookup: RoamCreatedStampLookup
    let target: RoamCreatedStampTarget
    let reader: any RoamExperienceReading
    @Published private var revision = 0
    private var mounted = false
    private var hasDisappeared = false
    /// One return from a pushed album may be reported by both SwiftUI and UIKit. The second report must not read again.
    private var returnReadDone = false
    private var operation = UUID()
    private var work: Task<Void, Never>?
    init(target: RoamCreatedStampTarget, reader: any RoamExperienceReading) {
        self.target = target; self.reader = reader; lookup = .init(target: target, reader: reader)
    }
    func appear() {
        if returnReadDone { mounted = true; return }
        let alreadyMounted = mounted
        mounted = true
        // Still on screen: the album pop is delivered by the navigation anchor, not a second onAppear.
        if alreadyMounted { return }
        retire()
        let returning = hasDisappeared
        hasDisappeared = false
        if returning { returnReadDone = true }
        readAction(refresh: true)()
    }
    func disappear() { mounted = false; hasDisappeared = true; returnReadDone = false; retire() }
    /// The result stayed on the navigation stack under the album. Popping that album is the reread, even when SwiftUI does not call `onAppear` again.
    func rereadAfterCover() {
        guard !returnReadDone else { return }
        returnReadDone = true; hasDisappeared = false; mounted = true; retire(); readAction(refresh: true)()
    }
    private func retire() {
        operation = UUID(); work?.cancel(); work = nil; lookup.cancel(); revision &+= 1
    }
    private func accepts(_ offered: UUID) -> Bool {
        mounted && operation == offered && !Task.isCancelled && target.isCurrent(reader: reader)
    }
    func readAction(refresh: Bool = false) -> () -> Void {
        let offered = operation
        return { [weak self] in
            guard let self, self.accepts(offered) else { return }
            self.operation = UUID(); let issued = self.operation
            self.work?.cancel()
            self.work = Task { [weak self] in
                guard let self, self.accepts(issued) else { return }
                // Do not let a cancelled queued refresh call cancel() on a newer lookup generation.
                if refresh { await self.lookup.refresh() } else { await self.lookup.loadNext() }
                guard self.operation == issued else { return }
                self.work = nil; self.operation = UUID(); self.revision &+= 1
            }
        }
    }
}

@MainActor struct RoamCreatedStampView: View {
    let target: RoamCreatedStampTarget
    let album: RoamStampAlbumContinuation
    var body: some View {
        RoamCreatedStampContent(target: target, album: album)
            .id(RoamCreatedStampReadOwner(target: target, reader: album.reader))
    }
}

@MainActor private struct RoamCreatedStampContent: View {
    let target: RoamCreatedStampTarget
    let album: RoamStampAlbumContinuation
    @StateObject private var presentation: RoamCreatedStampReadPresentation
    private var lookup: RoamCreatedStampLookup { presentation.lookup }
    init(target: RoamCreatedStampTarget, album: RoamStampAlbumContinuation) {
        self.target = target; self.album = album
        _presentation = StateObject(wrappedValue: .init(target: target, reader: album.reader))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !target.isCurrent(reader: album.reader) || lookup.phase == .unavailable {
                    CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.createdStamp.changed")
                        .accessibilityIdentifier("roam.createdStamp.changed")
                } else {
                    RoamExperienceNotice(offline: album.reader.isOfflineExample)
                    CYHeroHeader("roam.createdStamp.confirmed", subtitle: "roam.createdStamp.readNotice")
                    LabeledContent("roam.createdStamp.id", value: String(target.stampID)).monospacedDigit()
                    result
                    NavigationLink {
                        RoamStampAlbumView(reader: album.reader, stampDestination: album.camera)
                    } label: { CYPillButton("roam.createdStamp.browse", style: .primary, systemImage: "rectangle.stack") {}.allowsHitTesting(false) }
                        .buttonStyle(.plain)
                        .disabled(!album.reader.isConfigured)
                        .accessibilityIdentifier("roam.createdStamp.browse")
                }
            }.padding(CYSpacing.pageHorizontal)
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .cyPageTitle("roam.createdStamp.title")
        .background { RoamCreatedStampCoverReturn(presentation: presentation).frame(width: 0, height: 0) }
        .onAppear { presentation.appear() }
        .onDisappear { presentation.disappear() }
        .accessibilityIdentifier("roam.createdStamp.result")
    }
    @ViewBuilder private var result: some View {
        let refresh = presentation.readAction(refresh: true), next = presentation.readAction()
        switch lookup.phase {
        case .idle, .loading:
            CYSkeleton().accessibilityLabel(Text("roam.loading"))
        case .found:
            if let stamp = lookup.stamp, album.reader.isConfigured {
                RoamStampCard(stamp: stamp, offline: album.reader.isOfflineExample)
                    .cyStampSlam(trigger: true)
                    .accessibilityIdentifier("roam.createdStamp.match")
            }
            CYPillButton("action.retry", style: .tertiary, systemImage: "arrow.clockwise") { refresh() }
        case .more:
            Text("roam.createdStamp.moreHint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            CYPillButton("roam.experience.loadMore", style: .secondary) { next() }
                .accessibilityIdentifier("roam.createdStamp.more")
        case .hidden:
            Label("roam.createdStamp.hidden", systemImage: "eye.slash")
            CYPillButton("action.retry", style: .tertiary, systemImage: "arrow.clockwise") { refresh() }
        case .missing:
            Text("roam.createdStamp.missing")
            CYPillButton("action.retry", style: .tertiary, systemImage: "arrow.clockwise") { refresh() }
        case .failed:
            if let error = lookup.error { RoamExperienceIssue(error: error) { next() } }
        case .unavailable:
            EmptyView()
        }
    }
}

/// A pushed album covers this result without removing it. The pop is a UIKit appearance, which is what rereads the confirmed id.
@MainActor private struct RoamCreatedStampCoverReturn: UIViewControllerRepresentable {
    let presentation: RoamCreatedStampReadPresentation
    func makeUIViewController(context: Context) -> Controller { Controller(presentation: presentation) }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.presentation = presentation }
    @MainActor final class Controller: UIViewController {
        var presentation: RoamCreatedStampReadPresentation
        private var appeared = false
        private var covered = false
        init(presentation: RoamCreatedStampReadPresentation) {
            self.presentation = presentation; super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { return nil }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            let shouldReread = covered && transitionCoordinator?.isCancelled != true
            covered = false; appeared = true
            if shouldReread { presentation.rereadAfterCover() }
        }
        override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); noteCover() }
        override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); noteCover() }
        private func noteCover() {
            // isMovingFromParent stays false for a non-animated transition, so the stack is the signal.
            // A pushed album leaves this host installed and not on top. Popping the result removes the host.
            guard appeared, transitionCoordinator?.isCancelled != true, coveredByPush else { return }
            covered = true
        }
        private var coveredByPush: Bool {
            var current: UIViewController? = self
            while let value = current {
                if let navigation = value.navigationController {
                    var node: UIViewController? = value
                    while let item = node {
                        if navigation.viewControllers.contains(where: { $0 === item }) {
                            return navigation.topViewController !== item
                        }
                        node = item.parent
                    }
                }
                current = value.parent
            }
            return false
        }
    }
}
