import Foundation

/// Presentation projections for reform plan v9 §24 / W16 (decisions U02–U07):
/// - `TeamFirstMeeting`: confirmed-team eligibility without interest matching, real-name verification
///   scoped exclusively to `.strangerTeamMeeting`, rotating QR handshake with NFC permanently off,
///   and zero location point fields (MV38).
/// - `FriendMultiInvite` & `RevokeWinsLedger`: review invalidation on selection change, partial-failure
///   retry restricted to failed/unsent recipients with stable request IDs, and terminal revocation precedence.
/// - `BeijingDeadline`: dual-zone display (device zone + governing Asia/Shanghai time when offsets differ)
///   and server-offset-driven advisory hints that never block submission.
public enum TeamMeetingHandshakePresentation {

    // MARK: - U05–U07: Team First Meeting Eligibility & Handshake Presentation

    public enum EligibilityVerdict: Equatable, Sendable {
        case eligible(TeamMeetingEligibility)
        case teamNotConfirmed
        case invalidBinding
    }

    public struct MeetingCard: Equatable, Sendable {
        public let teamId: String
        public let meetingId: String
        public let phase: TeamFirstMeeting.Phase
        public let phaseTitle: String
        public let phaseSubtitle: String
        public let noInterestMatching: Bool
        public let realNameScopedOnlyToStrangerMeeting: Bool
        public let availableHandshakes: [TeamMeetingHandshake]
        public let qrAlwaysOffered: Bool
        public let nfcOffered: Bool
        public let requiresRealNameCheck: Bool
        public let canBeginHandshake: Bool
        public let canScanPeerCode: Bool
        public let awaitingServerDecision: Bool
        public let isTerminal: Bool
        public let activeChallengePayload: String?
        public let isChallengeExpired: Bool
    }

    /// Evaluates whether server team facts open the stranger team-meeting step (U05).
    public static func evaluateEligibility(
        teamId: String,
        meetingId: String,
        selfMemberId: String,
        peerMemberId: String,
        formation: String,
        teamStatus: TeamStatus
    ) -> EligibilityVerdict {
        do {
            let eligibility = try TeamMeetingEligibility(
                teamId: teamId,
                meetingId: meetingId,
                selfMemberId: selfMemberId,
                peerMemberId: peerMemberId,
                formation: formation,
                teamStatus: teamStatus
            )
            return .eligible(eligibility)
        } catch let issue as TeamMeetingIssue {
            return issue == .teamNotConfirmed ? .teamNotConfirmed : .invalidBinding
        } catch {
            return .invalidBinding
        }
    }

    /// Verifies U06: only `.strangerTeamMeeting` requires real-name verification; every other flow is false.
    public static func isRealNameStrictlyScoped() -> Bool {
        let nonMeetingFlows: [RealNameScope.Flow] = [
            .ordinaryPlay,
            .friendInvite,
            .mapRead,
            .teamJoin,
            .publish
        ]
        return RealNameScope.requiresRealName(.strangerTeamMeeting)
            && nonMeetingFlows.allSatisfy { !RealNameScope.requiresRealName($0) }
    }

    /// Formats the opaque rotating QR payload for local rendering when issued by `selfMemberId` for this meeting.
    public static func challengePayload(
        for challenge: TeamMeetingChallenge?,
        eligibility: TeamMeetingEligibility,
        deviceNow: Date,
        serverOffset: TimeInterval
    ) -> (payload: String?, isExpired: Bool) {
        guard let challenge,
              challenge.meetingId == eligibility.meetingId,
              challenge.teamId == eligibility.teamId,
              challenge.issuerMemberId == eligibility.selfMemberId,
              challenge.receiverMemberId == eligibility.peerMemberId else {
            return (nil, true)
        }
        let estimatedNow = deviceNow.addingTimeInterval(serverOffset)
        guard estimatedNow < challenge.expiresAt else {
            return (nil, true)
        }
        let joined = [
            challenge.meetingId,
            challenge.issuerMemberId,
            challenge.nonce,
            challenge.keyVersion,
            challenge.signature
        ].joined(separator: ".")
        return (joined, false)
    }

