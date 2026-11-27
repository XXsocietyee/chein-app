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
                .cyText(.caption).foregroundStyle(CYColor.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .cyNightGlass(in: Capsule())
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
            Label(key, systemImage: "exclamationmark.circle").cyText(.body).foregroundStyle(CYColor.textSecondary)
            if canRetry, let retry {
                CYPillButton("action.retry", style: .secondary, fullWidth: false, action: retry)
                    .accessibilityIdentifier("roam.experience.retry")
            }
        }.accessibilityElement(children: .contain)
            .background { RoamHostedAccessibilityGroup(items: items) }
            .accessibilityIdentifier("roam.experience.error")
    }
}
/// Ink-paper card for the player's own record (history, summary): ink1 over an indigo falloff with a 1 pt night edge.
/// Content surface, so it is not glass (spec 2.2); the pressed state comes from the enclosing button style.
struct RoamNightCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
            .background {
                shape.fill(CYNight.ink1)
                    .overlay(shape.fill(LinearGradient(colors: [CYNight.indigo.opacity(0.55), .clear], startPoint: .top, endPoint: .center)))
            }
            .overlay { shape.strokeBorder(LinearGradient(colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1) }
            .clipShape(shape)
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        let sketch = RoamRouteSketch(track: record.track, places: record.pois.map(\.point))
        let glow = !reduceTransparency && CYLightBudget.shadersAllowed
        let shape = RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
        ZStack {
            // Night map ground: indigo falloff, so the lantern route is the only light in the frame.
            shape.fill(LinearGradient(colors: [CYNight.indigo, CYNight.ink1], startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(CYNight.glassEdgeBottom, lineWidth: 1)
            if sketch.track.isEmpty {
                Label("roam.experience.noTrack", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.caption).foregroundStyle(CYColor.textSecondary).padding()
            } else {
                Canvas { context, size in
                    var path = Path()
                    let segmentCount = max(0, sketch.track.count - 1)
                    let pointCount = visibleSegments.map { min(segmentCount, max(0, $0)) + 1 } ?? sketch.track.count
                    var last: CGPoint?
                    for (index, point) in sketch.track.prefix(pointCount).enumerated() {
                        let position = CGPoint(x: point.x * size.width, y: point.y * size.height)
                        if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
                        last = position
                    }
                    let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    if glow {
                        context.drawLayer { layer in
                            layer.addFilter(.blur(radius: 8))
                            layer.stroke(path, with: .color(CYNight.lantern.opacity(0.55)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        }
                    }
                    context.stroke(path, with: .color(CYNight.lantern), style: style)
                    for point in sketch.places {
                        let rect = CGRect(x: point.x * size.width - 4, y: point.y * size.height - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: rect), with: .color(CYNight.lanternHot))
                        context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(CYNight.lantern.opacity(0.5)), lineWidth: 1)
                    }
                    if let last {
                        context.fill(Path(ellipseIn: CGRect(x: last.x - 5, y: last.y - 5, width: 10, height: 10)), with: .color(.white))
                    }
                }.padding(14).accessibilityHidden(true)
            }
        }.frame(height: 180)
            .clipShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(sketch.track.isEmpty ? "roam.experience.noTrack" : "roam.experience.routeSketch"))
    }
}
struct RoamRecordedStats: View {
    @Environment(\.locale) private var locale
    let record: RoamHistoryRecord
    var body: some View {
        // Mini-program kv: 总距离 / 时长 / 探店 / 探索度 rows with hairlines; a missing value shows —.
        VStack(spacing: 0) {
            row("roam.experience.distance") {
                if let distance = record.distance { Text(LocaleDisplay.roadNumber(kilometers: distance, locale: locale), format: .number.precision(.fractionLength(1))) + Text(verbatim: " ") + Text(LocalizedStringKey(LocaleDisplay.usesMiles(locale) ? "unit.mile.abbr" : "roam.history.km")) }
                else { Text(verbatim: "—") }
            }
            row("roam.experience.duration") { Text(verbatim: record.durationText ?? "—") }
            row("roam.experience.shops") {
                if let shops = record.shops { Text("roamSub.w208.session.shopsValue \(shops)") } else { Text(verbatim: "—") }
            }
            row("roam.experience.explorePct") { Text(verbatim: record.explorePct.map { "\($0)%" } ?? "—") }
        }.monospacedDigit()
    }
    private func row(_ label: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).cyText(.body).foregroundStyle(CYColor.textSecondary)
                Spacer(minLength: CYSpacing.md)
                value().cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            }
            .frame(minHeight: 52)
            .accessibilityElement(children: .combine)
            Divider().overlay(CYColor.borderSubtle)
        }
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
