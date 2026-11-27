import SwiftUI

/// Explicit injection only; no production route/factory is installed. identityVersion must track revocation too.
@MainActor struct CityParticipationFormView: View {
    @Bindable var model: CityParticipationFormModel
    let identityVersion: UInt64
    @Environment(\.scenePhase) private var scenePhase
    @State private var inviteCode = ""
    var body: some View {
        CityParticipationContent(display: display, inviteCode: $inviteCode,
            inviteChanged: { model.invitationInputChanged() }, readInvite: { Task { await model.inspectInvite(inviteCode) } },
            prepare: { model.prepare($0) }, confirm: { Task { await model.submitPrepared() } }, cancel: { model.cancelReview() },
            recheck: { Task { await model.recovery.recheck() } }, reload: { Task { await model.open() } })
        .navigationTitle("城市队伍参与")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("city.participation.form")
        .task { if scenePhase == .active { await model.open() } }
        .onChange(of: identityVersion) { _, _ in inviteCode = ""; model.close() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.open() } } else { inviteCode = ""; model.close() }
        }
        .onDisappear { inviteCode = ""; model.close() }
    }
    private var display: CityParticipationDisplay {
        var recovery = CityParticipationDisplay.Recovery.none
        switch model.recovery.display {
        case .unknown: recovery = .unknown
        case .complete(let status): recovery = status == 200 ? .done : .rejected
        case .storageBlocked: recovery = .blocked
        case .unavailable: recovery = .unavailable
        case .empty, .hidden: break
        }
        return CityParticipationDisplay(
            unavailable: model.unavailable, title: model.state?.binding.title, hasState: model.state != nil,
            team: model.state?.team.map { ($0.memberCount, $0.present, $0.confirmed) },
            writeOpen: (model.state?.writeApproved ?? false) && model.hasApprovalHost,
            kinds: model.availableKinds, busy: model.busy, canPrepare: model.hasApprovalHost, invitationMembers: model.invitation?.memberCount,
            prepared: model.prepared?.kind, recovery: recovery, recoveryBusy: model.recovery.busy)
    }
}

struct CityParticipationDisplay {
    enum Recovery { case none, unknown, done, rejected, blocked, unavailable }
    var unavailable = false
    var title: String?
    var hasState = false
    var team: (members: Int, present: Bool, confirmed: Bool)?
    var writeOpen = false
    var kinds: [CityParticipationCommand.Kind] = []
    var busy = false
    var canPrepare = false
    var invitationMembers: Int?
    var prepared: CityParticipationCommand.Kind?
    var recovery: Recovery = .none
    var recoveryBusy = false
    static func label(_ kind: CityParticipationCommand.Kind) -> String {
        switch kind { case .create: appLocalized("创建队伍", locale: .current); case .join: appLocalized("加入邀请队伍", locale: .current)
            case .lock: appLocalized("锁定队伍", locale: .current); case .confirm: appLocalized("确认参与", locale: .current)
            case .exit: appLocalized("退出当前队伍", locale: .current); case .resume: appLocalized("恢复原队伍", locale: .current) }
    }
}