    /// Builds the meeting presentation card for `TeamFirstMeeting` (U05–U07).
    public static func presentMeeting(
        _ meeting: TeamFirstMeeting,
        myChallenge: TeamMeetingChallenge? = nil,
        capabilities: ReformWorldCapabilities = .disabled,
        deviceReportsNFC: Bool = false,
        deviceNow: Date = Date(),
        serverOffset: TimeInterval = 0
    ) -> MeetingCard {
        let handshakes = TeamMeetingHandshake.available(
            capabilities: capabilities,
            deviceReportsNFC: deviceReportsNFC
        )
        let codeState = challengePayload(
            for: myChallenge,
            eligibility: meeting.eligibility,
            deviceNow: deviceNow,
            serverOffset: serverOffset
        )
        let title: String
        let subtitle: String
        switch meeting.phase {
        case .realNameRequired:
            title = W8Text.t("需完成实名核验", "Real-name verification required")
            subtitle = W8Text.t("仅陌生人组队见面步需要实名核验，普通游玩与好友邀请无需实名", "Only the stranger-team meet-up step needs real-name verification; regular play and friend invites don’t")
        case .readyToMeet:
            title = W8Text.t("队伍已确认，准备当面核验", "Team confirmed. Get ready to verify in person")
            subtitle = W8Text.t("仅对已确认成团的队友开放，无兴趣匹配，出示动态二维码完成核验", "Open only to confirmed teammates, with no interest matching. Show the dynamic QR code to verify")
        case .handshaking:
            title = W8Text.t("出示或扫描动态二维码", "Show or scan the dynamic QR code")
            subtitle = codeState.isExpired ? W8Text.t("当前二维码已过期，请刷新动态码", "This QR code has expired. Refresh the dynamic code") : W8Text.t("请向队友出示动态二维码，或扫描对方动态码", "Show your dynamic QR code to a teammate, or scan theirs")
        case .confirmationPending:
            title = W8Text.t("正在等待服务端确认", "Waiting for server confirmation")
            subtitle = W8Text.t("核验请求已提交，结果未明时可通过原请求回读确认", "The verification request was submitted. If the result is unclear, read back the original request to confirm")
        case .met:
            title = W8Text.t("已完成当面核验", "In-person verification complete")
            subtitle = W8Text.t("服务端已确认本次组队见面", "The server confirmed this team meet-up")
        case .cancelled:
            title = W8Text.t("见面已取消", "Meet-up canceled")
            subtitle = W8Text.t("任一方取消或撤回后本次见面终止，后续迟到响应不再生效", "The meet-up ends once either side cancels or withdraws, and later responses no longer apply")
        case .expired:
            title = W8Text.t("见面已过期", "Meet-up expired")
            subtitle = W8Text.t("超出有效时段，本次组队见面已结束", "The valid window has passed and this team meet-up has ended")
        }

        let isTerminal = [.met, .cancelled, .expired].contains(meeting.phase)
        return MeetingCard(
            teamId: meeting.eligibility.teamId,
            meetingId: meeting.eligibility.meetingId,
            phase: meeting.phase,
            phaseTitle: title,
            phaseSubtitle: subtitle,
            noInterestMatching: true,
            realNameScopedOnlyToStrangerMeeting: isRealNameStrictlyScoped(),
            availableHandshakes: handshakes,
            qrAlwaysOffered: handshakes.contains(.dynamicQR),
            nfcOffered: handshakes.contains(.nfcUnverified),
            requiresRealNameCheck: meeting.phase == .realNameRequired,
            canBeginHandshake: meeting.phase == .readyToMeet,
            canScanPeerCode: meeting.phase == .handshaking,
            awaitingServerDecision: meeting.phase == .confirmationPending,
            isTerminal: isTerminal,
            activeChallengePayload: meeting.phase == .handshaking ? codeState.payload : nil,
            isChallengeExpired: codeState.isExpired
        )
    }

