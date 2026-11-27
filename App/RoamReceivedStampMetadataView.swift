import SwiftUI
import UIKit

private struct RoamReceivedStampReaderKey: EnvironmentKey {
    static let defaultValue: RoamReceivedStampReader? = nil
}
extension EnvironmentValues {
    var roamReceivedStampReader: RoamReceivedStampReader? {
        get { self[RoamReceivedStampReaderKey.self] }
        set { self[RoamReceivedStampReaderKey.self] = newValue }
    }
}
private func receivedStampText(_ key: String) -> Text { Text(LocalizedStringKey("roam.receivedMetadata." + key), tableName: "RoamReceivedStamp") }

/// Bridges SwiftUI received-stamp identifiers and activation handlers into the UIKit view hierarchy
/// so hosted unit-test window probes (`UIAccessibilityIdentification` / `UIControl`) and VoiceOver
/// can deterministically discover and activate mounted controls even when the system AX server is not attached.
@MainActor private struct RoamReceivedStampAccessibilityAnchor: UIViewRepresentable {
    let id: String
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil

    func makeUIView(context: Context) -> RoamReceivedStampAccessibilityControl {
        let control = RoamReceivedStampAccessibilityControl(frame: .zero)
        control.isUserInteractionEnabled = false
        control.isAccessibilityElement = false
        control.backgroundColor = .clear
        return control
    }

    func updateUIView(_ control: RoamReceivedStampAccessibilityControl, context: Context) {
        control.accessibilityIdentifier = id
        control.isEnabled = isEnabled
        control.onActivate = action
    }

    static func dismantleUIView(_ control: RoamReceivedStampAccessibilityControl, coordinator: ()) {
        control.accessibilityIdentifier = nil
        control.onActivate = nil
        control.removeFromSuperview()
    }
}

/// Non-VoiceOver probe node. Hosted window probes cast with `as? UIAccessibilityIdentification`, which fails at
/// runtime for plain UIKit views, so the anchor exposes this explicitly conforming element in `accessibilityElements`.
@MainActor private final class RoamReceivedStampAccessibilityProbe: NSObject, UIAccessibilityIdentification {
    var accessibilityIdentifier: String?
    weak var control: RoamReceivedStampAccessibilityControl?
    override var isAccessibilityElement: Bool { get { false } set {} }
    override func accessibilityActivate() -> Bool {
        guard let control, control.isEnabled, let onActivate = control.onActivate else { return false }
        onActivate()
        return true
    }
}

@MainActor private final class RoamReceivedStampAccessibilityControl: UIControl {
    var onActivate: (() -> Void)?
    private let probe = RoamReceivedStampAccessibilityProbe()

    override var accessibilityIdentifier: String? {
        didSet { probe.accessibilityIdentifier = accessibilityIdentifier }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        probe.control = self
        accessibilityElements = [probe]
        addTarget(self, action: #selector(handleTouchUpInside), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTouchUpInside() {
        guard isEnabled else { return }
        onActivate?()
    }

    override func accessibilityActivate() -> Bool {
        guard isEnabled, let onActivate else { return false }
        onActivate()
        return true
    }
}

/// Mounted only outside the original album's lazy content; nil hosts remain unchanged.
@MainActor struct RoamReceivedStampNavigation: ViewModifier {
    let isEntry: Bool
    @Environment(\.roamReceivedStampReader) private var reader
    @State private var target: Target?
    private struct Target: Hashable { let id = UUID(); let owner: RoamAlbumReadOwner }
    func body(content: Content) -> some View {
        if isEntry, let reader {
            let offered = RoamAlbumReadOwner(reader: reader, scope: nil)
            let canOpen = reader.identity != nil && reader.isConfigured
            let openAction: () -> Void = {
                guard offered == RoamAlbumReadOwner(reader: reader, scope: nil), reader.identity != nil,
                      reader.isConfigured, target == nil else { return }
                target = .init(owner: offered)
            }
            content.safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: openAction) {
                        Label { receivedStampText("open") } icon: { Image(systemName: "tray.and.arrow.down") }
                    }
                    .disabled(!canOpen)
                    .background {
                        RoamReceivedStampAccessibilityAnchor(
                            id: "roam.receivedMetadata.open",
                            isEnabled: canOpen,
                            action: openAction
                        )
                    }
                    .accessibilityIdentifier("roam.receivedMetadata.open")
                    if !reader.isConfigured { Text(LocalizedStringKey(reader.identity == nil ? "roam.signInRequired" : "roam.notConfigured")).cyText(.meta) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.regularMaterial)
            }
            .onChange(of: offered) { _, _ in target = nil }
            .navigationDestination(item: $target) { target in
                if target.owner == RoamAlbumReadOwner(reader: reader, scope: nil) {
                    RoamReceivedStampMetadataDestination(reader: reader, owner: target.owner)
                } else { receivedStampText("changed") }
            }
        } else { content }
    }
}

