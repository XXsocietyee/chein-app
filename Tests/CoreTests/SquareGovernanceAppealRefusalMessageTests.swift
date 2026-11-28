import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `post-governance` submit: a definite refusal shows `requestError(res, '申诉未提交')`, i.e. the server `msg`
/// after `safeUserMessage`. Native carries it on `SquareGovernanceFailure.appealRefused(message:)`.
@MainActor final class SquareGovernanceAppealRefusalMessageTests: XCTestCase {
    private func fixture() -> (SquareGovernanceCoordinator, SquareGovernanceSyntheticAccess, SquareGovernanceSyntheticTransport) {
        let transport = SquareGovernanceSyntheticTransport()
        return (.init(service: .init(offlineBaseURL: URL(string: "https://square-governance.invalid")!, transport: transport), journal: .ephemeral()), .init(), transport)
    }

    func testRefusalCarriesTheServerSentenceAndReleasesTheRow() async throws {
        let (coordinator, access, transport) = fixture(); let snapshot = try await coordinator.load(access: access)
        transport.mutationReply = (code: 422, status: 200)
        transport.mutationMessage = "该处置已超过申诉期限"
        let review = try coordinator.prepare(.appeal(enforcementID: 91, reason: "facts"), snapshot: snapshot, access: access)
        do { _ = try await coordinator.confirm(review, access: access); XCTFail() } catch {
            XCTAssertEqual(error as? SquareGovernanceFailure, .appealRefused(message: "该处置已超过申诉期限"))
        }
        XCTAssertFalse(coordinator.dispatched(.appeal(enforcementID: 91, reason: ""), snapshot: snapshot))
    }

    func testDiagnosticTextFallsBackToTheFixedCopy() async throws {
        let (coordinator, access, transport) = fixture(); let snapshot = try await coordinator.load(access: access)
        transport.mutationReply = (code: 400, status: 400)
        transport.mutationMessage = "java.lang.IllegalStateException: bad SQL grammar"
        let review = try coordinator.prepare(.appeal(enforcementID: 91, reason: "facts"), snapshot: snapshot, access: access)
        do { _ = try await coordinator.confirm(review, access: access); XCTFail() } catch {
            XCTAssertEqual(error as? SquareGovernanceFailure, .appealRefused(message: nil))
        }
    }

    func testSignedOutRefusalStaysSignedOut() async throws {
        let (coordinator, access, transport) = fixture(); let snapshot = try await coordinator.load(access: access)
        transport.mutationReply = (code: 401, status: 401)
        let review = try coordinator.prepare(.appeal(enforcementID: 91, reason: "facts"), snapshot: snapshot, access: access)
        do { _ = try await coordinator.confirm(review, access: access); XCTFail() } catch {
            XCTAssertEqual(error as? SquareGovernanceFailure, .signedOut)
        }
    }

    func testRefusalMessageFilterMatchesTheMPSafeUserMessage() {
        func message(_ text: String) -> String? { SquareGovernanceService.refusalMessage(.object(["msg": .string(text)])) }
        XCTAssertEqual(message("  该处置已超过申诉期限 "), "该处置已超过申诉期限")
        XCTAssertNil(message(""))
        XCTAssertNil(message("参数错误"))
        XCTAssertNil(message("认证失败，无法访问系统资源"))
        XCTAssertNil(message("see https://example.invalid/api/x"))
        XCTAssertNil(message("请联系 13800138000"))
        XCTAssertNil(message(String(repeating: "长", count: 61)))
        XCTAssertNil(message("第一行\n第二行"))
        XCTAssertEqual(SquareGovernanceService.refusalMessage(.object(["message": .string("申诉理由不能包含联系方式")])), "申诉理由不能包含联系方式")
        XCTAssertNil(SquareGovernanceService.refusalMessage(nil))
    }
}
