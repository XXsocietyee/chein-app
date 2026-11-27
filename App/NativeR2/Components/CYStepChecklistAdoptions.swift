import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Components r1 R-steps: `CYStepChecklist` where the app walks the player through steps. Each host adds one line; the step
// state comes from the model the host already has, and the copy follows the MP page named on each type.

/// Publish activity wizard (MP `pages/publish/activity`: 基本信息 / 活动内容 / 票务与合作, `buildProgress` done/current/todo).
/// 开始 on a step jumps there, like tapping a step dot.
@MainActor struct ActivityPublishStepChecklist: View {
    let step: Int
    let draft: ActivityPublishDraft
    let onSelect: (Int) -> Void
    @Environment(\.locale) private var locale
    private var steps: [CYChecklistStep] {
        ActivityPublishingWizard.progress(step).map { mark in
            CYChecklistStep(id: String(mark.index), title: title(mark.key),
                            state: mark.state == "done" ? .done : mark.state == "current" ? .current : .todo,
                            detail: mark.state == "done" ? summary(mark.key) : nil,
                            thumbnailSymbol: mark.key == "content" ? "photo" : "ticket")
        }
    }
    var body: some View {
        CYStepChecklist("publishModes.wizard.checklist", systemImage: "square.and.pencil", steps: steps,
                        onStart: { id in if let index = Int(id) { onSelect(index) } })
            .accessibilityIdentifier("publishModes.wizard.checklist")
    }
    private func title(_ key: String) -> String {
        switch key {
        case "basic": return appLocalized("publishModes.wizard.step.basic", locale: locale)
        case "content": return appLocalized("publishModes.wizard.step.content", locale: locale)
        default: return appLocalized("publishModes.wizard.step.ticket", locale: locale)
        }
    }
    private func summary(_ key: String) -> String? {
        switch key {
        case "basic":
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case "ticket": return draft.tickets.isEmpty ? nil : "\(draft.tickets.count)"
        default: return nil
        }
    }
}

/// Club create intro (MP `pages/club/create`: 类型 / 活动方向 / 资料 / 城市, 开始创建). 开始 on the first step starts the flow.
@MainActor struct ClubCreateStepChecklist: View {
    let locale: Locale
    let onStart: (Int) -> Void
    private var steps: [CYChecklistStep] {
        (1...4).map { index in
            CYChecklistStep(id: String(index), title: ClubPlayerCopy.createTitle(step: index, locale: locale),
                            state: index == 1 ? .current : .todo, startable: index == 1)
        }
    }
    var body: some View {
        CYStepChecklist("club.create.checklist", systemImage: "person.3.sequence.fill", steps: steps,
                        startTitle: "club.create.checklist.start",
                        onStart: { id in if let index = Int(id) { onStart(index) } })
            .accessibilityIdentifier("club.player.create.checklist")
    }
}

/// City-orientation run (MP roadmap `play-roadmap.js`: "X / N 已完成", 下一站 / 已完成 / 前路未知): stops as steps.
/// 继续 opens the stop's punch sheet, like the legs row below.
@MainActor struct CityOrientationStepChecklistSection: View {
    let route: PlayRouteMapPresentation
    let onOpen: (Int) -> Void
    @Environment(\.locale) private var locale
    private var steps: [CYChecklistStep] {
        route.stops.map { stop in
            let state: CYChecklistStep.State
            switch stop.state {
            case .completed: state = .done
            case .current: state = .current
            case .available: state = .todo
            case .locked, .unknown: state = .locked
            }
            return CYChecklistStep(id: String(stop.id), title: "\(stop.order) · " + name(stop), state: state,
                                   detail: stop.state == .completed ? stop.address : nil,
                                   thumbnailSymbol: "checkmark.seal.fill", startable: stop.canOpen)
        }
    }
    var body: some View {
        if !route.stops.isEmpty {
            Section {
                CYStepChecklist("nativeR2.city.checklist", systemImage: "flag.checkered", steps: steps, tint: .orange,
                                startTitle: "nativeR2.city.checklist.continue",
                                onStart: { id in if let stopID = Int(id) { onOpen(stopID) } })
                    .accessibilityIdentifier("nativeR2.city.checklist")
            }
        }
    }
    private func name(_ stop: PlayRouteMapPresentation.Stop) -> String {
        if stop.state == .locked { return appLocalized("playRoute.lockedStop", locale: locale) }
        if let name = stop.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return appLocalized("playRoute.unnamedStop", locale: locale)
    }
}

