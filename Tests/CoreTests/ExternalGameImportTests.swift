import XCTest
import CryptoKit
@testable import QuestifyCore

@MainActor final class ExternalGameImportTests: XCTestCase {
    private let signer = ExternalGameFixtureSigner()

    private func makeTempStore() -> (ExternalGameStore, URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ExternalGameTests-" + UUID().uuidString, isDirectory: true)
        let store = ExternalGameStore(rootDirectory: tempDir, verificationPublicKey: signer.publicKey)
        return (store, tempDir)
    }

    private func sample(id: String = "rpg.campfire.riddle", name: String = "篝火谜题小游戏", version: String = "1.0.0",
                        entry: String = "index.html", permissions: [String] = ["storage", "haptics"],
                        contentRating: String = "4+", allowedDomains: [String] = ["assets.example.com"],
                        sign: ((Data) -> String)? = nil) -> ExternalGamePackageArchive {
        ExternalGameStore.makeSampleSignedArchive(id: id, name: name, version: version, entry: entry, permissions: permissions,
                                                  contentRating: contentRating, allowedDomains: allowedDomains,
                                                  sign: sign ?? signer.signPayload)
    }

    func testValidSignedArchiveImportInstallUpdateRemoveAndBridge() throws {
        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archiveV1 = sample(
            id: "rpg.campfire.riddle",
            name: "篝火谜题",
            version: "1.0.0",
            permissions: ["storage", "haptics"],
            contentRating: "4+",
            allowedDomains: ["assets.example.com"]
        )
        let confirmation = try store.prepareImport(
            archive: archiveV1,
            source: .url(URL(string: "https://example.com/packages/riddle.json")!)
        )
        XCTAssertFalse(confirmation.isUpdate)
        XCTAssertEqual(confirmation.permissionsList, [.storage, .haptics])

        let installed = try store.confirmInstall()
        XCTAssertEqual(store.installedGames.count, 1)
        XCTAssertEqual(installed.manifest.version, "1.0.0")
        XCTAssertNotNil(store.entryFileURL(for: installed))

        // Update to v1.1.0
        let archiveV2 = sample(
            id: "rpg.campfire.riddle",
            name: "篝火谜题",
            version: "1.1.0",
            permissions: ["storage"],
            contentRating: "9+",
            allowedDomains: ["assets.example.com"]
        )
        let updateConf = try store.prepareImport(
            archive: archiveV2,
            source: .qrCode("https://example.com/packages/riddle-v2.json")
        )
        XCTAssertTrue(updateConf.isUpdate)
        XCTAssertEqual(updateConf.previousVersion, "1.0.0")
        let updated = try store.confirmInstall()
        XCTAssertEqual(store.installedGames.count, 1)
        XCTAssertEqual(updated.manifest.version, "1.1.0")

        // Versioned JS bridge v1.0
        let saveReq = try JSONEncoder().encode(ExternalGameBridgeRequest(
            apiVersion: "1.0",
            action: "saveProgress",
            payload: ["stage": "2"]
        ))
        let saveRes = store.handleBridgeMessage(saveReq, for: "rpg.campfire.riddle")
        XCTAssertTrue(saveRes.ok)

        let loadReq = try JSONEncoder().encode(ExternalGameBridgeRequest(
            apiVersion: "1.0",
            action: "loadProgress"
        ))
        let loadRes = store.handleBridgeMessage(loadReq, for: "rpg.campfire.riddle")
        XCTAssertTrue(loadRes.ok)
        XCTAssertEqual(loadRes.data?["stage"], "2")

        // Haptics was removed in v1.1.0 permissions, so bridge must deny it
        let hapticReq = try JSONEncoder().encode(ExternalGameBridgeRequest(
            apiVersion: "1.0",
            action: "haptic"
        ))
        let hapticRes = store.handleBridgeMessage(hapticReq, for: "rpg.campfire.riddle")
        XCTAssertFalse(hapticRes.ok)
        XCTAssertEqual(hapticRes.error, "PERMISSION_DENIED_HAPTICS")

        // Unknown bridge version or non-allowlisted action is rejected
        let badVerReq = try JSONEncoder().encode(ExternalGameBridgeRequest(
            apiVersion: "2.0",
            action: "getMetadata"
        ))
        XCTAssertEqual(store.handleBridgeMessage(badVerReq, for: "rpg.campfire.riddle").error, "UNSUPPORTED_API_VERSION")

        let payReq = try JSONEncoder().encode(ExternalGameBridgeRequest(
            apiVersion: "1.0",
            action: "requestPayment"
        ))
        XCTAssertEqual(store.handleBridgeMessage(payReq, for: "rpg.campfire.riddle").error, "ACTION_NOT_ALLOWLISTED")

        // Remove package
        try store.remove(id: "rpg.campfire.riddle")
        XCTAssertTrue(store.installedGames.isEmpty)
    }

