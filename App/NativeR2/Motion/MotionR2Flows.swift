import SwiftUI
import Observation

// R5 tab symbol bounce, R7 resizing permission sheet, R9 confirm → top pill, R10 first-run checklist,
// R16 quick capture menu.

// MARK: - R5 Animated tab icons

/// R5: a root tab label whose symbol bounces when the tab becomes selected. Only used when
/// `NativeR2Flags.motion2TabBounce` is on (see the flag note); Reduce Motion: the plain label.
struct MotionR2TabLabel: View {
    let titleKey: String
    let systemImage: String
    let selected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label {
            Text(LocalizedStringKey(titleKey))
        } icon: {
            if MotionR2.live(reduceMotion: reduceMotion) {
                Image(systemName: systemImage).symbolEffect(.bounce, value: selected)
            } else {
                Image(systemName: systemImage)
            }
        }
    }
}

// MARK: - R7 Resizing permission sheet

/// R7: one sheet that resizes between steps: a short welcome card (small detent) grows into the full primer for the
/// permission (large detent), with the content cross-fading. Used by `CYPermissionPrimerWindow` when motion r2 is on;
/// the copy, buttons and identifiers are the existing `CYPermissionPrimer`'s. Reduce Motion: the detent changes
/// without animation and the content swaps with a fade. VoiceOver: each step announces its title.
struct MotionR2PermissionSheetHost: View {
    let kind: CYPermissionPromptKind
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    @State private var presented = true

    var body: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .sheet(isPresented: $presented) {
                MotionR2PermissionSteps(kind: kind, onPrimary: onPrimary, onSecondary: onSecondary)
            }
    }
}

private struct MotionR2PermissionSteps: View {
    let kind: CYPermissionPromptKind
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    private enum Step { case welcome, detail }
    @State private var step: Step = .welcome
    @State private var detent: PresentationDetent = .height(260)
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var content: CYPermissionPrimerContent { .content(for: kind, denied: false, locale: locale) }

    var body: some View {
        Group {
            switch step {
            case .welcome: welcome.transition(.opacity)
            case .detail:
                ScrollView {
                    CYPermissionPrimer(kind: kind, locale: locale, onPrimary: onPrimary, onSecondary: onSecondary)
                        .padding()
                }
                .transition(.opacity)
            }
        }
        .presentationDetents([.height(260), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        .onAppear { MotionR2.announce(verbatim: content.title) }
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Image(systemName: content.glyph)
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(verbatim: content.title).font(.title3.bold()).multilineTextAlignment(.center)
            Button {
                advance()
            } label: {
                Text("motion2.permission.why").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("motion2.permission.next")
            Button(action: onSecondary) { Text(verbatim: content.secondaryTitle) }
                .accessibilityIdentifier("motion2.permission.later")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .accessibilityIdentifier("motion2.permission.welcome")
    }

    private func advance() {
        let animation: Animation? = reduceMotion ? nil : MotionR2.spring
        withAnimation(animation) {
            step = .detail
            detent = .large
        }
        MotionR2.announce(verbatim: content.body)
    }
}

// MARK: - R9 Confirm → top pill

/// R9: a confirmation card ("付款成功") that, after a beat, collapses into a small pill at the top of the sheet
/// (`matchedGeometryEffect`), then hands the message to the in-app island as a `.status` success when the sheet
/// closes. Reduce Motion: the card fades to the pill. VoiceOver: announces the title once.
struct MotionR2ConfirmPill: View {
    let titleKey: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = .green
    @Namespace private var namespace
    @State private var collapsed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if collapsed {
                pill
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .sensoryFeedback(.success, trigger: collapsed) { old, new in !old && new }
        .accessibilityIdentifier("motion2.confirmPill")
        .task { await run() }
        .onDisappear { handOffToIsland() }
    }

    private var card: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle).imageScale(.large)
                .foregroundStyle(tint)
                .matchedGeometryEffect(id: "symbol", in: namespace)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(titleKey))
                .font(.title2.bold())
                .matchedGeometryEffect(id: "title", in: namespace)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
        .matchedGeometryEffect(id: "frame", in: namespace)
        .accessibilityElement(children: .combine)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .matchedGeometryEffect(id: "symbol", in: namespace)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(titleKey))
                .font(.subheadline.weight(.semibold))
                .matchedGeometryEffect(id: "title", in: namespace)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .matchedGeometryEffect(id: "frame", in: namespace)
        .accessibilityElement(children: .combine)
    }

    private func run() async {
        MotionR2.announce(String.LocalizationValue(stringLiteral: titleKey))
        guard NativeR2Flags.motion2 else { return }
        try? await Task.sleep(for: .milliseconds(900))
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.25) : MotionR2.spring
        withAnimation(animation) { collapsed = true }
    }

    private func handOffToIsland() {
        guard NativeR2Flags.motion2, IslandCenter.isEnabled else { return }
        IslandCenter.shared.status(.key(titleKey), tone: .success)
    }
}

// MARK: - R10 First-run checklist

/// The four first-run steps. Marked locally (this device) at the existing success moments; never a request.
enum MotionR2ChecklistStep: String, CaseIterable, Identifiable {
    case storyChapter, punch, stamp, club
    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey(key) }
    /// Catalog key of the step title (used where an already-localized String is needed).
    var key: String {
        switch self {
        case .storyChapter: return "motion2.checklist.story"
        case .punch: return "motion2.checklist.punch"
        case .stamp: return "motion2.checklist.stamp"
        case .club: return "motion2.checklist.club"
        }
    }
    var systemImage: String {
        switch self {
        case .storyChapter: return "book.pages"
        case .punch: return "mappin.and.ellipse"
        case .stamp: return "seal"
        case .club: return "person.3"
        }
    }
}

