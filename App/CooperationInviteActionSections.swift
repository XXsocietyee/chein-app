import SwiftUI

/// Source `pages/coop/invite-detail` "合作操作" card and bottom action bar. Every action opens the existing
/// dormant request review (`CoopFlowRequestPreview` / handle, perk and review editors); none dispatches.
@MainActor struct CooperationInviteActionSections: View {
    let view: CooperationInvitePresentation
    let peerReader: (any CoopFlowReading)?
    @Environment(\.dismiss) private var dismiss
    /// MC7-32-4: 进入项目 opens the bound topic when the list supplied the project destination.
    @Environment(\.cooperationProjectDestination) private var projectDestination
    private var invite: CooperationInvite { view.invite }
    var body: some View {
        if view.showsContactPartner, let peerReader { accepted(peerReader) }
        Section {
            switch view.footer {
            case .legacy: Text("cooperation.detail.footer.legacy").foregroundStyle(.secondary)
            case .decide:
                if let name = invite.supplyStationName, !name.isEmpty, invite.supplyStationId != nil {
                    Text(verbatim: name).cyText(.body).foregroundStyle(CYColor.textPrimary)
                        .accessibilityIdentifier("cooperation.detail.supplyStation")
                }
                // Mini bottom bar: 接受合作 is the single solid action, 拒绝 the quiet one.
                if let stationID = invite.supplyStationId {
                    // MC7-30-6: a station topic confirms the frozen station, then sends `supplyStationId` with the accept.
                    NavigationLink {
                        CoopSupplyStationAcceptView(inviteID: invite.id, stationID: stationID, stationName: invite.supplyStationName)
                    } label: {
                        Text("cooperation.detail.accept").cyText(.bodyMedium).foregroundStyle(CYColor.infoText)
                    }
                    .accessibilityIdentifier("cooperation.detail.handle.\(CoopFlowHandle.accept.rawValue)")
                } else {
                    handle(.accept, label: "cooperation.detail.accept", emphasis: true)
                }
                handle(.reject, label: "cooperation.detail.reject")
                Text("cooperation.detail.reply.hint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            case .withdraw:
                handle(.cancel, label: "cooperation.detail.withdraw")
                Text("cooperation.detail.withdraw.hint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            case .deposit:
                // 去缴纳保证金 has no payment path in the app; the owed amount is shown in 合作条款 above.
                Text("cooperation.detail.deposit.owedFooter").foregroundStyle(.secondary)
                // Mini goDeposit only sends the user back to the cooperation list, where the deposit flow lives.
                Button("cooperation.detail.deposit.backToList") { dismiss() }
                    .accessibilityIdentifier("cooperation.detail.deposit.backToList")
                Text("cooperation.detail.deposit.unavailable").cyText(.bodyCompact).foregroundStyle(.secondary)
            case .ongoing(let frozen):
                Text(LocalizedStringKey(frozen ? "cooperation.detail.footer.ongoingFrozen" : "cooperation.detail.footer.ongoing")).foregroundStyle(.secondary)
            case .inactive: Text("cooperation.detail.footer.inactive").foregroundStyle(.secondary)
            }
        }.accessibilityIdentifier("cooperation.detail.footer")
    }

    @ViewBuilder private func accepted(_ reader: any CoopFlowReading) -> some View {
        Section("cooperation.detail.actions") {
            if let scope = view.projectScope, let topic = invite.topicId {
                if let projectDestination, topic > 0 {
                    NavigationLink {
                        CooperationProjectNavigationDestination(topicID: topic, invite: CooperationInviteKey(id: invite.id, direction: view.direction),
                                                                destination: projectDestination)
                    } label: { Text("cooperation.detail.project") }
                    .accessibilityIdentifier("cooperation.detail.project.\(scope.rawValue)")
                } else {
                    LabeledContent { Text(verbatim: "#" + String(topic)) } label: { Text("cooperation.detail.project") }
                        .accessibilityIdentifier("cooperation.detail.project.\(scope.rawValue)")
                }
            }
            NavigationLink { CoopFlowRequestPreview(operation: .contact(inviteID: invite.id)) } label: { Text("cooperation.detail.contactPartner") }
                .accessibilityIdentifier("cooperation.detail.contactPartner")
            if view.showsPerkDeclaration {
                NavigationLink { CoopFlowPerkPicker(reader: reader, inviteID: invite.id) } label: { Text("cooperation.detail.declarePerks") }
                    .accessibilityIdentifier("cooperation.detail.declarePerks")
            }
            if view.showsReview, let member = view.revieweeID, let topic = invite.topicId, member != reader.session?.accountID {
                CooperationInviteReviewRow(reader: reader, memberID: member, topicID: topic, partnerName: invite.partner?.name)
            }
        }
        // MR-36 (`186:6119`): 取消合作 sits alone in the last group of the actions, not among the normal rows.
        Section {
            if view.cancelLocked {
                VStack(alignment: .leading, spacing: 2) {
                    Text("cooperation.detail.cancelAccepted").foregroundStyle(.secondary)
                    Text("cooperation.detail.cancelLocked").cyText(.bodyCompact).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("cooperation.detail.cancelLocked")
            } else {
                NavigationLink { CoopFlowHandleEditor(inviteID: invite.id, action: .cancel, currentStatus: 1) } label: {
                    Text("cooperation.detail.cancelAccepted").foregroundStyle(CYColor.dangerText)
                }.accessibilityIdentifier("cooperation.detail.cancelAccepted")
            }
        }
    }
    private func handle(_ action: CoopFlowHandle, label: String, emphasis: Bool = false) -> some View {
        let stationID = action == .accept ? invite.supplyStationId : nil
        return NavigationLink {
            CoopFlowHandleEditor(inviteID: invite.id, action: action, currentStatus: invite.status ?? 0,
                                 supplyStationID: stationID,
                                 supplyStationName: stationID == nil ? nil : invite.supplyStationName,
                                 flowReader: stationID == nil ? nil : peerReader)
        } label: {
            Text(LocalizedStringKey(label)).cyText(emphasis ? .bodyMedium : .body)
                .foregroundStyle(emphasis ? CYColor.infoText : CYColor.textPrimary)
        }
            .accessibilityIdentifier("cooperation.detail.handle.\(action.rawValue)")
    }
}

/// Shows "已评价 ★…" when this viewer already reviewed the topic (source `loadMyReview`), else the review editor.
@MainActor struct CooperationInviteReviewRow: View {
    let reader: any CoopFlowReading
    let memberID: Int
    let topicID: Int
    let partnerName: String?
    @Environment(\.locale) private var locale
    @State private var rating: Int?
    @State private var loadedSession: CoopFlowSession?
    @State private var selectedScoreID: String?
    @State private var showsCommentPrompt = false
    @State private var commentText = ""
    @State private var showsPreview = false

    private var selectedRating: Int {
        Int(selectedScoreID ?? "5") ?? 5
    }

    var body: some View {
        Group {
            if let rating, loadedSession == reader.session {
                LabeledContent { Text(verbatim: String(repeating: "★", count: rating)) } label: { Text("cooperation.detail.reviewed") }
                    .accessibilityIdentifier("cooperation.detail.reviewed")
            } else {
                // MR-36 (`186:6119`): five tappable stars in place (no pick sheet); the word under them follows the tap,
                // then 下一步 asks for the optional comment and opens the same request review as before.
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("cooperation.detail.review")
                    CoopStarRatingControl(selection: $selectedScoreID, locale: locale)
                    if selectedScoreID != nil {
                        Button {
                            commentText = ""
                            showsCommentPrompt = true
                        } label: {
                            HStack {
                                Text(verbatim: MerchantAreaCopy.text("下一步", "Next", locale))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .cyText(.meta, weight: .semibold)
                                    .foregroundStyle(CYColor.textSecondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cooperation.detail.review")
                    }
                }
            }
        }
        .cyPromptModalOverlay(
            isPresented: showsCommentPrompt,
            title: MerchantAreaCopy.text("评语(选填)", "Comment (optional)", locale),
            message: partnerName.flatMap { $0.isEmpty ? nil : $0 },
            text: $commentText,
            placeholder: MerchantAreaCopy.text("说说这次合作…", "Share how this cooperation went…", locale),
            cancelTitle: MerchantAreaCopy.cancel(locale),
            confirmTitle: MerchantAreaCopy.text("提交", "Submit", locale),
            onCancel: { showsCommentPrompt = false },
            onConfirm: {
                showsCommentPrompt = false
                showsPreview = true
            }
        )
        .navigationDestination(isPresented: $showsPreview) {
            CoopFlowRequestPreview(
                operation: .review(
                    topicID: topicID,
                    memberID: memberID,
                    rating: selectedRating,
                    comment: commentText
                )
            )
        }
        .task(id: "\(reader.session?.accountID ?? 0):\(reader.session?.epoch ?? 0):\(memberID):\(topicID)") {
            rating = nil; loadedSession = nil
            guard let session = reader.session else { return }
            // A failed summary read only leaves the review entry available; it never claims a rating.
            guard let summary = try? await reader.read(.reviewSummary(memberID: memberID)), !Task.isCancelled, reader.session == session else { return }
            rating = CooperationInvitePresentation.myRating(summary: summary, me: session.accountID, topicID: topicID); loadedSession = session
        }
    }
}

/// Source `typeText`: "from → to" party labels, else the invite-type label.
struct CooperationInvitePartyText: View {
    let view: CooperationInvitePresentation
    var body: some View {
        if let keys = view.partyKeys {
            Text(LocalizedStringKey(keys.from)) + Text(verbatim: " → ") + Text(LocalizedStringKey(keys.to))
        } else { Text(LocalizedStringKey(view.inviteTypeKey)) }
    }
}
/// Source `termsOf`: a missing rate or fee shows "?" rather than a default.
struct CooperationInviteTermsText: View {
    let terms: CooperationInvitePresentation.Terms
    var body: some View {
        switch terms {
        case .traffic: Text("cooperation.terms.traffic")
        case .share(let rate): Text("cooperation.detail.terms.share \(rate.map(cooperationInviteNumber) ?? "?")")
        case .fixed(let fee): Text("cooperation.detail.terms.fixed \(fee.map(cooperationInviteMoney) ?? "?")")
        case .unknown: Text(verbatim: "—")
        }
    }
}
struct CooperationInviteDepositText: View {
    let deposit: CooperationInvitePresentation.Deposit
    var body: some View {
        switch deposit {
        case .notRequired: Text("cooperation.detail.deposit.none")
        case .owed(let amount?): Text("cooperation.detail.deposit.owed \(cooperationInviteMoney(amount))").monospacedDigit().foregroundStyle(CYColor.dangerText)
        case .owed(nil): Text("cooperation.detail.deposit.owedUnknown").foregroundStyle(CYColor.dangerText)
        }
    }
}
/// No default amount, exchange rate, estimated deposit or contract total.
func cooperationInviteNumber(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...8))) }
/// Owner decision #9 (2026-11-24): money shows two decimals through the one shared formatter (`MoneyDisplay`).
func cooperationInviteMoney(_ value: Double) -> String {
    MoneyDisplay.plain(Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value))
}

/// MR-36 star rating: five stars, tap to set; the word under them changes with the tap; one `.selection` tick per tap.
/// The cooperation contract (`test_cooperation_structure`) keeps these pages free of custom motion, so the stars fill
/// without a stagger or pop; the system symbol swap is the only change.
struct CoopStarRatingControl: View {
    @Binding var selection: String?
    let locale: Locale

    private var value: Int { selection.flatMap(Int.init) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(1...5, id: \.self) { star in
                    Button { select(star) } label: {
                        Image(systemName: star <= value ? "star.fill" : "star")
                            .cyText(.sectionTitle)
                            .foregroundStyle(star <= value ? CYColor.warningText : CYColor.textTertiary)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                }
            }
            .sensoryFeedback(.selection, trigger: value)
            Group {
                if let score = selection.flatMap(CoopReviewScore.init(rawValue:)) {
                    Text(verbatim: score.option(locale: locale).title)
                } else {
                    Text(verbatim: MerchantAreaCopy.text("点星星打分", "Tap a star to rate", locale))
                }
            }
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: MerchantAreaCopy.text("评分", "Rating", locale)))
        .accessibilityValue(Text(verbatim: value == 0 ? "—" : "\(value) / 5"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(min(5, max(1, value + 1)))
            case .decrement: select(max(1, value - 1))
            @unknown default: break
            }
        }
        .accessibilityIdentifier("cooperation.detail.rating")
    }

    private func select(_ star: Int) { selection = String(star) }
}
