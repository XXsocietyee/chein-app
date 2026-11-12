import XCTest
@testable import QuestifyCore

final class G7ClientRulesTests: XCTestCase {
    func testBoundaryDoesNotCallNetworkOrEnableMoney() {
        XCTAssertFalse(G7ClientRuleBoundary.performsNetwork)
        XCTAssertFalse(G7ClientRuleBoundary.enablesMoney)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        for kind in ReleaseMoneyWriteKind.allCases {
            XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind))
        }
    }

    func testCT04dDecliningShareKeepsPlayAndRoam() {
        for consent in ShareConsentChoice.allCases {
            for activity in OrdinaryActivity.allCases {
                let decision = ShareDeclineParticipation.decide(activity, shareConsent: consent)
                XCTAssertEqual(decision.activity, activity)
                XCTAssertEqual(decision.shareConsent, consent)
                XCTAssertTrue(decision.allowed)
            }
        }
        let declinedPlay = ShareDeclineParticipation.decide(.play, shareConsent: .declined)
        let declinedRoam = ShareDeclineParticipation.decide(.roam, shareConsent: .declined)
        XCTAssertTrue(declinedPlay.allowed)
        XCTAssertTrue(declinedRoam.allowed)
        XCTAssertEqual(declinedPlay.allowed, ShareDeclineParticipation.decide(.play, shareConsent: .granted).allowed)
        XCTAssertEqual(declinedRoam.allowed, ShareDeclineParticipation.decide(.roam, shareConsent: .unset).allowed)
    }

    func testCT04eCopiesDoNotExtendRetentionOrGainUses() {
        let sourceEnd = Date(timeIntervalSince1970: 1_700_086_400)
        let longer = sourceEnd.addingTimeInterval(86_400)
        let shorter = sourceEnd.addingTimeInterval(-3_600)
        let sourceUses: Set<LocationRetentionUse> = [.activePlayCapture]
        for kind in LocationCopyKind.allCases {
            let kept = LocationCopyRetention.evaluate(LocationCopyClaim(
                kind: kind, sourceEndsAt: sourceEnd, proposedEndsAt: shorter,
                sourceUses: sourceUses, proposedUses: sourceUses))
            XCTAssertEqual(kept, .kept(endsAt: sourceEnd, uses: sourceUses))
            let extended = LocationCopyRetention.evaluate(LocationCopyClaim(
                kind: kind, sourceEndsAt: sourceEnd, proposedEndsAt: longer,
                sourceUses: sourceUses, proposedUses: sourceUses))
            XCTAssertEqual(extended, .refusedExtension)
            let newUse = LocationCopyRetention.evaluate(LocationCopyClaim(
                kind: kind, sourceEndsAt: sourceEnd, proposedEndsAt: sourceEnd,
                sourceUses: sourceUses, proposedUses: [.personalShare]))
            XCTAssertEqual(newUse, .refusedNewUse)
        }
    }

    func testCT05cPlaceIDsStayDistinctKinds() {
        let raw = "42"
        let refs = GeographicPlaceKind.allCases.map { GeographicPlaceRef(kind: $0, raw: raw) }
        for lhs in refs {
            for rhs in refs where lhs.kind != rhs.kind {
                XCTAssertFalse(GeographicPlaceIDs.samePlace(lhs, rhs))
            }
        }
        let poi = GeographicPlaceRef(kind: .pointOfInterest, raw: raw)
        let node = GeographicPlaceRef(kind: .gameNode, raw: raw)
        let store = GeographicPlaceRef(kind: .store, raw: raw)
        let provider = GeographicPlaceRef(kind: .mapProvider, raw: raw)
        XCTAssertEqual(GeographicPlaceIDs.pointOfInterest(poi)?.raw, raw)
        XCTAssertNil(GeographicPlaceIDs.pointOfInterest(node))
        XCTAssertNil(GeographicPlaceIDs.pointOfInterest(store))
        XCTAssertNil(GeographicPlaceIDs.pointOfInterest(provider))
        XCTAssertEqual(GeographicPlaceIDs.gameNode(node)?.raw, raw)
        XCTAssertNil(GeographicPlaceIDs.gameNode(poi))
        XCTAssertEqual(GeographicPlaceIDs.store(store)?.raw, raw)
        XCTAssertNil(GeographicPlaceIDs.store(provider))
        XCTAssertEqual(GeographicPlaceIDs.mapProvider(provider)?.raw, raw)
        XCTAssertNil(GeographicPlaceIDs.mapProvider(store))
        XCTAssertTrue(GeographicPlaceIDs.samePlace(poi, GeographicPlaceRef(kind: .pointOfInterest, raw: raw)))
        XCTAssertNil(GeographicPlaceIDs.pointOfInterest(GeographicPlaceRef(kind: .pointOfInterest, raw: "")))
        XCTAssertFalse(GeographicPlaceIDs.samePlace(
            GeographicPlaceRef(kind: .store, raw: ""),
            GeographicPlaceRef(kind: .store, raw: "")))
        XCTAssertNotEqual(PointOfInterestID(raw: raw), PointOfInterestID(raw: "43"))
        XCTAssertEqual(GameNodeID(raw: raw), GameNodeID(raw: raw))
        XCTAssertEqual(StorePlaceID(raw: raw).raw, raw)
        XCTAssertEqual(MapProviderPlaceID(raw: raw).raw, raw)
    }

    func testCT07ePendingPhotoAwardsNothingAndReplayReturnsOriginal() {
        let original = OriginalTaskCompletion(taskInstanceID: "task-7", score: 80, requiredComplete: false)
        let pending = PhotoSubstituteCompletion.rule(
            original: original, review: .pending, proposedScore: 100, proposedAdvance: true,
            replayOrSwitchMethod: false)
        XCTAssertEqual(pending.substituteScore, 0)
        XCTAssertFalse(pending.advancesRequiredCompletion)
        XCTAssertEqual(pending.completion, original)
        XCTAssertFalse(pending.callsNetwork)
        XCTAssertNotEqual(pending.substituteScore, 100)

        let replay = PhotoSubstituteCompletion.rule(
            original: original, review: .pending, proposedScore: 100, proposedAdvance: true,
            replayOrSwitchMethod: true)
        XCTAssertEqual(replay.completion, original)
        XCTAssertEqual(replay.completion.score, 80)
        XCTAssertFalse(replay.completion.requiredComplete)
        XCTAssertEqual(replay.substituteScore, 0)
        XCTAssertFalse(replay.advancesRequiredCompletion)
        XCTAssertFalse(replay.callsNetwork)

        let switched = PhotoSubstituteCompletion.rule(
            original: original, review: .notPending, proposedScore: 100, proposedAdvance: true,
            replayOrSwitchMethod: true)
        XCTAssertEqual(switched.completion, original)
        XCTAssertEqual(switched.substituteScore, 0)
        XCTAssertFalse(switched.advancesRequiredCompletion)

        let alreadyDone = OriginalTaskCompletion(taskInstanceID: "task-7", score: 80, requiredComplete: true)
        let replayDone = PhotoSubstituteCompletion.rule(
            original: alreadyDone, review: .pending, proposedScore: 0, proposedAdvance: false,
            replayOrSwitchMethod: true)
        XCTAssertEqual(replayDone.completion, alreadyDone)
        XCTAssertTrue(replayDone.completion.requiredComplete)
        XCTAssertEqual(replayDone.substituteScore, 0)
    }

    func testCT09bHalfUnitBalanceAndCapacityNeverSpendMoney() {
        let oneHalfFromOneWhole = QuotaUnitGate.check(
            balance: .whole(1), request: .halves(1), capacityHalfSteps: 4, spendsMoney: false)
        XCTAssertEqual(oneHalfFromOneWhole.gate, .admit)
        XCTAssertEqual(oneHalfFromOneWhole.remaining, .halves(1))
        XCTAssertFalse(oneHalfFromOneWhole.chargedMoney)

        let wholeNeedsTwoHalves = QuotaUnitGate.check(
            balance: .halves(1), request: .whole(1), capacityHalfSteps: 4, spendsMoney: false)
        XCTAssertEqual(wholeNeedsTwoHalves.gate, .insufficientBalance)
        XCTAssertEqual(wholeNeedsTwoHalves.remaining, .halves(1))

        let exact = QuotaUnitGate.check(
            balance: .halves(2), request: .whole(1), capacityHalfSteps: 2, spendsMoney: false)
        XCTAssertEqual(exact.gate, .admit)
        XCTAssertEqual(exact.remaining, .halves(0))

        let overCapacity = QuotaUnitGate.check(
            balance: .unlimited, request: .whole(2), capacityHalfSteps: 3, spendsMoney: false)
        XCTAssertEqual(overCapacity.gate, .overCapacity)
        XCTAssertEqual(overCapacity.remaining, .unlimited)

        let unlimited = QuotaUnitGate.check(
            balance: .unlimited, request: .halves(3), capacityHalfSteps: nil, spendsMoney: false)
        XCTAssertEqual(unlimited.gate, .admit)
        XCTAssertEqual(unlimited.remaining, .unlimited)
        XCTAssertFalse(unlimited.chargedMoney)

        let negative = QuotaUnitGate.check(
            balance: .whole(-1), request: .halves(1), capacityHalfSteps: 4, spendsMoney: false)
        XCTAssertEqual(negative.gate, .invalidQuantity)
        let unlimitedRequest = QuotaUnitGate.check(
            balance: .unlimited, request: .unlimited, capacityHalfSteps: nil, spendsMoney: false)
        XCTAssertEqual(unlimitedRequest.gate, .invalidQuantity)

        let money = QuotaUnitGate.check(
            balance: .whole(4), request: .halves(1), capacityHalfSteps: nil, spendsMoney: true)
        XCTAssertEqual(money.gate, .moneyDisabled)
        XCTAssertEqual(money.remaining, .whole(4))
        XCTAssertFalse(money.chargedMoney)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
    }

    func testCT09cNoShowTouchesOnlyThatUnit() {
        let ticket = MultiUseTicket(ticketID: "ticket-9", units: [
            TicketUnit(id: "a", state: .available),
            TicketUnit(id: "b", state: .reserved),
            TicketUnit(id: "c", state: .fulfilled)
        ])
        let missed = MissedAppointmentTicket.recordNoShow(ticket, unitID: "b")
        XCTAssertFalse(missed.wholeTicketVoided)
        XCTAssertFalse(missed.chargesMoney)
        XCTAssertFalse(missed.refundsMoney)
        XCTAssertEqual(missed.ticket.ticketID, "ticket-9")
        XCTAssertEqual(missed.ticket.units.map(\.state), [.available, .noShow, .fulfilled])
        XCTAssertEqual(missed.ticket.units.map(\.id), ["a", "b", "c"])

        let unknown = MissedAppointmentTicket.recordNoShow(ticket, unitID: "missing")
        XCTAssertEqual(unknown.ticket.units, ticket.units)
        XCTAssertFalse(unknown.wholeTicketVoided)

        let fulfilled = MissedAppointmentTicket.recordNoShow(ticket, unitID: "c")
        XCTAssertEqual(fulfilled.ticket.units.map(\.state), [.available, .reserved, .fulfilled])
        XCTAssertFalse(fulfilled.chargesMoney)
        XCTAssertFalse(fulfilled.refundsMoney)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
    }

    func testCT14bExpiredReferenceDoesNotBecomeLocationlessPublicPost() {
        let live = PublicReferencePost(postID: "post-14", referenceExpired: false, hasLocation: true, isPublic: true)
        let shown = ExpiredPublicReference.resolve(live, downgradeToLocationlessPublic: false)
        XCTAssertTrue(shown.visible)
        XCTAssertTrue(shown.isPublic)
        XCTAssertTrue(shown.hasLocation)
        XCTAssertFalse(shown.isLocationlessPublicPost)

        let expired = PublicReferencePost(postID: "post-14", referenceExpired: true, hasLocation: true, isPublic: true)
        let expiredWithoutDowngrade = ExpiredPublicReference.resolve(expired, downgradeToLocationlessPublic: false)
        XCTAssertFalse(expiredWithoutDowngrade.visible)
        XCTAssertFalse(expiredWithoutDowngrade.isPublic)
        XCTAssertTrue(expiredWithoutDowngrade.hasLocation)
        XCTAssertFalse(expiredWithoutDowngrade.isLocationlessPublicPost)
        let withheld = ExpiredPublicReference.resolve(expired, downgradeToLocationlessPublic: true)
        XCTAssertFalse(withheld.visible)
        XCTAssertFalse(withheld.isPublic)
        XCTAssertTrue(withheld.hasLocation)
        XCTAssertFalse(withheld.isLocationlessPublicPost)

        let refusedDowngrade = ExpiredPublicReference.resolve(live, downgradeToLocationlessPublic: true)
        XCTAssertFalse(refusedDowngrade.visible)
        XCTAssertFalse(refusedDowngrade.isPublic)
        XCTAssertTrue(refusedDowngrade.hasLocation)
        XCTAssertFalse(refusedDowngrade.isLocationlessPublicPost)
    }
}