    // MARK: - U02 & U04: Friend Multi-Invite & Revoke-Wins Presentation

    public struct RecipientRow: Equatable, Identifiable, Sendable {
        public let friendId: String
        public let displayName: String
        public let delivery: FriendMultiInvite.Delivery
        public let stableRequestId: String?
        public let statusBadgeText: String
        public let isRetryable: Bool
        public var id: String { friendId }
    }

    public struct InviteBatchCard: Equatable, Sendable {
        public let contextId: String
        public let phase: FriendMultiInvite.Phase
        public let selectedCount: Int
        public let maximumCount: Int
        public let selectionCounterText: String
        public let isReviewValid: Bool
        public let canSendReviewed: Bool
        public let canRetryFailedNow: Bool
        public let requiresUnknownReadbackFirst: Bool
        public let retryableRecipientIds: [String]
        public let unknownRecipientIds: [String]
        public let summary: FriendMultiInvite.Summary
        public let recipientRows: [RecipientRow]
    }

    /// Projects a `FriendMultiInvite` batch into a presentation card highlighting review invalidation,
    /// stable per-recipient request IDs, and failed-only retry rules (U02, U04).
    public static func presentInviteBatch(_ batch: FriendMultiInvite) -> InviteBatchCard {
        let rows: [RecipientRow] = batch.selected.map { target in
            let delivery = batch.deliveries[target.friendId] ?? .notSent
            let badge: String
            let retryable: Bool
            switch delivery {
            case .notSent:
                badge = W8Text.t("待发送", "Pending")
                retryable = true
            case .sent:
                badge = W8Text.t("已发送", "Sent")
                retryable = false
            case .rejected(let code):
                badge = W8Text.t("已拒绝（\(code)）", "Declined (\(code))")
                retryable = false
            case .failed:
                badge = W8Text.t("发送失败，可重试", "Failed to send. You can retry")
                retryable = true
            case .unknown:
                badge = W8Text.t("结果未明，需先回读", "Result unclear. Read back first")
                retryable = false
            case .revoked:
                badge = W8Text.t("已撤回", "Withdrawn")
                retryable = false
            }
            return RecipientRow(
                friendId: target.friendId,
                displayName: target.displayName,
                delivery: delivery,
                stableRequestId: batch.requestIds[target.friendId],
                statusBadgeText: badge,
                isRetryable: retryable
            )
        }

        let summary = batch.summary
        let retryableIds = rows.filter(\.isRetryable).map(\.friendId)
        let unknownIds = rows.filter { $0.delivery == .unknown }.map(\.friendId)
        let isReviewValid = batch.phase == .reviewed
        let canSendReviewed = batch.phase == .reviewed && !batch.selected.isEmpty
        let canRetryFailedNow = batch.phase == .finished && summary.retryable > 0 && summary.unknown == 0

        return InviteBatchCard(
            contextId: batch.contextId,
            phase: batch.phase,
            selectedCount: batch.selected.count,
            maximumCount: batch.maximum,
            selectionCounterText: "\(batch.selected.count) / \(batch.maximum)",
            isReviewValid: isReviewValid,
            canSendReviewed: canSendReviewed,
            canRetryFailedNow: canRetryFailedNow,
            requiresUnknownReadbackFirst: summary.unknown > 0,
            retryableRecipientIds: retryableIds,
            unknownRecipientIds: unknownIds,
            summary: summary,
            recipientRows: rows
        )
    }

    public struct RevokeLedgerBadge: Equatable, Sendable {
        public let subjectId: String
        public let display: RevokeWinsState.Display
        public let version: Int64
        public let isRevokeFinal: Bool
        public let statusText: String
        public let pendingToast: RevokeWinsState.Display?
    }

