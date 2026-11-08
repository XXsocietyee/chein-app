import Foundation
import XCTest
#if canImport(Questify)
@testable import Questify
#endif

/// Source-level mount proof plus a model-level no-network proof. Not a rendered-UI test.
@MainActor final class WP12QmodImportMountTests: XCTestCase {
    private func source(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("App/\(name)"), encoding: .utf8)
    }

    func testImportEntryReachableFromAuthorViews() throws {
        let views = try source("NativeAttributeAuthorViews.swift")
        XCTAssertTrue(views.contains("QmodAuthorImportView()"))
        XCTAssertTrue(views.contains("nativeAttribute.qmodImport"))
        // Mounted inside NativeAttributeAuthorView (reached only through NativeAttributeAuthorEntry), not a new route.
        let author = try XCTUnwrap(views.range(of: "struct NativeAttributeAuthorView"))
        let mount = try XCTUnwrap(views.range(of: "QmodAuthorImportView()"))
        XCTAssertLessThan(author.lowerBound, mount.lowerBound)
        let form = try XCTUnwrap(views.range(of: "struct NativeAttributeAuthorForm"))
        XCTAssertLessThan(mount.lowerBound, form.lowerBound)
        _ = QmodAuthorImportView()
    }

    func testImportDoesNotIssueNetworkRequest() throws {
        let importer = try source("QmodAuthorImportView.swift")
        for forbidden in ["URLSession", "URLRequest", "NativeAttributeAuthorTransport", "NativeAttributeAuthorService", "dataTask"] {
            XCTAssertFalse(importer.contains(forbidden), forbidden)
        }
        // The mount passes no coordinator/service/transport to the import view.
        let views = try source("NativeAttributeAuthorViews.swift")
        XCTAssertTrue(views.contains("NavigationLink { QmodAuthorImportView() }"))
        let model = QmodAuthorImportModel()
        XCTAssertEqual(model.session.phase, .idle)
    }
}
