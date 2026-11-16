import SwiftUI
import UIKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Challenge N34 (204:34263) → 准备掷骰 N36 → 掷骰中 N37 → 拿下 N38 / 没掷够 N39 (204:34340 … 204:34440),
// plus the owner's sheets over 我的地盘 (shield N47, upgrade N48) and the moments they end in.
// The server rolls the d20; the client only throws the art and shows the server's face.

enum CityMomentRoute: Identifiable {
    case claimed(CityPlace, photo: UIImage?, protectionHours: Int, price: Int64)
    case ready(CityPlace, fixes: [RoamDeviceFix], dc: Int?)
    case upgraded(CityPlace, fromLevel: Int)
    case placeLost(CityPlace, compensation: Int64?)
    case defended(CityPlace, hours: Int)

    var id: String {
        switch self {
        case .claimed(let place, _, _, _): return "claimed-" + place.id
        case .ready(let place, _, _): return "ready-" + place.id
        case .upgraded(let place, _): return "upgraded-" + place.id
        case .placeLost(let place, _): return "lost-" + place.id
        case .defended(let place, _): return "defended-" + place.id
        }
    }
}

/// Collects presence fixes (≥ 3 over ≥ 60 s) for upgrade and challenge, which need no photo.
@MainActor final class CityPresenceSampler: ObservableObject {
    @Published private(set) var fixes: [RoamDeviceFix] = []
    @Published private(set) var running = false
    @Published private(set) var tick = 0
    private var task: Task<Void, Never>?

    func start(_ captureFix: (@MainActor () async throws -> RoamDeviceFix)?) {
        guard let captureFix, task == nil else { return }
        running = true
        task = Task { @MainActor in
            for index in 0..<4 {
                if index > 0 { try? await Task.sleep(nanoseconds: 20_000_000_000) }
                guard !Task.isCancelled else { break }
                if let fix = try? await captureFix() { fixes.append(fix); tick += 1 }
            }
            running = false
            task = nil
        }
    }
    func stop() { task?.cancel(); task = nil; running = false }
    func checks(anchor: RoamCoordinate) -> [CityPresenceCheck] {
        CityPresencePreflight.evaluate(fixes: fixes, anchor: anchor, requirePhoto: false, hasPhoto: false)
    }
    func passed(anchor: RoamCoordinate) -> Bool { let c = checks(anchor: anchor); return c.count >= 3 && c.allSatisfy(\.passed) }
}

struct CityPresenceChecklist: View {
    let checks: [CityPresenceCheck]
    let running: Bool
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    var body: some View {
        let copy = CityCopy(locale: locale)
        VStack(spacing: CYSpacing.xs) {
            ForEach(CityPresenceCheck.Kind.allCases.filter { $0 != .photo }, id: \.self) { kind in
                let check = checks.first { $0.kind == kind }
                CityCheckRow(title: title(kind, copy), detail: check?.detail(chinese: copy.chinese) ?? copy("正在定位…", "Locating…"),
                             state: check.map { $0.passed ? .passed : (running && kind == .dwell ? .working : .failed) } ?? (running ? .working : .waiting))
            }
        }
        .padding(CYSpacing.md)
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
    private func title(_ kind: CityPresenceCheck.Kind, _ copy: CityCopy) -> String {
        switch kind {
        case .distance: return copy("距离", "Distance")
        case .accuracy: return copy("定位精度", "Accuracy")
        case .dwell: return copy("现场停留", "Stay on site")
        case .photo: return copy("现场照片", "On-site photo")
        }
    }
}

extension CityPresenceCheck.Kind: CaseIterable {
    public static var allCases: [CityPresenceCheck.Kind] { [.distance, .accuracy, .dwell, .photo] }
}

struct CityChallengeSheet: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let onMoment: (CityMomentRoute) -> Void
    let onClose: () -> Void