    func testRejectsPathTraversalAndDisallowedExtensions() {
        let badPaths = [
            "../index.html",
            "../../etc/passwd",
            "/abs/index.html",
            "sub/../../escape.html",
            "sub\\win.html",
            ".hidden.html",
            "sub/.secret.js",
            "a//b.html",
        ]
        for path in badPaths {
            XCTAssertFalse(ExternalGameValidator.isSafeRelativePath(path), "Must reject path traversal: \(path)")
            let archive = ExternalGameStore.makeSampleSignedArchive(entry: path)
            XCTAssertThrowsError(try ExternalGameValidator.validateArchive(archive)) { error in
                XCTAssertEqual(error as? ExternalGameValidationError, .pathTraversalDetected(path))
            }
        }

        let badExtArchive = ExternalGameStore.makeSampleSignedArchive(entry: "payload.dylib")
        XCTAssertThrowsError(try ExternalGameValidator.validateArchive(badExtArchive)) { error in
            XCTAssertEqual(error as? ExternalGameValidationError, .disallowedFileExtension("payload.dylib"))
        }
    }

    func testRejectsOversizedFilesAndPackages() {
        let oversizedFile = Data(repeating: 0x41, count: ExternalGameValidator.maxSingleFileSizeBytes + 1)
        let files: [String: Data] = [
            "index.html": Data("<html></html>".utf8),
            "big.png": oversizedFile,
        ]
        let sha = ExternalGameValidator.computePackageSHA256(files)
        var manifest = ExternalGameManifest(
            id: "rpg.oversized.test",
            name: "Oversized",
            version: "1.0.0",
            entry: "index.html",
            sha256: sha,
            signature: ""
        )
        manifest = ExternalGameManifest(
            id: manifest.id,
            name: manifest.name,
            version: manifest.version,
            entry: manifest.entry,
            sha256: sha,
            signature: ""
        )
        let archive = ExternalGamePackageArchive(manifest: manifest, files: files)
        XCTAssertThrowsError(try ExternalGameValidator.validateArchive(archive)) { error in
            guard case ExternalGameValidationError.fileOversized(let name, _, _) = error else {
                XCTFail("Expected fileOversized, got \(error)")
                return
            }
            XCTAssertEqual(name, "big.png")
        }
    }

    func testRejectsUnsignedTamperedHashAndInvalidSignature() {
        let valid = ExternalGameStore.makeSampleSignedArchive()
        let unsignedManifest = ExternalGameManifest(
            id: valid.manifest.id,
            name: valid.manifest.name,
            version: valid.manifest.version,
            entry: valid.manifest.entry,
            sha256: valid.manifest.sha256,
            signature: ""
        )
        XCTAssertThrowsError(try ExternalGameValidator.validateArchive(
            ExternalGamePackageArchive(manifest: unsignedManifest, files: valid.files)
        )) { error in
            XCTAssertEqual(error as? ExternalGameValidationError, .unsignedManifest)
        }

        // Tamper file content without updating hash
        let tamperedFiles = ["index.html": Data("<html><h1>Tampered</h1></html>".utf8)]
        XCTAssertThrowsError(try ExternalGameValidator.validateArchive(
            ExternalGamePackageArchive(manifest: valid.manifest, files: tamperedFiles)
        )) { error in
            guard case ExternalGameValidationError.hashMismatch = error else {
                XCTFail("Expected hashMismatch, got \(error)")
                return
            }
        }

        let wrongSig = ExternalGameStore.makeSampleSignedArchive(sign: ExternalGameFixtureSigner().signPayload)
        XCTAssertThrowsError(try ExternalGameValidator.validateArchive(wrongSig, publicKeyRaw: signer.publicKey)) { error in
            XCTAssertEqual(error as? ExternalGameValidationError, .invalidSignature)
        }
    }