/// First roam (MP `pages/roam` 怎么玩 sheet): the four rules as steps, read one by one with 知道了. Local view state only —
/// reading the guide grants no consent and starts nothing (see `RoamPreflightRulesView`).
@MainActor struct RoamFirstRoamChecklist: View {
    @State private var read: Set<RoamPreflightRule> = []
    @Environment(\.locale) private var locale
    private var steps: [CYChecklistStep] {
        let current = RoamPreflightRule.allCases.first { !read.contains($0) }
        return RoamPreflightRule.allCases.map { rule in
            CYChecklistStep(id: rule.id, title: appLocalized(String.LocalizationValue(rule.titleKey), locale: locale),
                            state: read.contains(rule) ? .done : rule == current ? .current : .todo,
                            thumbnailSymbol: symbol(rule), startable: rule == current)
        }
    }
    var body: some View {
        Section {
            CYStepChecklist("roam.firstRoam.checklist", systemImage: "figure.walk", steps: steps, tint: .green,
                            startTitle: "roam.firstRoam.gotIt",
                            onStart: { id in if let rule = RoamPreflightRule(rawValue: id) { read.insert(rule) } },
                            onReset: { read = [] }) {
                CYStepChecklistResultCard(title: "roam.firstRoam.ready", systemImage: "figure.walk.motion", tint: .green)
            }
            .accessibilityIdentifier("roam.preflightRules.checklist")
        }
    }
    private func symbol(_ rule: RoamPreflightRule) -> String {
        switch rule {
        case .explore: return "map"
        case .arrival: return "mappin.and.ellipse"
        case .finish: return "flag.checkered"
        case .privacy: return "location.slash"
        }
    }
}

/// Event check-in (MP order timeline `scene-member-order-detail`: 报名成功 → 等待到店核销 / 权益已核销 → 开始游玩, 已通关).
/// 开始 on the check-in step opens the pass (出示入场码); staff verify, so nothing else is started from here.
@MainActor struct TicketCheckInStepChecklist: View {
    let ticket: TicketWalletTicket
    let canPresent: Bool
    let onPresent: () -> Void
    @Environment(\.locale) private var locale
    private var steps: [CYChecklistStep] {
        let verified = ticket.status == .verified
        var steps = [
            CYChecklistStep(id: "signup", title: appLocalized("ticketWallet.checklist.signup", locale: locale),
                            state: ticket.status == .pending ? .current : .done, startable: false),
            CYChecklistStep(id: "verify", title: appLocalized("ticketWallet.checklist.verify", locale: locale),
                            state: verified ? .done : ticket.status == .ready ? .current : .todo,
                            detail: verified ? ticket.verificationTime : nil, thumbnailSymbol: "qrcode",
                            startable: canPresent)
        ]
        if ticket.hasGame {
            let cleared = ticket.topicCompletedFlag == true
            steps.append(CYChecklistStep(id: "play", title: appLocalized("ticketWallet.checklist.play", locale: locale),
                                         state: cleared ? .done : verified ? .current : .todo,
                                         detail: cleared ? appLocalized("ticketWallet.checklist.cleared", locale: locale) : nil,
                                         startable: false))
        }
        return steps
    }
    var body: some View {
        let shown: [TicketWalletStatus] = [.pending, .ready, .verified]
        if shown.contains(ticket.status) {
            Section {
                CYStepChecklist("ticketWallet.checklist.title", systemImage: "ticket", steps: steps,
                                startTitle: "ticketWallet.checklist.present",
                                onStart: { id in if id == "verify" { onPresent() } })
                    .accessibilityIdentifier("ticketWallet.checklist.\(ticket.id)")
            }
        }
    }
}