/// Local store of finished first-run steps (`UserDefaults`), observed by the checklist section.
@MainActor @Observable final class MotionR2Checklist {
    static let shared = MotionR2Checklist()
    private static let storageKey = "motion2.checklist.done"
    private(set) var done: Set<String>
    private(set) var dismissed: Bool

    private init() {
        done = Set(UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? [])
        dismissed = UserDefaults.standard.bool(forKey: Self.storageKey + ".dismissed")
    }

    var completed: Int { MotionR2ChecklistStep.allCases.filter { done.contains($0.rawValue) }.count }
    var total: Int { MotionR2ChecklistStep.allCases.count }

    func isDone(_ step: MotionR2ChecklistStep) -> Bool { done.contains(step.rawValue) }

    /// Called at the success moment of a step. Idempotent.
    func mark(_ step: MotionR2ChecklistStep) {
        guard !done.contains(step.rawValue) else { return }
        done.insert(step.rawValue)
        UserDefaults.standard.set(Array(done), forKey: Self.storageKey)
    }

    func dismiss() {
        dismissed = true
        UserDefaults.standard.set(true, forKey: Self.storageKey + ".dismissed")
    }
}

/// R10: "新手清单" section, now a `CYStepChecklist` (ring + "n of 4", current step with Start → its tab, finished
/// steps folded under 已完成 (n)). Hidden when the flag is off, every step is done, or the player hid it.
struct MotionR2ChecklistSection: View {
    @State private var checklist = MotionR2Checklist.shared
    @Environment(\.rootTabSwitch) private var switchTab

    private var open: [MotionR2ChecklistStep] { MotionR2ChecklistStep.allCases.filter { !checklist.isDone($0) } }

    @Environment(\.locale) private var locale

    /// Design pass me (P4, R-steps): the first open step is the current one with the one Start; finished steps fold
    /// into 已完成 (n) instead of disappearing, so the player can see what they already did.
    private var steps: [CYChecklistStep] {
        let current = open.first
        return MotionR2ChecklistStep.allCases.map { step in
            let state: CYChecklistStep.State = checklist.isDone(step) ? .done : (step == current ? .current : .todo)
            return CYChecklistStep(id: step.rawValue, title: appLocalized(String.LocalizationValue(step.key), locale: locale),
                                   state: state, thumbnailSymbol: step.systemImage, startable: switchTab.isAvailable)
        }
    }

    var body: some View {
        if NativeR2Flags.motion2, !checklist.dismissed, !open.isEmpty {
            Section {
                CYStepChecklist("motion2.checklist.title", systemImage: "sparkles", steps: steps,
                                onStart: { id in
                                    if let step = MotionR2ChecklistStep(rawValue: id) { switchTab(step.tab) }
                                })
                                .accessibilityIdentifier("motion2.checklist.steps")
            } header: {
                Text("motion2.checklist.subtitle")
            } footer: {
                Button("motion2.checklist.hide") { checklist.dismiss() }
                    .font(.footnote)
                    .accessibilityIdentifier("motion2.checklist.hide")
            }
            .accessibilityIdentifier("motion2.checklist")
        }
    }
}

extension MotionR2ChecklistStep {
    /// Where each first-run step is done (MP tab bar: 首页 · 漫游 · 发布 · 俱乐部 · 我的).
    var tab: RootTab {
        switch self {
        case .storyChapter: return .home
        case .punch, .stamp: return .roam
        case .club: return .club
        }
    }
}

// MARK: - R16 Quick capture menu

/// One action of the capture menu.
struct MotionR2CaptureAction: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let systemImage: String
    let perform: () -> Void
}

/// R16: a bottom bar button (记录) that expands into a panel of capture actions (camera / scan / album / note — the
/// ones the host can actually do). `.move(edge: .bottom)` + opacity; Reduce Motion: opacity only. VoiceOver: the
/// bar is a button with expanded/collapsed value; each action is a plain button.
struct MotionR2CaptureMenu: View {
    let actions: [MotionR2CaptureAction]
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if expanded {
                panel.transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            toggle
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : MotionR2.spring, value: expanded)
        .sensoryFeedback(.selection, trigger: expanded)
        .accessibilityIdentifier("motion2.capture")
    }

    private var toggle: some View {
        Button {
            expanded.toggle()
        } label: {
            Label("motion2.capture.title", systemImage: expanded ? "xmark" : "plus")
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityValue(expanded ? Text("motion2.capture.expanded") : Text("motion2.capture.collapsed"))
        .accessibilityIdentifier("motion2.capture.toggle")
    }

    private var panel: some View {
        HStack(spacing: 12) {
            ForEach(actions) { action in
                Button {
                    expanded = false
                    action.perform()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: action.systemImage).font(.title2)
                        Text(action.titleKey).font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("motion2.capture." + action.id)
            }
        }
    }
}

#Preview("Motion r2 flows") {
    List {
        MotionR2ChecklistSection()
        Section {
            MotionR2ConfirmPill(titleKey: "motion2.pay.done")
            MotionR2CaptureMenu(actions: [
                MotionR2CaptureAction(id: "camera", titleKey: "motion2.capture.camera", systemImage: "camera", perform: {}),
                MotionR2CaptureAction(id: "scan", titleKey: "motion2.capture.scan", systemImage: "qrcode.viewfinder", perform: {}),
            ])
        }
    }
}