    func testRejectsBadDomainsInsecureURLsForbiddenPermissionsAndIAP() {
        let badDomains = [
            "*.example.com",
            "https://example.com",
            "example.com/path",
            "example.com:8443",
            "localhost",
            "127.0.0.1",
            "192.168.1.1",
            "10.0.0.1",
            "internal.local",
            "user@example.com",
        ]
        for domain in badDomains {
            XCTAssertFalse(ExternalGameValidator.isValidDomain(domain), "Must reject domain: \(domain)")
            let archive = ExternalGameStore.makeSampleSignedArchive(allowedDomains: [domain])
            XCTAssertThrowsError(try ExternalGameValidator.validateArchive(archive)) { error in
                XCTAssertEqual(error as? ExternalGameValidationError, .invalidAllowedDomain(domain))
            }
        }

        // Insecure HTTP import URL rejected
        XCTAssertThrowsError(try ExternalGameValidator.validateImportURL(URL(string: "http://example.com/game.json")!))

        // Forbidden permission rejected
        for forbidden in ["payment", "iap", "camera", "location", "native-bridge"] {
            let archive = ExternalGameStore.makeSampleSignedArchive(permissions: [forbidden])
            XCTAssertThrowsError(try ExternalGameValidator.validateArchive(archive)) { error in
                XCTAssertEqual(error as? ExternalGameValidationError, .forbiddenPermission(forbidden))
            }
        }

        // Embedded payment/IAP script rejected
        let iapFiles = ["index.html": Data("<script>new ApplePaySession(3, {});</script>".utf8)]
        let sha = ExternalGameValidator.computePackageSHA256(iapFiles)
        var m = ExternalGameManifest(id: "rpg.iap.attempt", name: "IAP", version: "1.0.0", entry: "index.html", sha256: sha, signature: "")
        m = ExternalGameManifest(id: m.id, name: m.name, version: m.version, entry: m.entry, sha256: sha, signature: "")
        XCTAssertThrowsError(try ExternalGameValidator.validateArchive(ExternalGamePackageArchive(manifest: m, files: iapFiles))) { error in
            XCTAssertEqual(error as? ExternalGameValidationError, .paymentOrIAPDetected("ApplePaySession"))
        }
    }

    func testSandboxNavigationPolicyAndCSP() {
        let archive = ExternalGameStore.makeSampleSignedArchive(allowedDomains: ["cdn.example.com"])
        let csp = ExternalGameSandboxPolicy.contentSecurityPolicy(for: archive.manifest)
        XCTAssertTrue(csp.contains("default-src 'self'"))
        XCTAssertTrue(csp.contains("connect-src https://cdn.example.com"))
        XCTAssertTrue(csp.contains("frame-src 'none'"))

        let root = URL(fileURLWithPath: "/tmp/sandbox/packages/rpg.campfire.riddle", isDirectory: true)
        let validFile = root.appendingPathComponent("index.html")
        let escapedFile = URL(fileURLWithPath: "/tmp/sandbox/packages/other/index.html")
        XCTAssertTrue(ExternalGameSandboxPolicy.allowsNavigation(to: validFile, packageRoot: root, manifest: archive.manifest))
        XCTAssertFalse(ExternalGameSandboxPolicy.allowsNavigation(to: escapedFile, packageRoot: root, manifest: archive.manifest))
        XCTAssertTrue(ExternalGameSandboxPolicy.allowsNavigation(to: URL(string: "https://cdn.example.com/sprite.png")!, packageRoot: root, manifest: archive.manifest))
        XCTAssertFalse(ExternalGameSandboxPolicy.allowsNavigation(to: URL(string: "https://evil.example.com/sprite.png")!, packageRoot: root, manifest: archive.manifest))
        XCTAssertFalse(ExternalGameSandboxPolicy.allowsNavigation(to: URL(string: "itms-apps://itunes.apple.com")!, packageRoot: root, manifest: archive.manifest))
        XCTAssertFalse(ExternalGameSandboxPolicy.allowsNavigation(to: URL(string: "weixin://wap/pay")!, packageRoot: root, manifest: archive.manifest))
    }