    @StateObject private var sampler = CityPresenceSampler()
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var quote: CityTerritoryQuote? { store.pendingQuote?.kind == .challenge ? store.pendingQuote?.quote : nil }
    private var fee: Int64 { quote?.price ?? place.challengeFeePreview ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CitySheetTitle(title: copy("挑战 ", "Challenge ") + copy.title(place),
                               tags: [[copy.tier(place.tier), copy.level(place.level)].compactMap { $0 }.joined(separator: " · ")],
                               districtIndex: place.districtIndex, district: copy.district(place), onClose: close)
                if let dc = quote?.dc {
                    CityOddsBar(needFace: CityOddsBar.needFace(dc: dc, mod: 0))
                        .padding(CYSpacing.md)
                        .background(palette.bgRaised.opacity(0.5), in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                } else {
                    CityBanner(text: copy("难度要侦察后才知道。掷出 20 必赢，掷出 1 必输。", "Difficulty shows after scouting. A natural 20 always wins, a 1 always loses."), symbol: "dice")
                }
                CityPresenceChecklist(checks: sampler.checks(anchor: place.coordinate), running: sampler.running)
                CityFactTable(rows: [
                    .init(label: copy("挑战费", "Challenge fee"), value: String(fee), coin: true),
                    .init(label: copy("今天还可挑战", "Challenges left today"), value: copy("最多 \(CityMonopolyRules.challengesPerDay) 次", "up to \(CityMonopolyRules.challengesPerDay)"))
                ])
                CYPillButton(verbatim: copy("开始挑战 · \(fee) 积分", "Start · \(fee) pts")) {
                    sampler.stop()
                    onMoment(.ready(place, fixes: sampler.fixes, dc: quote?.dc))
                }
                .disabled(quote == nil || !sampler.passed(anchor: place.coordinate))
                .accessibilityIdentifier("city.challenge.start")
                Text(verbatim: copy("没掷够，挑战费的 30% 给守方，其余销毁。", "If you miss, 30% of the fee goes to the holder and the rest is burned."))
                    .font(CYTypography.caption).foregroundStyle(palette.textTertiary).frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                if let issue = store.issueCode {
                    CityBanner(text: CityReasonCopy.text(issue, chinese: copy.chinese), symbol: "exclamationmark.circle", tone: .error)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
        }
        .sensoryFeedback(.selection, trigger: sampler.tick)
        .task {
            let first = try? await captureFix?()
            await store.quote(.challenge, place: place, fix: first)
            sampler.start(captureFix)
        }
        .onDisappear { sampler.stop() }
        .accessibilityIdentifier("city.challenge.sheet")
    }

    private func close() { sampler.stop(); store.cancelQuote(); onClose() }
}

struct CityShieldSheet: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    let onClose: () -> Void
    @State private var until: Date?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        let copy = CityCopy(locale: locale)
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CitySheetTitle(title: copy("给 ", "Shield ") + copy.title(place) + copy(" 开护盾", ""), onClose: onClose)
            if let until {
                CityBanner(text: copy("护盾已开，保护到 ", "Shield on, protected until ") + copy.clock(until), symbol: "shield.fill", tone: .ok)
            } else {
                CityFactTable(rows: [
                    .init(label: copy("护盾", "Shield"), value: copy("保护 +12 小时", "+12 h protection")),
                    .init(label: copy("花费", "Cost"), value: String(CityMonopolyRules.shieldCost), coin: true)
                ])
                Text(verbatim: copy("同一块地 7 天只能开一次，最多叠到 48 小时。", "Once per place every 7 days, up to 48 hours."))
                    .font(CYTypography.meta).foregroundStyle(palette.textSecondary)
            }
            CYPillButton(verbatim: until == nil ? copy("开护盾 · \(CityMonopolyRules.shieldCost) 积分", "Shield · \(CityMonopolyRules.shieldCost) pts") : copy("好", "Done")) {
                if until != nil { onClose() } else { Task { until = await store.shield(place) } }
            }
            .disabled(store.busy)
            if let issue = store.issueCode {
                CityBanner(text: CityReasonCopy.text(issue, chinese: copy.chinese), symbol: "exclamationmark.circle", tone: .error)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
    }
}