    /// Applies an ordered sequence of `RevokeWinsEvent` updates to a `RevokeWinsState` and formats
    /// the resulting terminal revocation state and notification gate (U04).
    public static func evaluateRevokeLedger(
        subjectId: String,
        events: [RevokeWinsEvent]
    ) throws -> RevokeLedgerBadge {
        var state = try RevokeWinsState(subjectId: subjectId)
        for event in events {
            _ = try state.apply(event)
        }
        let toast = state.notificationToShow()
        return presentRevokeState(state, pendingToast: toast)
    }

    public static func presentRevokeState(
        _ state: RevokeWinsState,
        pendingToast: RevokeWinsState.Display? = nil
    ) -> RevokeLedgerBadge {
        let text: String
        switch state.display {
        case .pending:
            text = W8Text.t("待回应", "Awaiting reply")
        case .accepted:
            text = W8Text.t("已接受", "Accepted")
        case .declined:
            text = W8Text.t("已婉拒", "Declined")
        case .revoked:
            text = W8Text.t("已撤回（终态）", "Withdrawn (final)")
        case .expired:
            text = W8Text.t("已过期", "Expired")
        case .unknown:
            text = W8Text.t("状态待确认", "Status unconfirmed")
        }
        return RevokeLedgerBadge(
            subjectId: state.subjectId,
            display: state.display,
            version: state.version,
            isRevokeFinal: state.display == .revoked,
            statusText: text,
            pendingToast: pendingToast
        )
    }

    // MARK: - U03: Beijing Deadline Dual-Zone Banner Presentation

    public struct DeadlineBanner: Equatable, Sendable {
        public let localTimeText: String
        public let governingBeijingTimeText: String?
        public let showsDualZone: Bool
        public let headlineText: String
        public let hint: BeijingDeadline.Hint
        public let advisoryStatusText: String
        public let allowsSubmission: Bool
    }

    /// Formats a `BeijingDeadline` for `phoneZone` and `locale`, displaying both the phone-zone time
    /// and the governing Beijing time when the offsets differ, while keeping submission enabled (U03).
    public static func presentDeadlineBanner(
        _ deadline: BeijingDeadline,
        phoneZone: TimeZone,
        locale: Locale = Locale(identifier: "zh_Hans_CN"),
        deviceNow: Date,
        serverOffset: TimeInterval,
        uncertainty: TimeInterval = 2
    ) -> DeadlineBanner {
        let pair = deadline.display(phoneZone: phoneZone, locale: locale)
        let hint = deadline.hint(deviceNow: deviceNow, serverOffset: serverOffset, uncertainty: uncertainty)
        let headline: String
        if let beijing = pair.beijing {
            headline = W8Text.t("截止时间：\(pair.local)（北京时间 \(beijing)）", "Deadline: \(pair.local) (Beijing time \(beijing))")
        } else {
            headline = W8Text.t("截止时间：\(pair.local)", "Deadline: \(pair.local)")
        }

        let advisory: String
        switch hint {
        case .open(let remainingSeconds):
            advisory = W8Text.t("距离截止还有 \(remainingSeconds) 秒", "\(remainingSeconds) seconds until the deadline")
        case .boundary:
            advisory = W8Text.t("临近截止时间，提交结果以服务端为准", "Close to the deadline. The server decides the result of any submission")
        case .likelyClosed:
            advisory = W8Text.t("已过截止时间（仍可提交由服务端裁定）", "Past the deadline (you can still submit; the server decides)")
        }

        return DeadlineBanner(
            localTimeText: pair.local,
            governingBeijingTimeText: pair.beijing,
            showsDualZone: pair.beijing != nil,
            headlineText: headline,
            hint: hint,
            advisoryStatusText: advisory,
            allowsSubmission: true
        )
    }
}