    // MARK: FP-H4 (App Store 1.2 / 4.7)

    func testManifestAllowedDomainsAreEmptyByDefaultAndNoNetworkIsReachable() {
        let manifest = ExternalGameManifest(id: "rpg.default.domains", name: "Default", version: "1.0.0", entry: "index.html", sha256: "x", signature: "y")
        XCTAssertEqual(manifest.allowedDomains, [])
        let root = URL(fileURLWithPath: "/tmp/sandbox/packages/rpg.default.domains", isDirectory: true)
        for url in ["https://cdn.example.com/a.png", "https://example.com", "http://example.com/a.png"] {
            XCTAssertFalse(ExternalGameSandboxPolicy.allowsNavigation(to: URL(string: url)!, packageRoot: root, manifest: manifest), url)
        }
        XCTAssertTrue(ExternalGameSandboxPolicy.contentSecurityPolicy(for: manifest).contains("default-src 'self'"))
    }

    func testBlockingAPackageAlsoBlocksItsCreatorAcrossRelaunch() throws {
        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let first = sample(id: "rpg.block.one", allowedDomains: [])
        _ = try store.prepareImport(archive: first, source: .file(URL(fileURLWithPath: "/tmp/one.json")))
        let installed = try store.confirmInstall()
        XCTAssertNotNil(store.entryFileURL(for: installed))
        store.activeLaunchingGame = installed

        store.block(installed.manifest)
        XCTAssertNil(store.activeLaunchingGame, "block closes the running game")
        XCTAssertNil(store.entryFileURL(for: installed), "a blocked package cannot run")
        XCTAssertTrue(store.isBlocked(installed.manifest))

        let sibling = sample(id: "rpg.block.two", allowedDomains: [])
        XCTAssertThrowsError(try store.prepareImport(archive: sibling, source: .file(URL(fileURLWithPath: "/tmp/two.json")))) {
            XCTAssertEqual($0 as? ExternalGameValidationError, .blockedByUser(sibling.manifest.name))
        }
        XCTAssertNil(store.pendingConfirmation)

        let relaunched = ExternalGameStore(rootDirectory: tempDir, verificationPublicKey: signer.publicKey)
        XCTAssertTrue(relaunched.isBlocked(installed.manifest))
        XCTAssertThrowsError(try relaunched.prepareImport(archive: sibling, source: .file(URL(fileURLWithPath: "/tmp/two.json"))))

        relaunched.unblock(installed.manifest)
        XCTAssertFalse(relaunched.isBlocked(installed.manifest))
        XCTAssertNoThrow(try relaunched.prepareImport(archive: sibling, source: .file(URL(fileURLWithPath: "/tmp/two.json"))))
    }

    func testReportSummaryNamesThePackageAndCreatorWithoutAnyEndpoint() {
        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let manifest = ExternalGameStore.makeSampleSignedArchive(id: "rpg.report.one", allowedDomains: ["cdn.example.com"]).manifest
        let text = store.reportSummary(for: manifest)
        for expected in ["id: rpg.report.one", "creator: Chein Workshop", "sha256: \(manifest.sha256)", "allowedDomains: cdn.example.com"] {
            XCTAssertTrue(text.contains(expected), expected)
        }
        XCTAssertFalse(text.contains("http"), "no URL or support endpoint is invented")
        XCTAssertFalse(text.contains("@"), "no email address is invented")
    }

    func testEd25519RoundTripAndEmptyKeyFailsClosed() throws {
        let archive = sample(id: "rpg.verify.one", permissions: [], allowedDomains: [])
        XCTAssertTrue(ExternalGameValidator.verifyServerSignature(archive.manifest, publicKeyRaw: signer.publicKey))
        XCTAssertFalse(ExternalGameValidator.verifyServerSignature(archive.manifest, publicKeyRaw: Data()))
        XCTAssertNoThrow(try ExternalGameValidator.validateArchive(archive, publicKeyRaw: signer.publicKey))
    }

