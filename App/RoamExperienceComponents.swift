import SwiftUI
import UIKit

@MainActor final class RoamHostedScopeTracker: ObservableObject {
    static let shared = RoamHostedScopeTracker()
    @Published private(set) var tick: UInt64 = 0
    private struct PassportState: Equatable {
        let owner: RoamPassportToolsPageOwner
        let isConfigured: Bool?
    }
    private struct PrivateState: Equatable {
        let scope: RoamPrivatePageScope
        let isConfigured: Bool
        let allowsWrites: Bool
    }
    private var passportStates: [ObjectIdentifier: PassportState] = [:]
    private var privateStates: [ObjectIdentifier: PrivateState] = [:]
    private var pendingNotify = false

    func observePassport(_ reader: (any RoamPassportToolsReading)?) {
        guard let reader else { return }
        let id = ObjectIdentifier(reader)
        let state = PassportState(owner: RoamPassportToolsPageOwner(reader), isConfigured: reader.isConfigured)
        guard passportStates[id] != state else { return }
        passportStates[id] = state
        scheduleNotify()
    }

    func observePrivate(_ tools: (any RoamPrivateToolsServing)?) {
        guard let tools else { return }
        let id = ObjectIdentifier(tools)
        let state = PrivateState(scope: RoamPrivatePageScope(tools), isConfigured: tools.isConfigured, allowsWrites: tools.allowsWrites)
        guard privateStates[id] != state else { return }
        privateStates[id] = state
        scheduleNotify()
    }

    private func scheduleNotify() {
        guard !pendingNotify else { return }
        pendingNotify = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pendingNotify = false
            self.tick &+= 1
        }
    }
}

@MainActor struct RoamHostedAccessibilityItem {
    let identifier: String
    var label: String? = nil
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil
}

@MainActor struct RoamHostedAccessibilityGroup: UIViewRepresentable {
    let items: [RoamHostedAccessibilityItem]

    func makeUIView(context: Context) -> RoamHostedAccessibilityGroupView {
        let view = RoamHostedAccessibilityGroupView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: RoamHostedAccessibilityGroupView, context: Context) {
        view.update(items: items)
    }

    static func dismantleUIView(_ view: RoamHostedAccessibilityGroupView, coordinator: ()) {
        view.update(items: [])
        view.removeFromSuperview()
    }
}

@MainActor private final class RoamHostedAccessibilityItemProbe: NSObject, UIAccessibilityIdentification {
    var accessibilityIdentifier: String?
    private let itemLabel: String?
    private let isEnabled: Bool
    private let onActivate: (() -> Void)?

    init(item: RoamHostedAccessibilityItem) {
        self.accessibilityIdentifier = item.identifier
        self.itemLabel = item.label
        self.isEnabled = item.isEnabled
        self.onActivate = item.action
        super.init()
        self.accessibilityLabel = item.label
    }

    override var isAccessibilityElement: Bool { get { false } set {} }

    override func accessibilityActivate() -> Bool {
        guard isEnabled, let onActivate else { return false }
        onActivate()
        return true
    }
}

@MainActor final class RoamHostedAccessibilityGroupView: UIView {
    func update(items: [RoamHostedAccessibilityItem]) {
        accessibilityElements = items.map { RoamHostedAccessibilityItemProbe(item: $0) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window = self.window, window.windowScene == nil,
           let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window.windowScene = scene
            window.makeKeyAndVisible()
        }
    }
}

@MainActor struct RoamHostedAccessibilityAnchor: UIViewRepresentable {
    let identifier: String
    var label: String? = nil
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil

    func makeUIView(context: Context) -> RoamHostedAccessibilityControl {
        let control = RoamHostedAccessibilityControl(frame: .zero)
        control.isUserInteractionEnabled = false
        control.isAccessibilityElement = false
        control.backgroundColor = .clear
        return control
    }

    func updateUIView(_ control: RoamHostedAccessibilityControl, context: Context) {
        control.accessibilityIdentifier = identifier
        control.accessibilityLabel = label
        control.isEnabled = isEnabled
        control.onActivate = action
    }

