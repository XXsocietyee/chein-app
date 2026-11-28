# K40 · AI NPC, guide, and creation

Branch `cursor/1128-k40-ai` from `origin/ui/combined-r7` pin `a7c956335`. Base for the PR is `ui/combined-r7`. Not deployed. `main` untouched. No secrets, no executed SQL, no money-switch edits. `App/AppSession.swift` stays 7977 lines. Play init order stays `devices`, `sensors`, `artworkHosts`. Merchant AI stays off (`AICreationReleaseApprovals` has no merchant case). The AI row stays the first item of the player create menu (`PublishTabRootView.publishMenu`, `PublishingModesViews`). No `String(localized:)` literals in the AI files this pass touched.

Counts: **n=11** audit rows rechecked, **m=5** already fixed, **k=4** closed here with a test, **2** left.

## Already fixed (m=5)

| Row | Where it stands | SHA |
|---|---|---|
| Plan R-18 roam NPC prompt (profile + reviewed event line, no persona) | `G6RoamNPCPromptModel` still draws the bubble from `api/ai/npc/profile` and `api/ai/npc/event` | `83796dab6` |
| Plan J-04a shop NPC text and voice in Release | `shopNPCWrites`, text/voice/mic grants, paths `shop-chat` and `voice-chat`. Playback stays off | `4ef826127` |
| Brief AI guide on roam and play | `AIGuideToolbarButton` on `RoamLiveSessionView` and play. Formless in roam | `8ff088499` |
| Functions audit: Settings 「AI 对话记录」 was Unverified | Release read lease and delete path are on. Proof: `testReleaseCompositionIssuesNPCChatDataReadAndDeletion` | `4ef826127` |
| Plan H-08a template fill for club hosts | `.publishingAITemplate` → `api/ai/template/fill`. Players and merchants get no grant | `1b09f1e2b` |

## Closed here (k=4)

| Row | Change | Test |
|---|---|---|
| Plan J-04c and H-16: dead `POST /api/ai/npc/dialogue` | Removed `ShopNPCHTTP.dialogue` and the unused `ShopNPCDialogueReceipt`. Live chat stays `shop-chat` / `voice-chat`. Journey asks stay off (`journeyAsks` false, `api/ai/npc/chat` not in the Release play paths) | `testShopNPCTextUsesShopChatAndRateLimits`, `test_k40_ai_npc_guide_creation.test_unserved_dialogue_path_is_not_a_client_method`, `test_shop_npc_interruption` |
| Plan H-08b quota skip | A precheck skip is quota only when the server message is exactly `今日AI次数已用完`. A longer sentence that contains that phrase is `.unavailable`, still not a block | `AICreationReleaseCompositionTests.testVerdictClassificationMatchesTheMP` |
| Plan H-08c club-design quota | Same exact phrase. The role gate `当前身份暂不支持AI创作` does not contain the quota phrase and classifies as identity, not quota. Template-fill 403 returns that same constant | `ClubContextualTests.testClubAIRoleGateIsIdentityAndNotTheQuotaPhrase` |
| ADA e4-settings: AI chat records had no chevron | The row stays the MP option-sheet button (`npcData.open`). It now shows the same trailing chevron as the other Settings button rows. VoiceOver hides the glyph | `test_mine_b_ai_chat_clear_count.test_row_shows_a_chevron_and_stays_a_sheet_button` |

Theme-draft instants (creation, not a separate audit row): `G6AIThemeDraft.instant` accepts only UTC text with a `T` and a trailing `Z` (`2030-01-01T00:00:00Z` and fractional `.250Z`). It refuses `+08:00`, `+00:00`, a space separator, a lowercase `z`, and a dash in the time part. The parser started at `83796dab6`; the offset refusal and the UTC formatter zone are this branch. Proof: `G6CapabilitySourceTests.testThemeDraftInstantsAreUTCWithTAndTrailingZ`.

## Left