/// Three steps in one flow: read the team, pick one action, confirm it. One primary action per step.
struct CityParticipationContent: View {
    let display: CityParticipationDisplay
    @Binding var inviteCode: String
    let inviteChanged: () -> Void
    let readInvite: () -> Void
    let prepare: (CityParticipationCommand.Kind) -> Void
    let confirm: () -> Void
    let cancel: () -> Void
    let recheck: () -> Void
    let reload: () -> Void
    @Environment(\.locale) private var locale
    private var step: Int { display.prepared != nil ? 2 : display.hasState ? 1 : 0 }
    var body: some View {
        CYCardPage {
            CYArtCoverHeader(title: Text("城市队伍参与"), symbol: "person.3.fill", seed: "participation") {
                if let title = display.title { Text(verbatim: title).cyText(.meta).foregroundStyle(.white.opacity(0.85)) }
            }
        } content: {
            CYStepIndicator(titles: [ChannelCopy.text("读取队伍", "Read team", locale: locale), ChannelCopy.text("选择操作", "Choose action", locale: locale),
                                     ChannelCopy.text("确认提交", "Confirm", locale: locale)], current: step)
                .padding(.horizontal, CYSpacing.xs)
            if display.unavailable { CYNoteBanner(text: Text("参与信息暂不可用，请保留原请求记录。"), symbol: "exclamationmark.triangle") }
            if display.busy { ProgressView().accessibilityLabel("正在读取或确认参与请求").frame(maxWidth: .infinity) }
            if display.hasState {
                CYInfoCard(title: Text("你的队伍"), symbol: "person.3.sequence.fill") {
                    if let team = display.team {
                        HStack(spacing: CYSpacing.sm) {
                            CYStatusChip(verbatim: "\(team.members) " + ChannelCopy.text("人", "members", locale: locale), systemImage: "person.2.fill")
                            CYStatusChip(verbatim: team.present ? "当前在队" : "已退出", tone: team.present ? .success : .neutral)
                            CYStatusChip(verbatim: team.confirmed ? "已确认" : "未确认", tone: team.confirmed ? .success : .warning)
                        }
                        if !team.present { Text("已退出，可恢复原队伍").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    } else { Text("尚未加入本轮队伍。").cyText(.body).foregroundStyle(CYColor.textPrimary) }
                    if !display.writeOpen { Text("参与提交尚未开放。").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                }
            }
            if let prepared = display.prepared {
                CYInfoCard(title: Text("确认操作：\(CityParticipationDisplay.label(prepared))"), symbol: "checkmark.shield.fill") {
                    Text("使用刚读取的原队伍与版本；结果不明时只查询原请求。").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    CYPillButton("确认提交", action: confirm).disabled(!display.canPrepare || display.busy)
                        .accessibilityIdentifier("city.participation.confirmOriginal")
                    CYPillButton("取消", style: .tertiary, action: cancel).disabled(display.busy)
                }
            } else {
                if display.kinds.contains(.join) {
                    CYInfoCard(title: Text("邀请码"), symbol: "ticket.fill") {
                        TextField("邀请码", text: $inviteCode).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(CYSpacing.md).frame(minHeight: 48).background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                            .disabled(display.busy).onChange(of: inviteCode) { _, _ in inviteChanged() }
                            .accessibilityIdentifier("city.participation.inviteCode")
                        if let count = display.invitationMembers { Text("邀请队伍人数：\(count)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        CYPillButton("读取邀请", style: .secondary, action: readInvite).disabled(display.busy)
                    }
                }
                ForEach(display.kinds, id: \.rawValue) { kind in
                    let primary = kind == display.kinds.first
                    CYPillButton(verbatim: CityParticipationDisplay.label(kind), style: primary ? .primary : .tertiary, action: { prepare(kind) })
                        .disabled(!display.canPrepare || display.busy || kind == .join && display.invitationMembers == nil)
                        .accessibilityIdentifier("city.participation.prepare.\(kind.rawValue)")
                }
            }
            if display.recovery != .none {
                CYInfoCard(title: Text("原请求结果"), symbol: "clock.arrow.circlepath") {
                    switch display.recovery {
                    case .unknown:
                        Text("结果尚未确认，不会重复提交。").cyText(.bodyCompact)
                        CYPillButton("查询原结果", style: .secondary, action: recheck).disabled(display.recoveryBusy || display.busy)
                    case .done: Text("原请求已完成，请重新读取参与信息。").cyText(.bodyCompact)
                    case .rejected: Text("原请求未获接受，请重新读取参与信息。").cyText(.bodyCompact)
                    case .blocked: Text("无法核实原记录，不会发起新请求。").cyText(.bodyCompact)
                    case .unavailable: Text("原请求读取暂不可用。").cyText(.bodyCompact)
                    case .none: EmptyView()
                    }
                }
            }
            CYPillButton("重新读取参与信息", style: .tertiary, systemImage: "arrow.clockwise", action: reload).disabled(display.busy)
        }
    }
}