    func testAgeGateIsPerGameAndKillSwitchRemovesUnpublished() throws {
        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let archive = sample(id: "rpg.keep.one", permissions: [], contentRating: "12+", allowedDomains: [])
        _ = try store.prepareImport(archive: archive, source: .file(URL(fileURLWithPath: "/tmp/keep.json")))
        let installed = try store.confirmInstall()
        XCTAssertTrue(store.ageGateNeedsConfirmation(installed.manifest))
        store.acceptAgeGate(installed.manifest)
        XCTAssertFalse(store.ageGateNeedsConfirmation(installed.manifest))
        let relaunched = ExternalGameStore(rootDirectory: tempDir, verificationPublicKey: signer.publicKey)
        XCTAssertFalse(relaunched.ageGateNeedsConfirmation(installed.manifest))
        XCTAssertEqual(try relaunched.removeUnpublished(approvedGameIDs: ["rpg.keep.one"]), [])
        XCTAssertEqual(try relaunched.removeUnpublished(approvedGameIDs: []), ["rpg.keep.one"])
        XCTAssertTrue(relaunched.installedGames.isEmpty)
    }

    func testExternalGameReviewStatusLeavesPendingOnlyWhenTheServerConfirms() throws {
        var gate = WorkshopModuleImportGate()
        try gate.beginExternalGameReview(requestID: "extsub-abc-12345678")
        XCTAssertEqual(gate.phase, .reviewPending)
        XCTAssertNil(gate.externalGameServerStatus)
        XCTAssertFalse(gate.applyExternalGameServerStatus("MYSTERY", requestID: "extsub-abc-12345678"))
        XCTAssertEqual(gate.phase, .reviewPending)
        XCTAssertFalse(gate.applyExternalGameServerStatus("PENDING", requestID: "other-request"))
        XCTAssertTrue(gate.applyExternalGameServerStatus("PENDING", requestID: "extsub-abc-12345678"))
        XCTAssertEqual(gate.phase, .reviewPending)
        XCTAssertEqual(gate.externalGameServerStatus, "PENDING")
        XCTAssertTrue(gate.applyExternalGameServerStatus("REJECTED", requestID: "extsub-abc-12345678"))
        XCTAssertEqual(gate.phase, .externalGameReviewed)
        XCTAssertEqual(gate.externalGameServerStatus, "REJECTED")
    }

    func testStrictCSPRemovesAttackerMetaAndEntryVerifiesIntegrityAndPinning() throws {
        let htmlWithPermissiveCSP = """
        <HTML><HEAD><META HTTP-EQUIV='Content-Security-Policy' CONTENT="script-src 'unsafe-inline' *"></HEAD><body>hi</body></HTML>
        """
        let files = ["index.html": Data(htmlWithPermissiveCSP.utf8)]
        let sha = ExternalGameValidator.computePackageSHA256(files)
        var manifest = ExternalGameManifest(
            id: "rpg.csp.hardening",
            name: "CSP Hardening",
            version: "1.0.0",
            entry: "index.html",
            sha256: sha,
            signature: ""
        )
        let sig = signer.signPayload(ExternalGameValidator.canonicalSigningPayload(for: manifest))
        manifest = ExternalGameManifest(
            id: manifest.id, name: manifest.name, version: manifest.version,
            entry: manifest.entry, sha256: manifest.sha256, signature: sig
        )
        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = try store.prepareImport(archive: ExternalGamePackageArchive(manifest: manifest, files: files), source: .file(URL(fileURLWithPath: "/tmp/csp.json")))
        let installed = try store.confirmInstall()
        XCTAssertEqual(installed.hardenedEntrySHA256?.count, 64)
        XCTAssertEqual(installed.hardenedPackageSHA256?.count, 64)

        let entryURL = try XCTUnwrap(store.entryFileURL(for: installed))
        let writtenHTML = try String(contentsOf: entryURL, encoding: .utf8)
        XCTAssertFalse(writtenHTML.contains("unsafe-inline' *"))
        XCTAssertTrue(writtenHTML.hasPrefix("<meta http-equiv=\"Content-Security-Policy\" content=\""))
        XCTAssertEqual(writtenHTML, ExternalGameSandboxPolicy.applyStrictCSP(to: htmlWithPermissiveCSP, manifest: manifest))

        // Relaunched store with pinned key must also open the hardened entry
        let relaunched = ExternalGameStore(rootDirectory: tempDir, verificationPublicKey: signer.publicKey)
        let relaunchedGame = try XCTUnwrap(relaunched.installedGames.first)
        XCTAssertNotNil(relaunched.entryFileURL(for: relaunchedGame))

        // Unpinned empty key must fail closed even on unmodified store
        let unpinnedStore = ExternalGameStore(rootDirectory: tempDir, verificationPublicKey: Data())
        XCTAssertNil(unpinnedStore.entryFileURL(for: installed))

        // Tampering with the installed HTML must fail closed before load
        try Data("<script>evil()</script>".utf8).write(to: entryURL)
        XCTAssertNil(store.entryFileURL(for: installed))
        XCTAssertNil(relaunched.entryFileURL(for: relaunchedGame))
    }