    static func dismantleUIView(_ control: RoamHostedAccessibilityControl, coordinator: ()) {
        control.accessibilityIdentifier = nil
        control.accessibilityLabel = nil
        control.onActivate = nil
        control.accessibilityElements = nil
        control.removeFromSuperview()
    }
}

@MainActor private final class RoamHostedAccessibilityProbe: NSObject, UIAccessibilityIdentification {
    var accessibilityIdentifier: String?
    weak var control: RoamHostedAccessibilityControl?
    override var isAccessibilityElement: Bool { get { false } set {} }
    override func accessibilityActivate() -> Bool {
        guard let control, control.isEnabled, let onActivate = control.onActivate else { return false }
        onActivate()
        return true
    }
}

@MainActor final class RoamHostedAccessibilityControl: UIControl {
    var onActivate: (() -> Void)?
    private let probe = RoamHostedAccessibilityProbe()

    override var accessibilityIdentifier: String? {
        didSet { probe.accessibilityIdentifier = accessibilityIdentifier }
    }

    override var accessibilityLabel: String? {
        didSet { probe.accessibilityLabel = accessibilityLabel }
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window = self.window, window.windowScene == nil,
           let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window.windowScene = scene
            window.makeKeyAndVisible()
        }
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

/// Example-content marker for offline samples only; live screens show nothing here.
struct RoamExperienceNotice: View {
    let offline: Bool
    var body: some View {
        if offline {
            Label("roam.experience.offline", systemImage: "testtube.2")
                .font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                .accessibilityIdentifier("roam.experience.notice")
        }
    }
}
struct RoamExperienceIssue: View {
    let error: Error
    var retry: (() -> Void)? = nil
    private var key: LocalizedStringKey {
        if error as? APIError == .unauthorized { return "roam.signInRequired" }
        if error as? APIError == .notConfigured { return "roam.notConfigured" }
        if error as? RoamExperienceFailure == .historyUnreadable { return "roam.experience.historyUnreadable" }
        return "roam.experience.readFailed"
    }
    var body: some View {
        let canRetry = retry != nil && error as? APIError != .unauthorized && error as? APIError != .notConfigured
        var items = [RoamHostedAccessibilityItem(identifier: "roam.experience.error")]
        if canRetry, let retry {
            items.append(RoamHostedAccessibilityItem(identifier: "roam.experience.retry", action: retry))
        }
        return VStack(alignment: .leading, spacing: 12) {
            Label(key, systemImage: "exclamationmark.circle").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
            if canRetry, let retry {
                CYPillButton("action.retry", style: .secondary, fullWidth: false, action: retry)
                    .accessibilityIdentifier("roam.experience.retry")
            }
        }.accessibilityElement(children: .contain)
            .background { RoamHostedAccessibilityGroup(items: items) }
            .accessibilityIdentifier("roam.experience.error")
    }
}
struct RoamExperienceCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading)
            .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
    }
}
struct RoamRouteSketchView: View {
    let record: RoamHistoryRecord
    var visibleSegments: Int? = nil
    var body: some View {
        let sketch = RoamRouteSketch(track: record.track, places: record.pois.map(\.point))
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color.accentColor.opacity(0.09))
            if sketch.track.isEmpty {
                Label("roam.experience.noTrack", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.caption).padding()
            } else {
                Canvas { context, size in
                    var path = Path()
                    let segmentCount = max(0, sketch.track.count - 1)
                    let pointCount = visibleSegments.map { min(segmentCount, max(0, $0)) + 1 } ?? sketch.track.count
                    for (index, point) in sketch.track.prefix(pointCount).enumerated() {
                        let position = CGPoint(x: point.x * size.width, y: point.y * size.height)
                        if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
                    }
                    context.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    for point in sketch.places {
                        let rect = CGRect(x: point.x * size.width - 5, y: point.y * size.height - 5, width: 10, height: 10)
                        context.fill(Path(ellipseIn: rect), with: .color(.primary))
                    }
                }.padding(8).accessibilityHidden(true)
            }
        }.frame(height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(sketch.track.isEmpty ? "roam.experience.noTrack" : "roam.experience.routeSketch"))
    }
}
struct RoamRecordedStats: View {
    let record: RoamHistoryRecord
    var body: some View {
        // Mini-program kv: 总距离 / 时长 / 探店 / 探索度; a missing value shows —.
        VStack(spacing: 8) {
            LabeledContent("roam.experience.distance") {
                if let distance = record.distance { Text(distance, format: .number.precision(.fractionLength(1))) + Text(verbatim: " km") }
                else { Text(verbatim: "—") }
            }
            LabeledContent("roam.experience.duration", value: record.durationText ?? "—")
            LabeledContent("roam.experience.shops", value: record.shops.map { String($0) } ?? "—")
            LabeledContent("roam.experience.explorePct", value: record.explorePct.map { "\($0)%" } ?? "—")
        }.font(.subheadline).monospacedDigit()
    }
}