| Row | Why it stays |
|---|---|
| Plan J-04b humanoid figure stage | Owner inventory row 20: the figure waits on the P3 avatar vendor. The presence ring from `8ff088499` stays |
| Plan J-14 AI score card | No `aiScore` in the app, and the planning audit says the backend does not emit it. Nothing was invented |

Roam free chat stays closed (owner 07-22, backend `chatOn()` hard false). Footprint hint stays with mp-roam (the map circle). Merchant NPC setup stays deferred.

## Gates

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_a11y_lint.py` PASS (0 new). `python3 tools/check_design_consistency.py` PASS (0 new). `python3 tools/contract_ratchet.py --check` 46 failing, baseline 46, **new 0**, fixed 0. `AppSession` ratchet PASS (7977). No `swiftc` on this machine, so the new XCTest methods were not executed. Contract checks that pin the same rules did run.

## Backend

`https://github.com/XXsocietyee/hengyin` returned **404** (`git ls-remote` repository not found; the contents API and `us/r3-functional` also 404). No `cursor/1128-be-k40-ai` branch. No JDK compile. The full app diff for this pass follows.

```diff
diff --git a/App/NPCChatDataReadSettingsEntry.swift b/App/NPCChatDataReadSettingsEntry.swift
index 53b8decdc..3b3ed45ba 100644
--- a/App/NPCChatDataReadSettingsEntry.swift
+++ b/App/NPCChatDataReadSettingsEntry.swift
@@ -30,8 +30,15 @@ struct NPCChatDataReadPresentation: Identifiable {
                 pendingIdentity = renderedIdentity
                 showsOptions = true
             } label: {
-                // MP shezhi AI 对话记录 = icon_lc_message-square-text.
-                Label { Text("mpd.aiChat.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcMessageSquareText) }
+                // MP shezhi AI 对话记录 = icon_lc_message-square-text. The row opens the option sheet, so it stays a
+                // button; the chevron matches the other Settings rows (ADA e4-settings).
+                HStack {
+                    Label { Text("mpd.aiChat.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcMessageSquareText) }
+                    Spacer(minLength: 0)
+                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
+                        .accessibilityHidden(true)
+                }
+                .contentShape(Rectangle())
             }
             .foregroundStyle(CYColor.textPrimary)
             .accessibilityIdentifier("npcData.open")
diff --git a/Core/AISafetyPrecheck.swift b/Core/AISafetyPrecheck.swift
index f8a83a1cc..b0c772278 100644
--- a/Core/AISafetyPrecheck.swift
+++ b/Core/AISafetyPrecheck.swift
@@ -78,7 +78,10 @@ public struct AISafetyPrecheckVerdict: Equatable {
 
     public static let blindTypes: Set<String> = ["missing_cover"]
     public static let advisoryTypes: Set<String> = ["timeline_conflict", "parse_error"]
-    static let quotaHint = "今日AI次数已用完"
+    /// The only server message that skips the precheck as quota. A longer sentence that merely contains it does not.
+    public static let quotaHint = "今日AI次数已用完"
+    /// Backend role gate (`gateRole` / template-fill 403). It must not contain `quotaHint`, or a quota skip would hide it.
+    public static let roleGate = "当前身份暂不支持AI创作"
 
     public init(blocking: [PublishingSafetyIssue], advisory: [PublishingSafetyIssue], skip: Skip?) {
         self.blocking = blocking
@@ -94,7 +97,7 @@ public struct AISafetyPrecheckVerdict: Equatable {
     }
 
     public static func skipped(message: String?) -> Self {
-        let quota = (message ?? "").contains(quotaHint)
+        let quota = message == quotaHint
         return Self(blocking: [], advisory: [], skip: quota ? .quota : .unavailable)
     }
 
diff --git a/Core/ClubAIDesignFlow.swift b/Core/ClubAIDesignFlow.swift
index 10456c26d..d14bb6aaf 100644
--- a/Core/ClubAIDesignFlow.swift
+++ b/Core/ClubAIDesignFlow.swift
@@ -132,7 +132,7 @@ public struct ClubAIDesignResult: Equatable {
             }
             catch { failure = error as? ClubAIDesignFailure ?? .parse }
         case .rejected(let message):
-            if message.contains("今日AI次数已用完") { failure = .quota }
+            if message == AISafetyPrecheckVerdict.quotaHint { failure = .quota }
             else if message.contains("身份") || message.contains("登录") { failure = .identity }
             else { failure = .unavailable }
         case .unknown: failure = .unknown
diff --git a/Core/G6AIThemeDraft.swift b/Core/G6AIThemeDraft.swift
index b15558bd3..4d9d8b2c2 100644
--- a/Core/G6AIThemeDraft.swift
+++ b/Core/G6AIThemeDraft.swift
@@ -37,14 +37,18 @@ public enum G6AIThemeDraft {
         return text
     }
 
-    /// An ISO instant ending in `Z` with a `T` separator that parses.
+    /// A UTC instant: a `T` separator and a trailing `Z`. Offsets (`+08:00`, `+00:00`) and a space separator are refused.
     public static func instant(_ value: Any?) -> Date? {
-        guard let text = value as? String, text.hasSuffix("Z"), text.contains("T") else { return nil }
+        guard let text = value as? String, text.hasSuffix("Z"), !text.contains("+"),
+              let separator = text.firstIndex(of: "T"), text.distance(from: text.startIndex, to: separator) >= 8,
+              !text[text.index(after: separator)...].dropLast().contains("-") else { return nil }
         let fractional = ISO8601DateFormatter()
         fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
+        fractional.timeZone = TimeZone(secondsFromGMT: 0)
         if let date = fractional.date(from: text) { return date }
         let plain = ISO8601DateFormatter()
         plain.formatOptions = [.withInternetDateTime]
+        plain.timeZone = TimeZone(secondsFromGMT: 0)
         return plain.date(from: text)
     }
 
diff --git a/Core/PublishingAuxiliaryService.swift b/Core/PublishingAuxiliaryService.swift
index 06ccbc130..f56d3a954 100644
--- a/Core/PublishingAuxiliaryService.swift
+++ b/Core/PublishingAuxiliaryService.swift
@@ -150,7 +150,7 @@ public struct PublishingSafetyIssue: Equatable {
             if review.request.path == "api/ai/template/fill" {
                 let body = try? OperationAdapterHTTP.envelope(data), code = body?["code"]?.integer
                 if status == 401 || code == 401 { try journal.clear(record); return .rejected("请先登录") }
-                if status == 403 || code == 403 { try journal.clear(record); return .rejected("当前身份暂不支持AI创作") }
+                if status == 403 || code == 403 { try journal.clear(record); return .rejected(AISafetyPrecheckVerdict.roleGate) }
             }
             guard (200..<300).contains(status), let body = try? OperationAdapterHTTP.envelope(data), let code = body["code"]?.integer else {
                 // fix/1128c-ai-showcase: the safety precheck moves nothing, so a failed answer clears its marker; a stuck
diff --git a/Core/ShopNPCContracts.swift b/Core/ShopNPCContracts.swift
index 764708758..5f9d418d2 100644
--- a/Core/ShopNPCContracts.swift
+++ b/Core/ShopNPCContracts.swift
@@ -121,40 +121,6 @@ public struct ShopNPCDialogueEffect: Equatable, Identifiable {
         try self.init(type: kind, key: key, delta: wire.delta, value: wire.value, label: wire.label)
     }
 }
-public struct ShopNPCDialogueReceipt: Equatable {
-    public let requestID: UUID
-    public let npcID: Int
-    public let routeActionID: String
-    public let stateVersion: Int
-    public let reply: String
-    public let effects: [ShopNPCDialogueEffect]
-    public let relation: ShopNPCRelationBadge?
-    public static func decode(_ bytes: Data, requestID: UUID, npcID: Int, routeActionID: String) throws -> Self {
-        struct Envelope: Decodable {
-            var code: Int?; var msg: String?; var data: Payload?
-            struct Payload: Decodable {
-                var npcId: Int?; var routeActionId: String?; var stateVersion: Int?; var reply: String?
-                var effects: [ShopNPCDialogueEffect.Wire]?; var relation: ShopNPCRelationBadge.Wire?
-            }
-        }
-        let body: Envelope
-        do { body = try JSONDecoder().decode(Envelope.self, from: bytes) }
-        catch { throw ShopNPCFailure.malformed }
-        guard let code = body.code else { throw ShopNPCFailure.malformed }
-        guard code == 200 else { throw ShopNPCFailure.server(code: code, message: body.msg) }
-        guard let data = body.data,
-              data.npcId == npcID,
-              data.routeActionId == routeActionID,
-              let version = data.stateVersion, version >= 0,
-              let reply = data.reply, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
-              reply.utf8.count <= 32_768 else {
-            throw ShopNPCFailure.malformed
-        }
-        let effects = try (data.effects ?? []).map(ShopNPCDialogueEffect.init(wire:))
-        let relation = try data.relation.map(ShopNPCRelationBadge.init(wire:))
-        return Self(requestID: requestID, npcID: npcID, routeActionID: routeActionID, stateVersion: version, reply: reply, effects: effects, relation: relation)
-    }
-}
 public struct ShopNPCReply: Equatable {
     public enum Outcome: String, Equatable { case succeeded = "SUCCEEDED", rejected = "REJECTED", failed = "FAILED", processing = "PROCESSING" }
     public let requestID: UUID
diff --git a/Core/ShopNPCHTTP.swift b/Core/ShopNPCHTTP.swift
index bd71fc9a7..73452018a 100644
--- a/Core/ShopNPCHTTP.swift
+++ b/Core/ShopNPCHTTP.swift
@@ -44,15 +44,6 @@ public extension ShopNPCHTTPTransport {
         append("\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"requestId\"\r\n\r\n\(requestID.uuidString)\r\n--\(boundary)--\r\n")
         return try await dispatch(path: "/api/ai/npc/voice-chat", type: "multipart/form-data; boundary=\(boundary)", body: data, scope: scope, voice: true)
     }
-    public func dialogue(topicID: Int, activityID: Int, npcID: Int, utterance: String, routeActionID: String, scope: ShopNPCScope, requestID: UUID = UUID()) async throws -> ShopNPCDialogueReceipt {
-        struct Body: Encodable { let topicId: Int; let activityId: Int; let npcId: Int; let utterance: String; let routeActionId: String }
-        let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
-        guard topicID > 0, activityID >= 0, npcID > 0, !trimmed.isEmpty, !routeActionID.isEmpty else { throw ShopNPCFailure.invalid }
-        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
-        let bytes = try encoder.encode(Body(topicId: topicID, activityId: activityID, npcId: npcID, utterance: trimmed, routeActionId: routeActionID))
-        let response = try await performRaw(path: "/api/ai/npc/dialogue", type: "application/json", body: bytes, scope: scope)
-        return try ShopNPCDialogueReceipt.decode(response.body, requestID: requestID, npcID: npcID, routeActionID: routeActionID)
-    }
     private func dispatch(path: String, type: String, body: Data, scope: ShopNPCScope, voice: Bool) async throws -> ShopNPCReply {
         let response = try await performRaw(path: path, type: type, body: body, scope: scope)
         return try ShopNPCReply.decode(response.body, voice: voice)
diff --git a/Tests/AppUnitTests/AICreationReleaseCompositionTests.swift b/Tests/AppUnitTests/AICreationReleaseCompositionTests.swift
index 63bd46f74..607195c46 100644
--- a/Tests/AppUnitTests/AICreationReleaseCompositionTests.swift
+++ b/Tests/AppUnitTests/AICreationReleaseCompositionTests.swift
@@ -164,8 +164,13 @@ import Foundation
         XCTAssertEqual(verdict.blocking.map(\.message), ["夜间水边"])
         XCTAssertEqual(verdict.advisory.map(\.message), ["营业时间", "提示少"], "missing_cover is dropped; timeline is advisory")
         XCTAssertFalse(verdict.allowsPublish)
-        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.unavailable("今日AI次数已用完")).skip, .quota)
-        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.rejected("当前身份暂不支持AI创作")).skip, .unavailable)
+        XCTAssertEqual(AISafetyPrecheckVerdict.quotaHint, "今日AI次数已用完")
+        XCTAssertEqual(AISafetyPrecheckVerdict.roleGate, "当前身份暂不支持AI创作")
+        XCTAssertFalse(AISafetyPrecheckVerdict.roleGate.contains(AISafetyPrecheckVerdict.quotaHint))
+        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.unavailable(AISafetyPrecheckVerdict.quotaHint)).skip, .quota)
+        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.unavailable(AISafetyPrecheckVerdict.quotaHint + "，请明天再来")).skip, .unavailable,
+                       "only the exact quota phrase is a quota skip")
+        XCTAssertEqual(AISafetyPrecheckRunner.verdict(.rejected(AISafetyPrecheckVerdict.roleGate)).skip, .unavailable)
         XCTAssertTrue(AISafetyPrecheckRunner.verdict(.unknown).allowsPublish, "AI never blocks the publish path")
     }
 
diff --git a/Tests/ContractChecks/test_mine_b_ai_chat_clear_count.py b/Tests/ContractChecks/test_mine_b_ai_chat_clear_count.py
index 3b3cc1bd8..a5b2a2b82 100644
--- a/Tests/ContractChecks/test_mine_b_ai_chat_clear_count.py
+++ b/Tests/ContractChecks/test_mine_b_ai_chat_clear_count.py
@@ -9,4 +9,8 @@ class AIChatClearCountTests(unittest.TestCase):
   self.assertIn('"已清除 \\(count) 条对话"',R)
   self.assertIn('"没有需要清除的对话"',R)
  def test_old_countless_copy_gone(self):self.assertNotIn('"已清除对话记录"',R)
+ def test_row_shows_a_chevron_and_stays_a_sheet_button(self):
+  self.assertIn('Image(systemName: "chevron.right")', R)
+  self.assertIn('accessibilityIdentifier("npcData.open")', R)
+  self.assertNotIn('NavigationLink', R)
 if __name__=='__main__':unittest.main()
diff --git a/Tests/ContractChecks/test_shop_npc_interruption.py b/Tests/ContractChecks/test_shop_npc_interruption.py
index ff0642171..4eb642c79 100644
--- a/Tests/ContractChecks/test_shop_npc_interruption.py
+++ b/Tests/ContractChecks/test_shop_npc_interruption.py
@@ -36,6 +36,9 @@ class ShopNPCInterruptionContracts(unittest.TestCase):
         fallback = source.split('public extension ShopNPCHTTPTransport {', 1)[1].split('@MainActor public struct', 1)[0]
         self.assertIn('throws { throw ShopNPCFailure.disabled }', fallback)
         self.assertIn('try transport.validateResume(scope: scope, grants: grants)', source)
+        # J-04c / H-16: the unserved POST /api/ai/npc/dialogue is not a client method.
+        self.assertNotIn('/api/ai/npc/dialogue', source)
+        self.assertNotIn('func dialogue(', source)
 
     def test_shipping_resume_validation_is_synchronous_local_and_double_checks_identity(self):
         body = function(read('Core/ShopNPCAuthenticatedTransport.swift'), 'validateResume')
diff --git a/Tests/CoreTests/ClubContextualTests.swift b/Tests/CoreTests/ClubContextualTests.swift
index ffbb890f2..deecaca53 100644
--- a/Tests/CoreTests/ClubContextualTests.swift
+++ b/Tests/CoreTests/ClubContextualTests.swift
@@ -70,12 +70,23 @@ import FoundationNetworking
         XCTAssertNil(draft.chapters[0].nodes[0].templateID)
     }
     func testClubAIQuotaStopsRepeatedGeneration() async throws {
-        let session = aiSession(), generator = ClubAIFakeGenerator(outcome: .rejected("今日AI次数已用完"))
+        let session = aiSession(), generator = ClubAIFakeGenerator(outcome: .rejected(AISafetyPrecheckVerdict.quotaHint))
         let flow = ClubAIDesignFlow(generator: generator, current: { session })
         let input = try ClubAIDesignInput(idea: "Walk")
         await flow.generate(input); XCTAssertEqual(flow.failure, .quota); XCTAssertFalse(flow.canGenerate)
         await flow.generate(input); XCTAssertEqual(generator.calls, 1)
     }
+    func testClubAIRoleGateIsIdentityAndNotTheQuotaPhrase() async throws {
+        XCTAssertFalse(AISafetyPrecheckVerdict.roleGate.contains(AISafetyPrecheckVerdict.quotaHint))
+        let session = aiSession(), generator = ClubAIFakeGenerator(outcome: .rejected(AISafetyPrecheckVerdict.roleGate))
+        let flow = ClubAIDesignFlow(generator: generator, current: { session })
+        await flow.generate(try ClubAIDesignInput(idea: "Walk"))
+        XCTAssertEqual(flow.failure, .identity)
+        let longer = ClubAIFakeGenerator(outcome: .rejected(AISafetyPrecheckVerdict.quotaHint + "，请明天再来"))
+        let other = ClubAIDesignFlow(generator: longer, current: { session })
+        await other.generate(try ClubAIDesignInput(idea: "Walk"))
+        XCTAssertEqual(other.failure, .unavailable)
+    }
     func testClubAICancelOrSessionChangeDropsLateResult() async throws {
         for cancel in [true, false] {
             var session: PublishingSession? = aiSession()
diff --git a/Tests/CoreTests/G6CapabilitySourceTests.swift b/Tests/CoreTests/G6CapabilitySourceTests.swift
index b29c46ccb..aefee4870 100644
--- a/Tests/CoreTests/G6CapabilitySourceTests.swift
+++ b/Tests/CoreTests/G6CapabilitySourceTests.swift
@@ -271,6 +271,25 @@ import FoundationNetworking
         XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [a, a], "nextCursor": NSNull()], before: nil))
     }
 
+    /// Theme-draft instants are UTC: a `T` separator and a trailing `Z`. Offsets and a space separator do not parse.
+    func testThemeDraftInstantsAreUTCWithTAndTrailingZ() {
+        let utc = Date(timeIntervalSince1970: 1_893_456_000)
+        XCTAssertEqual(G6AIThemeDraft.instant("2030-01-01T00:00:00Z"), utc)
+        XCTAssertEqual(G6AIThemeDraft.instant("2030-01-01T00:00:00.250Z"), utc.addingTimeInterval(0.25))
+        for refused in ["2030-01-01T08:00:00+08:00", "2030-01-01T00:00:00+00:00", "2030-01-01 00:00:00Z",
+                        "2030-01-01T00:00:00z", "2030-01-01T00:00:00-00:00Z", "2030-01-01"] {
+            XCTAssertNil(G6AIThemeDraft.instant(refused), refused)
+        }
+        var offset = ["cursor": "9", "prepareKey": "0f8fad5b-d9cb-469f-a165-70867728950e",
+                      "requestId": "td2_" + String(repeating: "a", count: 32), "state": "FAILED",
+                      "reasonCode": NSNull(), "productType": 1, "createdAt": "2030-01-01T08:00:00+08:00",
+                      "executeBefore": "2030-01-01T09:00:00Z", "resultExpiresAt": NSNull()] as [String: Any]
+        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [offset], "nextCursor": NSNull()], before: nil))
+        offset["createdAt"] = "2030-01-01T00:00:00Z"
+        offset["executeBefore"] = "2030-01-01 09:00:00Z"
+        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [offset], "nextCursor": NSNull()], before: nil))
+    }
+
     func testJournalRefusesIllegalUpdates() {
         let journal = G6AIThemeDraftJournal(store: JourneyMemoryRequestStore())
         let start = G6AIThemeDraftRecord(memberId: "9", prepareKey: "0f8fad5b-d9cb-469f-a165-70867728950e", requestId: nil,
diff --git a/Tests/CoreTests/NewFeatureServicesEdgeTests.swift b/Tests/CoreTests/NewFeatureServicesEdgeTests.swift
index 9486d2da3..c857877b9 100644
--- a/Tests/CoreTests/NewFeatureServicesEdgeTests.swift
+++ b/Tests/CoreTests/NewFeatureServicesEdgeTests.swift
@@ -321,34 +321,28 @@ import XCTest
         XCTAssertTrue(drop?.toastMessage(locale: Locale(identifier: "zh-Hans")).contains("双倍积分卡") == true)
     }
 
-    // MARK: - ShopNPCHTTP Dialogue Validation
+    // MARK: - Shop NPC live path (the unserved /api/ai/npc/dialogue method is gone)
 
-    func testShopNPCDialogueRejectsBlankAndRateLimits() async throws {
-        struct RateLimitTransport: ShopNPCHTTPTransport {
+    func testShopNPCTextUsesShopChatAndRateLimits() async throws {
+        final class RateLimitTransport: ShopNPCHTTPTransport {
+            var paths: [String] = []
             func perform(_ request: ShopNPCHTTPRequest) async throws -> ShopNPCHTTPResponse {
-                ShopNPCHTTPResponse(status: 429, body: Data())
+                paths.append(request.path)
+                return ShopNPCHTTPResponse(status: 429, body: Data())
             }
         }
-        let client = ShopNPCHTTPClient(transport: RateLimitTransport())
+        let http = RateLimitTransport()
+        let client = ShopNPCHTTPClient(transport: http)
         let nodeID = try XCTUnwrap(ShopNPCNodeID(20))
         let scope = ShopNPCScope(sessionID: "sess-1", accountID: "1", roleID: "player", accessRevision: 1, nodeID: nodeID)
-
-        do {
-            _ = try await client.dialogue(topicID: 10, activityID: 1, npcID: 40, utterance: "   ", routeActionID: "act-1", scope: scope)
-            XCTFail("Expected invalid")
-        } catch let err as ShopNPCFailure {
-            XCTAssertEqual(err, .invalid)
-        } catch {
-            XCTFail("Unexpected error: \(error)")
-        }
-
         do {
-            _ = try await client.dialogue(topicID: 10, activityID: 1, npcID: 40, utterance: "茶馆主人还在吗？", routeActionID: "act-1", scope: scope)
+            _ = try await client.text("茶馆主人还在吗？", requestID: UUID(), scope: scope)
             XCTFail("Expected rateLimited")
         } catch let err as ShopNPCFailure {
             XCTAssertEqual(err, .rateLimited)
         } catch {
             XCTFail("Unexpected error: \(error)")
         }
+        XCTAssertEqual(http.paths, ["/api/ai/npc/shop-chat"])
     }
 }
```