struct CityUpgradeSheet: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let onMoment: (CityMomentRoute) -> Void
    let onClose: () -> Void
    @StateObject private var sampler = CityPresenceSampler()
    @Environment(\.locale) private var locale

    var body: some View {
        let copy = CityCopy(locale: locale)
        let quote = store.pendingQuote?.kind == .upgrade ? store.pendingQuote?.quote : nil
        let cost = quote?.price ?? CityMonopolyRules.upgradeCost(tier: place.tier ?? .t1, fromLevel: place.level) ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CitySheetTitle(title: copy("升级 ", "Upgrade ") + copy.title(place), onClose: { sampler.stop(); store.cancelQuote(); onClose() })
                CityFactTable(rows: [
                    .init(label: copy.level(place.level) + " → " + copy.level(place.level + 1),
                          value: copy("租金 ", "Rent ") + CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(place.level + 1))),
                    .init(label: copy("升级费", "Upgrade cost"), value: String(cost), coin: true)
                ])
                Text(verbatim: copy("升级要本人到场：在原地停留 1 分钟。", "Upgrading needs you on site: stay one minute."))
                    .font(CYTypography.meta).foregroundStyle(.secondary)
                CityPresenceChecklist(checks: sampler.checks(anchor: place.coordinate), running: sampler.running)
                CYPillButton(verbatim: store.busy ? copy("校验中", "Checking") : copy("升级 · \(cost) 积分", "Upgrade · \(cost) pts")) {
                    Task {
                        let from = place.level
                        if let result = await store.confirm(fixes: sampler.fixes), result.kind == .applied {
                            onMoment(.upgraded(store.place(id: place.id) ?? place, fromLevel: from))
                        }
                    }
                }
                .disabled(quote == nil || store.busy || !sampler.passed(anchor: place.coordinate))
                if let reasons = store.lastResult?.reasons, store.lastResult?.kind == .rejected, !reasons.isEmpty {
                    CityBanner(text: reasons.map { CityReasonCopy.text($0, chinese: copy.chinese) }.joined(separator: "\n"), symbol: "xmark.octagon", tone: .error)
                } else if let issue = store.issueCode {
                    CityBanner(text: CityReasonCopy.text(issue, chinese: copy.chinese), symbol: "exclamationmark.circle", tone: .error)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
        }
        .task {
            store.clearResult()
            let first = try? await captureFix?()
            await store.quote(.upgrade, place: place, fix: first)
            sampler.start(captureFix)
        }
        .onDisappear { sampler.stop() }
    }
}

// MARK: - Moments

struct CityMomentHost: View {
    let route: CityMomentRoute
    @ObservedObject var store: CityBoardStore
    let onDone: () -> Void
    let onMine: () -> Void

    @Environment(\.locale) private var locale
    var body: some View {
        Group {
            switch route {
            case .claimed(let place, let photo, let hours, let price):
                CityClaimedMoment(place: place, photo: photo, protectionHours: hours, price: price, onMine: onMine, onDone: onDone)
            case .ready(let place, let fixes, let dc):
                CityDiceMoment(place: place, fixes: fixes, dc: dc, store: store, onMine: onMine, onDone: onDone)
            case .upgraded(let place, let from):
                CityUpgradedMoment(place: place, fromLevel: from, onDone: onDone)
            case .placeLost(let place, let compensation):
                CityPlaceLostMoment(place: place, compensation: compensation, onDone: onDone)
            case .defended(let place, let hours):
                CityDefendedMoment(place: place, hours: hours, onDone: onDone)
            }
        }
        .themeDomain(.player)
    }
}

/// 圈下了 N22: photo → deed → seal → text (SR2-49 rows 圈下了 1–4).
struct CityClaimedMoment: View {
    let place: CityPlace
    let photo: UIImage?
    let protectionHours: Int
    let price: Int64
    let onMine: () -> Void
    let onDone: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let copy = CityCopy(locale: locale)
        CityMomentView(
            headline: copy("圈下了", "Claimed"),
            line: copy("\(copy.title(place))现在是你的。每个到访的人都会给你留下 \(place.rentPerVisit ?? 0) 积分。",
                       "\(copy.title(place)) is yours. Every visitor leaves you \(place.rentPerVisit ?? 0) points."),
            chips: [copy("−\(price) 积分", "−\(price) pts"), copy("保护到 ", "Protected to ") + copy.clock(Date().addingTimeInterval(TimeInterval(protectionHours * 3600)))],
            primary: copy("去看看我的地盘", "See my places"), secondary: copy("好", "Done"),
            onPrimary: onMine, onSecondary: onDone
        ) { beat in
            ZStack(alignment: .topTrailing) {
                CityDeedCard(place: place, size: .full, heldDays: 1)
                    .overlay(alignment: .top) {
                        if let photo, beat < .stage {
                            Image(uiImage: photo).resizable().scaledToFill().frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.top, 60).transition(.opacity)
                        }
                    }
                    .offset(y: beat >= .stage || reduceMotion ? 0 : -44)
                    .opacity(beat >= .stage ? 1 : 0)
                CitySeal(text: copy("已圈下", "Claimed"), landed: beat >= .seal).offset(x: 6, y: -10)
            }
            .padding(.horizontal, CYSpacing.lg)
        }
        .cityFeedbackOnAppear(.success)
    }
}