/// Received metadata only. The original read-only scope never gains image, capture or exchange authority.
@MainActor struct RoamReceivedStampMetadataDestination: View {
    let reader: RoamReceivedStampReader
    let owner: RoamAlbumReadOwner
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var pageOwner = RoamAlbumPageOwner()
    @State private var scope: RoamStampAlbumReadOnlyScope?
    @State private var mounted = false
    @State private var didAttach = false
    /// mp-roam r3: true when mounted as the album's inline 收到的 tab (MP `cy-tabs`); the album keeps its own title.
    let inline: Bool
    init(reader: RoamReceivedStampReader, owner: RoamAlbumReadOwner? = nil, inline: Bool = false) {
        self.reader = reader; self.owner = owner ?? .init(reader: reader, scope: nil); self.inline = inline
    }
    private var isCurrent: Bool { owner == RoamAlbumReadOwner(reader: reader, scope: nil) }
    var body: some View {
        if inline {
            page
        } else {
            page.navigationTitle(receivedStampText("title")).navigationBarTitleDisplayMode(.inline)
        }
    }
    private var page: some View {
        Group {
            if !isCurrent { receivedStampText("changed") }
            else if reader.identity == nil { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.signInRequired") }
            else if !reader.isConfigured { CYEmptyState(systemImage: "lock", "roam.notConfigured") }
            else if scenePhase == .active {
                if let scope, scope.isCurrent {
                    RoamReceivedStampMetadataContent(reader: reader, scope: scope)
                        .id(scope.id).background { RoamAlbumMetadataLifetime(scope: scope).id(scope.id) }
                } else if didAttach {
                    VStack(spacing: 12) {
                        receivedStampText("retired")
                        Button { attach() } label: { receivedStampText("reopen") }
                            .background {
                                RoamReceivedStampAccessibilityAnchor(
                                    id: "roam.receivedMetadata.reopen",
                                    isEnabled: true,
                                    action: { attach() }
                                )
                            }
                            .accessibilityIdentifier("roam.receivedMetadata.reopen")
                    }.padding()
                } else { CYSkeleton().accessibilityLabel(Text("roam.loading")) }
            } else { Color.clear }
        }
        .onAppear { mounted = true; if !didAttach { attach() } }
        .onDisappear { mounted = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { scope?.retire() }
            else if !didAttach { attach() }
        }
        .onChange(of: RoamAlbumReadOwner(reader: reader, scope: nil)) { _, _ in scope?.retire() }
        .privacySensitive().accessibilityIdentifier("roam.receivedMetadata.page")
    }
    private func attach() {
        guard mounted, scenePhase == .active, isCurrent, reader.isConfigured, let identity = reader.identity else { return }
        scope?.retire()
        let fresh = RoamStampAlbumReadOnlyScope(reader: reader, identity: identity, isCurrent: { true })
        fresh.bind(to: pageOwner); scope = fresh; didAttach = true
    }
}

@MainActor private struct RoamReceivedStampMetadataContent: View {
    let reader: RoamReceivedStampReader
    let scope: RoamStampAlbumReadOnlyScope
    @StateObject private var presentation: RoamAlbumReadPresentation
    @State private var selectedStamp: RoamAlbumStamp?
    @Environment(\.scenePhase) private var scenePhase
    init(reader: RoamReceivedStampReader, scope: RoamStampAlbumReadOnlyScope) {
        self.reader = reader; self.scope = scope
        _presentation = StateObject(wrappedValue: .init(reader: reader, scope: scope))
    }
    private var pager: RoamAlbumPager { presentation.pager }
    private func openStamp(_ stamp: RoamAlbumStamp) {
        guard scenePhase == .active, scope.isCurrent, scope.matches(reader),
              pager.stamps.contains(stamp), selectedStamp == nil else { return }
        selectedStamp = stamp
    }
    var body: some View {
        let more = presentation.readAction(), refresh = presentation.refreshAction()
        List {
            if scope.matches(reader) {
                Section { receivedStampText("boundary").cyText(.bodyCompact).foregroundStyle(.secondary) }
                if let total = pager.total {
                    LabeledContent { Text(total, format: .number) } label: { receivedStampText("total") }
                }
                if let error = pager.error {
                    if CollectionReadAccess(error) == .denied { Label("roam.w208.entry.denied", systemImage: "lock") }
                    else { RoamExperienceIssue(error: error, retry: more) }
                }
                if pager.loaded && pager.stamps.isEmpty && pager.error == nil {
                    receivedStampText("empty")
                        .background { RoamReceivedStampAccessibilityAnchor(id: "roam.receivedMetadata.empty") }
                        .accessibilityIdentifier("roam.receivedMetadata.empty")
                }
                ForEach(pager.stamps.filter { !RoamHiddenStamps.contains($0.id) }) { stamp in
                    Button {
                        openStamp(stamp)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoamStampCard(stamp: stamp, offline: false, allowsRemoteImages: scope.allowsRemoteImages)
                            if let key = RoamReceivedStampKind.key(stamp.kind) { receivedStampText(key).cyText(.meta) }
                        }
                    }
                    .buttonStyle(.plain)
                    .background {
                        RoamReceivedStampAccessibilityAnchor(
                            id: "roam.receivedMetadata.record",
                            isEnabled: scope.isCurrent && pager.stamps.contains(stamp),
                            action: { openStamp(stamp) }
                        )
                    }
                    .accessibilityIdentifier("roam.receivedMetadata.record")
                }
                if presentation.loading { CYSkeleton().accessibilityLabel(Text("roam.loading")) }
                if pager.loaded && pager.hasMore && !presentation.loading {
                    Button("roam.experience.loadMore", action: more)
                        .background { RoamReceivedStampAccessibilityAnchor(id: "roam.receivedMetadata.more", action: more) }
                        .accessibilityIdentifier("roam.receivedMetadata.more")
                }
                if pager.loaded && !pager.hasMore && !pager.stamps.isEmpty && pager.error == nil {
                    receivedStampText("end").foregroundStyle(.secondary)
                        .background { RoamReceivedStampAccessibilityAnchor(id: "roam.receivedMetadata.end") }
                        .accessibilityIdentifier("roam.receivedMetadata.end")
                }
                if !presentation.loading {
                    Button("action.retry") { Task { await refresh() } }
                        .background { RoamReceivedStampAccessibilityAnchor(id: "roam.receivedMetadata.refresh", action: { Task { await refresh() } }) }
                        .accessibilityIdentifier("roam.receivedMetadata.refresh")
                }
            } else { receivedStampText("changed") }
        }.cyGroupedSurface()
        .navigationDestination(
            isPresented: Binding(
                get: { selectedStamp != nil },
                set: { if !$0 { selectedStamp = nil } }
            )
        ) {
            if let stamp = selectedStamp {
                RoamReceivedStampMetadataDetail(stamp: stamp, scope: scope, isCurrent: { scope.isCurrent && pager.stamps.contains(stamp) })
            }
        }
        .onAppear { presentation.appear(foreground: scenePhase == .active) }
        .onDisappear { presentation.disappear() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { selectedStamp = nil }
            presentation.setForeground(phase == .active)
        }
        .onChange(of: scope.isCurrent) { _, current in
            if !current { selectedStamp = nil }
        }
        .refreshable { await refresh() }
    }
}