    func testEntryWithOwnCSPMetaAndCompanionFilesInstallsOpensAndDetectsTampering() throws {
        let creatorHTML = """
        <!doctype html>
        <html>
        <head>
          <meta http-equiv="Content-Security-Policy" content="default-src * 'unsafe-inline'">
          <me<meta http-equiv="content-security-policy" content="x">ta http-equiv="content-security-policy" content="script-src 'unsafe-eval'">
        </head>
        <body><script src="game.js"></script></body>
        </html>
        """
        let files: [String: Data] = [
            "index.html": Data(creatorHTML.utf8),
            "game.js": Data("console.log('ok');".utf8),
        ]
        let sha = ExternalGameValidator.computePackageSHA256(files)
        let unsigned = ExternalGameManifest(
            id: "rpg.csp.companion",
            name: "CSP Companion",
            version: "1.0.0",
            entry: "index.html",
            sha256: sha,
            signature: ""
        )
        let sig = signer.signPayload(ExternalGameValidator.canonicalSigningPayload(for: unsigned))
        let manifest = ExternalGameManifest(
            id: unsigned.id, name: unsigned.name, version: unsigned.version,
            entry: unsigned.entry, sha256: sha, signature: sig
        )
        let expectedHardened = ExternalGameSandboxPolicy.applyStrictCSP(to: creatorHTML, manifest: manifest)
        XCTAssertEqual(
            expectedHardened,
            ExternalGameSandboxPolicy.applyStrictCSP(to: creatorHTML, manifest: manifest),
            "Strict CSP application must be deterministic"
        )
        XCTAssertFalse(expectedHardened.contains("unsafe-eval"))
        XCTAssertFalse(expectedHardened.contains("default-src *"))

        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = try store.prepareImport(
            archive: ExternalGamePackageArchive(manifest: manifest, files: files),
            source: .file(URL(fileURLWithPath: "/tmp/csp-companion.json"))
        )
        let installed = try store.confirmInstall()
        let entryURL = try XCTUnwrap(store.entryFileURL(for: installed))
        XCTAssertEqual(try String(contentsOf: entryURL, encoding: .utf8), expectedHardened)

        // Tampering with companion JS file on disk must also be refused
        let jsURL = store.packageDirectory(for: manifest.id).appendingPathComponent("game.js")
        try Data("console.log('tampered');".utf8).write(to: jsURL)
        XCTAssertNil(store.entryFileURL(for: installed))

        // Legacy or unhashed installed game records without hardenedEntrySHA256 must fail closed
        let legacyRecord = InstalledExternalGame(
            manifest: manifest,
            source: installed.source,
            installedAt: installed.installedAt,
            updatedAt: installed.updatedAt,
            totalBytes: installed.totalBytes
        )
        XCTAssertNil(store.entryFileURL(for: legacyRecord))
    }