/// Replays only the stored sketch. This view has no location, network or write capability.
@MainActor struct RoamSavedRouteReplayView: View {
    let reader: any RoamExperienceReading
    let record: RoamHistoryRecord
    @Environment(\.scenePhase) private var scenePhase
    @QuestifyReduceMotion private var reduceMotion
    @State private var replay = RoamRouteReplayState()
    @State private var visible = false
    @State private var request: Request?
    private struct Request {
        let id = UUID()
        let context: RoamRouteReplayState.Context
        let counts: [Int]
    }
    private var owner: RoamRouteReplayState.Owner { .init(reader: reader, record: record) }
    var body: some View {
        let current = owner
        let context = replay.context(for: current)
        VStack(alignment: .leading, spacing: 12) {
            // Always normalize the complete record; revealing a prefix never rescales it.
            RoamRouteSketchView(record: record, visibleSegments: context == nil ? nil : replay.visibleSegments)
            if let context {
                if replay.phase == .playing {
                    Button("roamRouteReplay.skip", systemImage: "forward.end") {
                        synchronize()
                        guard replay.accepts(context, current: owner) else { return }
                        replay.skip(in: context, current: owner); request = nil
                    }.frame(minHeight: 44).accessibilityIdentifier("roamRouteReplay.skip")
                } else {
                    Button(LocalizedStringKey(replay.phase == .completed ? "roamRouteReplay.again" : "roamRouteReplay.start"), systemImage: "play") {
                        synchronize()
                        guard replay.accepts(context, current: owner) else { return }
                        if let ticket = replay.start(in: context, current: owner) {
                            request = Request(context: ticket, counts: replay.plan.counts)
                        }
                    }.frame(minHeight: 44).accessibilityIdentifier("roamRouteReplay.start")
                }
                ProgressView(value: replay.progress, total: 1)
                    .accessibilityLabel(Text("roamRouteReplay.progress"))
                    .accessibilityValue(Text(replay.progress, format: .percent.precision(.fractionLength(0))))
                    .accessibilityIdentifier("roamRouteReplay.progress")
                Text(LocalizedStringKey(replay.phase == .playing ? "roamRouteReplay.playing" : (replay.phase == .completed ? "roamRouteReplay.completed" : "roamRouteReplay.ready")))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { visible = true; synchronize() }
        .onDisappear { visible = false; synchronize() }
        .onChange(of: owner) { _, _ in synchronize() }
        .onChange(of: scenePhase) { _, _ in synchronize() }
        .onChange(of: reduceMotion) { _, _ in synchronize() }
        .task(id: request?.id) {
            guard let captured = request else { return }
            for (index, count) in captured.counts.enumerated() {
                if index > 0 {
                    do { try await Task.sleep(nanoseconds: RoamRouteReplayPlan.intervalNanoseconds) }
                    catch { return }
                }
                if reduceMotion { synchronize(); return }
                guard !Task.isCancelled, visible, scenePhase == .active,
                      replay.accepts(captured.context, current: owner) else { return }
                replay.advance(to: count, in: captured.context, current: owner)
            }
            // No old-task cleanup can clear a later request.
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roamRouteReplay.saved")
    }
    private func synchronize() {
        replay.update(owner: owner, active: visible && scenePhase == .active, reduceMotion: reduceMotion)
        if let captured = request, !replay.accepts(captured.context, current: owner) { request = nil }
    }
}