/// 准备掷骰 → 掷骰中 → 拿下 / 没掷够. The throw sends the command; the face is the server's roll.
struct CityDiceMoment: View {
    enum Stage: Equatable { case ready, rolling, result(CityTerritoryCommandResult), failed(String) }
    let place: CityPlace
    let fixes: [RoamDeviceFix]
    let dc: Int?
    @ObservedObject var store: CityBoardStore
    let onMine: () -> Void
    let onDone: () -> Void
    /// Throws at once (design fixtures; the live flow waits for the flick or the tap).
    var autoRoll = false

    @State private var stage: Stage = .ready
    @State private var shownFace: Int?
    @State private var shownTotal: Int?
    @State private var tumbleTick = 0
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var copy: CityCopy { CityCopy(locale: locale) }

    var body: some View {
        Group {
            switch stage {
            case .ready: ready
            case .rolling: rolling
            case .result(let result): outcome(result)
            case .failed(let code): failed(code)
            }
        }
        .animation(reduceMotion ? CityTokens.reducedFade : CityTokens.deedSpring, value: stage)
        .onAppear { if autoRoll { roll() } }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack { Spacer(); CityThrowableDie(enabled: true, onThrow: roll); Spacer() }.padding(.top, CYSpacing.xxxl)
            if let dc {
                CityOddsBar(needFace: CityOddsBar.needFace(dc: dc, mod: 0))
            }
            Text(verbatim: copy("准备掷骰", "Ready to roll")).font(CYTypography.display).foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
            Text(verbatim: copy("把骰子甩出去，或点「掷骰」。", "Flick the die, or tap Roll.")).font(CYTypography.body).foregroundStyle(palette.textSecondary)
            CityInfoChip(text: copy("对手 ", "Holder ") + copy.level(place.level))
            Spacer()
            CYPillButton(verbatim: copy("掷骰", "Roll"), action: roll).accessibilityIdentifier("city.dice.roll")
            CYPillButton(verbatim: copy("再想想", "Not now"), style: .tertiary) { store.cancelQuote(); onDone() }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
        .background(palette.bgPage.ignoresSafeArea())
    }