    func testTamperedPackageIsRefusedAtInstall() throws {
        let (store, tempDir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let valid = sample(id: "rpg.tamper.install")
        var modifiedFiles = valid.files
        modifiedFiles["index.html"] = Data("<html><body>tampered</body></html>".utf8)

        // 1. Tampered package bytes with original signed manifest -> hashMismatch
        let tamperedBytesArchive = ExternalGamePackageArchive(manifest: valid.manifest, files: modifiedFiles)
        XCTAssertThrowsError(try store.prepareImport(
            archive: tamperedBytesArchive,
            source: .file(URL(fileURLWithPath: "/tmp/tampered-bytes.json"))
        )) { error in
            guard case ExternalGameValidationError.hashMismatch = error else {
                XCTFail("Expected hashMismatch, got \(error)")
                return
            }
        }
        XCTAssertNil(store.pendingConfirmation)
        XCTAssertTrue(store.installedGames.isEmpty)

        // 2. Tampered package bytes + updated sha256 without valid server Ed25519 signature -> invalidSignature
        let updatedSHA = ExternalGameValidator.computePackageSHA256(modifiedFiles)
        let forgedManifest = ExternalGameManifest(
            id: valid.manifest.id,
            name: valid.manifest.name,
            version: valid.manifest.version,
            entry: valid.manifest.entry,
            permissions: valid.manifest.permissions,
            contentRating: valid.manifest.contentRating,
            allowedDomains: valid.manifest.allowedDomains,
            sha256: updatedSHA,
            signature: valid.manifest.signature,
            author: valid.manifest.author,
            summary: valid.manifest.summary
        )
        let tamperedData = try JSONEncoder().encode(ExternalGamePackageArchive(manifest: forgedManifest, files: modifiedFiles))
        XCTAssertThrowsError(try store.prepareImport(
            archiveData: tamperedData,
            source: .file(URL(fileURLWithPath: "/tmp/tampered-sig.json"))
        )) { error in
            XCTAssertEqual(error as? ExternalGameValidationError, .invalidSignature)
        }
        XCTAssertNil(store.pendingConfirmation)
        XCTAssertTrue(store.installedGames.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.packageDirectory(for: valid.manifest.id).path))
    }

    func testBridgeRejectsUnexpectedArgsBadStorageKeysBadHapticAndTotalQuota() throws {
        let archive = sample(id: "rpg.bridge.hardening", permissions: ["storage", "haptics"])
        var progress: [String: String] = [:]

        let metaWithArgs = try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "getMetadata", payload: ["extra": "1"]))
        XCTAssertEqual(ExternalGameBridgeHandler.handle(rawJSON: metaWithArgs, manifest: archive.manifest, progressStore: &progress).error, "INVALID_ARGUMENTS")

        let badKey = try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "saveProgress", payload: ["bad/key": "1"]))
        XCTAssertEqual(ExternalGameBridgeHandler.handle(rawJSON: badKey, manifest: archive.manifest, progressStore: &progress).error, "STORAGE_QUOTA_EXCEEDED")

        let badHaptic = try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "haptic", payload: ["style": "arbitrary"]))
        XCTAssertEqual(ExternalGameBridgeHandler.handle(rawJSON: badHaptic, manifest: archive.manifest, progressStore: &progress).error, "INVALID_ARGUMENTS")

        let okHaptic = try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "haptic", payload: ["style": "light"]))
        XCTAssertTrue(ExternalGameBridgeHandler.handle(rawJSON: okHaptic, manifest: archive.manifest, progressStore: &progress).ok)

        // Filling beyond 64 total entries across multiple calls hits STORAGE_QUOTA_EXCEEDED
        var batch1: [String: String] = [:]
        var batch2: [String: String] = [:]
        for i in 0..<32 { batch1["k\(i)"] = "v"; batch2["m\(i)"] = "v" }
        XCTAssertTrue(ExternalGameBridgeHandler.handle(
            rawJSON: try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "saveProgress", payload: batch1)),
            manifest: archive.manifest, progressStore: &progress
        ).ok)
        XCTAssertTrue(ExternalGameBridgeHandler.handle(
            rawJSON: try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "saveProgress", payload: batch2)),
            manifest: archive.manifest, progressStore: &progress
        ).ok)
        let extra = try JSONEncoder().encode(ExternalGameBridgeRequest(apiVersion: "1.0", action: "saveProgress", payload: ["overflow": "1"]))
        XCTAssertEqual(ExternalGameBridgeHandler.handle(rawJSON: extra, manifest: archive.manifest, progressStore: &progress).error, "STORAGE_QUOTA_EXCEEDED")
    }
}

final class ExternalGameFixtureSigner {
    private let privateKey = Curve25519.Signing.PrivateKey()
    var publicKey: Data { privateKey.publicKey.rawRepresentation }
    func signPayload(_ payload: Data) -> String {
        let signature = (try? privateKey.signature(for: payload)) ?? Data()
        return signature.map { String(format: "%02x", $0) }.joined()
    }
}
