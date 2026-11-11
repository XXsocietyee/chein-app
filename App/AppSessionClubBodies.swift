import Foundation

/// Raw-body club reads forwarded to the session reader (kept out of AppSession.swift, which is line-ratcheted).
extension AppSession {
    func clubHomeBody() async throws -> Data? { try await clubReader.clubHomeBody() }
    func clubDetailBody(id: Int) async throws -> Data? { try await clubReader.clubDetailBody(id: id) }
}