    private var rolling: some View {
        VStack(spacing: CYSpacing.lg) {
            Spacer()
            CityTumblingDie()
            if let dc { CityInfoChip(text: copy("需要 ≥ \(CityOddsBar.needFace(dc: dc, mod: 0))", "Need ≥ \(CityOddsBar.needFace(dc: dc, mod: 0))")) }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(palette.bgPage.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: tumbleTick)
        .onAppear { AccessibilityNotification.Announcement(copy("正在掷骰", "Rolling")).post() }
    }

    @ViewBuilder private func outcome(_ result: CityTerritoryCommandResult) -> some View {
        let won = result.kind == .challengerWon
        let face = result.roll ?? 0
        let mod = result.modifierTotal
        let total = result.total ?? (face + mod)
        if result.taskFailed {
            failed("TASK_FAILED")
        } else if result.kind == .rejected {
            failed(result.reasons?.first ?? "REJECTED")
        } else {
            CityMomentView(
                headline: "\(total)",
                line: won
                    ? copy("掷出 \(face)，加成 +\(mod)，合计 \(total)。\(copy.title(place))归你了。", "Rolled \(face), +\(mod), total \(total). \(copy.title(place)) is yours.")
                    : copy("掷出 \(face)，加成 +\(mod)，合计 \(total)，没到 \(result.dc ?? dc ?? 0)。", "Rolled \(face), +\(mod), total \(total): short of \(result.dc ?? dc ?? 0)."),
                chips: won
                    ? [copy.level(place.level) + " → " + copy.level(max(0, place.level - 1)), copy("保护 24 小时", "24 h protection")]
                    : [copy("挑战费 30% 给守方", "30% of the fee to the holder"), copy("对这块地冷却 24 小时", "24 h cooldown here")],
                primary: won ? copy("去看看我的地盘", "See my places") : copy("好", "Done"),
                secondary: won ? copy("好", "Done") : nil,
                onPrimary: won ? onMine : onDone, onSecondary: won ? onDone : nil
            ) { beat in
                ZStack(alignment: .bottomTrailing) {
                    if won {
                        let taken = store.place(id: result.property?.propertyId)
                            ?? place.handedOver(to: .mine, level: max(0, place.level - 1), protectedUntil: Date().addingTimeInterval(24 * 3600))
                        CityDeedCard(place: taken, size: .full, heldDays: 1)
                            .opacity(beat >= .seal ? 1 : 0)
                            .offset(y: beat >= .seal || reduceMotion ? 0 : 40)
                    }
                    CityD20Art(face: beat >= .stage ? face : nil, lost: !won, size: won ? 96 : 148)
                        .offset(y: !won && beat >= .seal && !reduceMotion ? 24 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: won ? .bottomTrailing : .center)
                }
                .padding(.horizontal, CYSpacing.lg)
            }
            .cityFeedbackOnAppear(won ? .success : .impact(flexibility: .soft))
        }
    }

    private func failed(_ code: String) -> some View {
        CityMomentView(
            headline: code == "TASK_FAILED" ? copy("任务没过", "Task failed") : copy("这次没能挑战", "Challenge not sent"),
            line: code == "TASK_FAILED" ? copy("挑战结束，挑战费退回一半。", "The challenge ended and half the fee came back.") : CityReasonCopy.text(code, chinese: copy.chinese),
            primary: copy("好", "Done"), onPrimary: { store.cancelQuote(); onDone() }
        ) { _ in CityD20Art(face: nil, lost: true, size: 120) }
    }

    private func roll() {
        guard stage == .ready else { return }
        stage = .rolling
        Task { @MainActor in
            let ticker = Task { @MainActor in
                while !Task.isCancelled { try? await Task.sleep(nanoseconds: 120_000_000); tumbleTick += 1 }
            }
            let started = Date()
            let result = await store.confirm(fixes: fixes)
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 1.2 { try? await Task.sleep(nanoseconds: UInt64((1.2 - elapsed) * 1_000_000_000)) }
            ticker.cancel()
            if let result { stage = .result(result) } else { stage = .failed(store.issueCode ?? "UNAVAILABLE") }
        }
    }
}

struct CityUpgradedMoment: View {
    let place: CityPlace
    let fromLevel: Int
    let onDone: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        let copy = CityCopy(locale: locale)
        CityMomentView(headline: copy("升到 ", "Now ") + copy.level(place.level),
                       line: copy("每次到访的租金从 \(CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(fromLevel))) 提到 \(CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(place.level)))。",
                                  "Rent per visit goes from \(CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(fromLevel))) to \(CityMonopolyFormat.multiplier(CityMonopolyRules.levelMultiplier(place.level)))."),
                       primary: copy("好", "Done"), onPrimary: onDone) { beat in
            CityDeedCard(place: place, size: .full).padding(.horizontal, CYSpacing.lg).opacity(beat >= .stage ? 1 : 0)
        }
        .cityFeedbackOnAppear(.success)
    }
}

/// 被抢 N40: the deed tips to −6° and the holder row changes.
struct CityPlaceLostMoment: View {
    let place: CityPlace
    let compensation: Int64?
    let onDone: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        let copy = CityCopy(locale: locale)
        CityMomentView(headline: copy("\(copy.title(place))被拿走了", "\(copy.title(place)) was taken"),
                       line: compensation.map { copy("补偿 \($0) 积分已到账。24 小时内反击，挑战费减半。", "\($0) points compensation arrived. Strike back within 24 h at half the fee.") }
                            ?? copy("24 小时内反击，挑战费减半。", "Strike back within 24 h at half the fee."),
                       primary: copy("好", "Done"), onPrimary: onDone) { beat in
            CityDeedCard(place: beat >= .seal ? place.handedOver(to: .other, holder: CityCopy(locale: locale)("新主人", "New holder")) : place, size: .full)
                .padding(.horizontal, CYSpacing.lg)
                .rotationEffect(.degrees(beat >= .seal ? -6 : 0)).saturation(beat >= .seal ? 0.2 : 1)
        }
        .cityFeedbackOnAppear(.warning)
    }
}

struct CityDefendedMoment: View {
    let place: CityPlace
    let hours: Int
    let onDone: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        let copy = CityCopy(locale: locale)
        CityMomentView(headline: copy("守住了", "Defended"),
                       line: copy("\(copy.title(place))还是你的，保护 +\(hours) 小时。", "\(copy.title(place)) is still yours: +\(hours) h protection."),
                       chips: [copy("保护 +\(hours) 小时", "+\(hours) h protection")],
                       primary: copy("好", "Done"), onPrimary: onDone) { beat in
            ZStack(alignment: .topTrailing) {
                CityDeedCard(place: place, size: .full).padding(.horizontal, CYSpacing.lg)
                CitySeal(text: copy("守住", "Held"), landed: beat >= .seal).offset(x: -6, y: -10)
            }
        }
        .cityFeedbackOnAppear(.success)
    }
}