@MainActor struct RoamReceivedStampMetadataDetail: View {
    let stamp: RoamAlbumStamp
    let scope: RoamStampAlbumReadOnlyScope
    let isCurrent: () -> Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingHide = false
    var body: some View {
        List {
            if scenePhase == .active && scope.isCurrent && isCurrent() && stamp.isVisible {
                RoamStampCard(stamp: stamp, offline: false, allowsRemoteImages: scope.allowsRemoteImages)
                receivedStampText("anonymous")
                    .background { RoamReceivedStampAccessibilityAnchor(id: "roam.receivedMetadata.anonymous") }
                    .accessibilityIdentifier("roam.receivedMetadata.anonymous")
                if let key = RoamReceivedStampKind.key(stamp.kind) {
                    LabeledContent { receivedStampText(key) } label: { receivedStampText("kind") }
                }
                receivedStampText("boundary").cyText(.bodyCompact).foregroundStyle(.secondary)
                Section {
                    Button(role: .destructive) { confirmingHide = true } label: {
                        Label("roam.stamp.hide", systemImage: "eye.slash").frame(minHeight: 44)
                    }.accessibilityIdentifier("roam.receivedMetadata.hide")
                    // Hiding is permanent on this device: confirm first (native destructive pattern).
                    .confirmationDialog(Text("roam.stamp.hide.footer"), isPresented: $confirmingHide, titleVisibility: .visible) {
                        Button("roam.stamp.hide", role: .destructive) { RoamHiddenStamps.hide(stamp.id); dismiss() }
                    }
                } footer: { Text("roam.stamp.hide.footer") }
            } else { receivedStampText("changed") }
        }.cyGroupedSurface().navigationTitle(receivedStampText("detail")).navigationBarTitleDisplayMode(.inline)
            .privacySensitive().accessibilityIdentifier("roam.receivedMetadata.detail")
    }
}
/// Only the original two kind values have labels; no author/location inference from metadata.
enum RoamReceivedStampKind {
    static func key(_ value: Int?) -> String? {
        switch value { case 0: return "freePhoto"; case 1: return "cancelledStamp"; default: return nil }
    }
}

/// App Store 1.2 user-content control: a received stamp can be hidden for good on this device.
enum RoamHiddenStamps {
    private static let key = "hiddenStampIDsV1"
    static func contains(_ id: Int, defaults: UserDefaults = .standard) -> Bool { ids(defaults).contains(id) }
    static func hide(_ id: Int, defaults: UserDefaults = .standard) {
        var all = ids(defaults); all.insert(id)
        defaults.set(Array(all).sorted(), forKey: key)
    }
    private static func ids(_ defaults: UserDefaults) -> Set<Int> { Set((defaults.array(forKey: key) as? [Int]) ?? []) }
}
