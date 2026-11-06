import Foundation
import XCTest
@testable import QuestifyCore

@MainActor final class NativeAttributeAuthorMemoryStorage: TemplateAuthoringStorage {
    var values: [String: Data] = [:]
    var failWrites = false
    var writeCount = 0
    var failOnWrite: Int?
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws {
        writeCount += 1
        if failWrites || failOnWrite == writeCount { throw NativeAttributeAuthorError.storage }
        values[key] = data
    }
    func remove(_ key: String) throws { values[key] = nil }
}
@MainActor final class NativeAttributeAuthorRecordingTransport: NativeAttributeAuthorTransport {
    var requests: [NativeAttributeAuthorRequest] = []
    var beforeFinal: (() -> Void)?
    var response: (NativeAttributeAuthorRequest) async throws -> (Data, Int) = { request in
        return (NativeAttributeAuthorTestFixtures.envelope(NativeAttributeAuthorTestFixtures.row), 200)
    }
    func send(_ request: NativeAttributeAuthorRequest, finalCheck: @escaping @MainActor () throws -> Void) async throws -> (Data, Int) {
        beforeFinal?(); try finalCheck(); requests.append(request); return try await response(request)
    }
}