Untracked file added with this pass, `Tests/ContractChecks/test_k40_ai_npc_guide_creation.py`:

```python
"""K40: AI NPC, guide, and creation source pins. No Swift runtime."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class K40AIContracts(unittest.TestCase):
    def test_quota_skip_is_the_exact_phrase_and_the_role_gate_does_not_contain_it(self):
        source = read("Core/AISafetyPrecheck.swift")
        self.assertIn('public static let quotaHint = "今日AI次数已用完"', source)
        self.assertIn('public static let roleGate = "当前身份暂不支持AI创作"', source)
        self.assertNotIn("今日AI次数已用完", source.split("roleGate", 1)[1].split("\n", 1)[0])
        skipped = source.split("func skipped(message: String?)", 1)[1].split("public var allowsPublish", 1)[0]
        self.assertIn("message == quotaHint", skipped)
        self.assertNotIn(".contains(quotaHint)", skipped)
        self.assertNotIn(".contains(\"今日AI次数已用完\")", source)
        auxiliary = read("Core/PublishingAuxiliaryService.swift")
        self.assertIn("return .rejected(AISafetyPrecheckVerdict.roleGate)", auxiliary)
        self.assertNotIn("当前身份暂不支持AI创作今日AI次数已用完", auxiliary)
        club = read("Core/ClubAIDesignFlow.swift")
        self.assertIn("message == AISafetyPrecheckVerdict.quotaHint", club)
        self.assertNotIn('message.contains("今日AI次数已用完")', club)

    def test_theme_draft_instants_are_utc_with_t_and_trailing_z(self):
        source = read("Core/G6AIThemeDraft.swift")
        body = source.split("public static func instant", 1)[1].split("static func older", 1)[0]
        self.assertIn('text.hasSuffix("Z")', body)
        self.assertIn('text.firstIndex(of: "T")', body)
        self.assertIn('!text.contains("+")', body)
        self.assertIn('.contains("-")', body)
        self.assertIn("TimeZone(secondsFromGMT: 0)", body)

    def test_unserved_dialogue_path_is_not_a_client_method(self):
        http = read("Core/ShopNPCHTTP.swift")
        self.assertNotIn("/api/ai/npc/dialogue", http)
        self.assertNotIn("func dialogue(", http)
        self.assertIn("/api/ai/npc/shop-chat", http)
        self.assertIn("/api/ai/npc/voice-chat", http)

    def test_ai_row_stays_first_in_the_player_create_menu(self):
        menu = read("App/PublishTabRootView.swift")
        sheet = menu.split("private var publishMenu", 1)[1].split("private var creatorMenu", 1)[0]
        self.assertLess(sheet.index("publishRoute = .aiCreation"), sheet.index("choose(.freeExplore)"))
        self.assertLess(sheet.index("choose(.freeExplore)"), sheet.index("choose(.city)"))
        self.assertLess(sheet.index("choose(.city)"), sheet.index("choose(.interaction)"))
        modes = read("App/PublishingModesViews.swift")
        body = modes.split("var body: some View", 1)[1].split("@MainActor struct QuickPublishingView", 1)[0]
        self.assertLess(body.index('accessibilityIdentifier("publishModes.ai")'), body.index('accessibilityIdentifier("publishModes.pro.freeExplore")'))

    def test_play_init_order_and_merchant_ai_stay_gated(self):
        leases = read("App/ReviewedPlayerWriteLeases.swift")
        self.assertIn(
            "publisherReads: true, devices: Self.playDevices, sensors: Self.playSensors,\n"
            "            artworkHosts: Self.playArtworkHosts(apiBase: context.baseURL), shopNPCWrites: true",
            leases,
        )
        approvals = read("App/AICreationReleaseApprovals.swift")
        self.assertIn('case "player":', approvals)
        self.assertIn('case "club":', approvals)
        self.assertNotIn('case "merchant":', approvals)
        self.assertIn("default: return []", approvals)
        session = read("App/AppSession.swift")
        self.assertLessEqual(len(session.splitlines()), 7977)

    def test_touched_ai_sources_add_no_string_localized_literals(self):
        for path in [
            "Core/AISafetyPrecheck.swift",
            "Core/G6AIThemeDraft.swift",
            "Core/ShopNPCHTTP.swift",
            "Core/ClubAIDesignFlow.swift",
            "Core/PublishingAuxiliaryService.swift",
            "App/NPCChatDataReadSettingsEntry.swift",
            "App/AICreationReleaseApprovals.swift",
            "App/AICreationHubView.swift",
        ]:
            self.assertNotIn("String(localized:", read(path), path)


if __name__ == "__main__":
    unittest.main()
```
