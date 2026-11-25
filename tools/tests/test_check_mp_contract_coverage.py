"""Literal HTTP-call coverage. This does not parse JavaScript."""
import os
import subprocess
import tempfile
import textwrap
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOL = os.path.join(ROOT, "tools", "check_mp_contract_coverage.py")


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(textwrap.dedent(content).lstrip("\n"))


class ContractCoverageTests(unittest.TestCase):
    def test_literal_row_matches_symbol_and_pin_and_leaves_dynamic_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            mp = os.path.join(tmp, "chengyinhub-xcx")
            core = os.path.join(tmp, "Core")
            tests = os.path.join(tmp, "Tests")
            write(os.path.join(mp, "pages/play/circle/index.js"), """
                function request(url, method, data) {
                  return send({ url, method, data });
                }
                request('/api/circle-theme/session/record', 'POST', { sessionId: 1, offerId: 2, note: '' });
                request('/api/circle-theme/session/' + sessionId + '/card', 'GET', {});
                request(dynamicUrl, 'POST', payload);
            """)
            write(os.path.join(mp, "tests/unit/ignored.test.js"), """
                request('/api/ignored', 'GET', {});
            """)
            write(os.path.join(core, "Play.swift"), """
                public struct PlayExperienceService {
                    public static let recordPath = "api/circle-theme/session/record"
                    public func circleCard() {
                        _ = "api/circle-theme/session/\\(sessionID)/card"
                    }
                }
            """)
            write(os.path.join(tests, "PinTests.swift"), """
                final class PinTests: XCTestCase {
                    func testRecordPinsFields() {
                        XCTAssertEqual(path, "/api/circle-theme/session/record")
                        XCTAssertEqual(method, "POST")
                        XCTAssertEqual(["note", "offerId", "sessionId"], ["note", "offerId", "sessionId"])
                    }
                    func testCardMentionsPathOnly() {
                        XCTAssertEqual(path, "api/circle-theme/session/")
                        XCTAssertTrue(path.hasSuffix("/card"))
                    }
                }
            """)
            result = subprocess.run(
                ["python3", TOOL, "--mp-root", mp, "--core", core, "--tests", tests],
                check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = [line for line in result.stdout.splitlines() if not line.startswith("#") and not line.startswith("MP ")]
            self.assertEqual(lines, [
                "pages/play/circle/index.js:4\tPlayExperienceService.recordPath\tPinTests.testRecordPinsFields",
                "pages/play/circle/index.js:5\tPlayExperienceService.circleCard\tMISSING",
                "pages/play/circle/index.js:6\tMISSING\tMISSING",
            ])
            self.assertIn("total 3 matched 1 missing_endpoint 1 missing_test 2", result.stdout)

    def test_same_file_helper_url_is_used_and_passed_method_is_not_invented(self):
        with tempfile.TemporaryDirectory() as tmp:
            mp = os.path.join(tmp, "xcx")
            write(os.path.join(mp, "utils/roam-presence-privacy.js"), """
                function request(app, method, data) {
                  app.sendRequest({ url: '/api/roam/presence-visibility', method, data });
                }
                request(app, 'GET', { sessionId: '1' });
                request(app, 'POST', { sessionId: '', visible: false, consentVersion: '' });
            """)
            write(os.path.join(tmp, "Core", "Presence.swift"), """
                public enum RoamPresenceVisibilityContract {
                    public static let path = "api/roam/presence-visibility"
                }
            """)
            result = subprocess.run(
                ["python3", TOOL, "--mp-root", mp, "--core", os.path.join(tmp, "Core"),
                 "--tests", os.path.join(tmp, "Tests")],
                check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            body = [line for line in result.stdout.splitlines() if line.startswith("utils/")]
            self.assertEqual(body, [
                "utils/roam-presence-privacy.js:2\tRoamPresenceVisibilityContract.path\tMISSING",
                "utils/roam-presence-privacy.js:4\tRoamPresenceVisibilityContract.path\tMISSING",
                "utils/roam-presence-privacy.js:5\tRoamPresenceVisibilityContract.path\tMISSING",
            ])


    def test_closed_function_does_not_keep_a_later_literal(self):
        with tempfile.TemporaryDirectory() as tmp:
            mp = os.path.join(tmp, "xcx")
            write(os.path.join(mp, "utils/read.js"), """
                request('/api/roam/passport/history', 'GET', {});
                request('/api/capsules/detail', 'GET', { id: 1 });
                request('/api/capsules/list', 'GET', {});
            """)
            write(os.path.join(tmp, "Core", "Routes.swift"), """
                public enum ChinaReviewedRouteCapability {
                    func isOpaqueID() { return true }
                    static let history = "api/roam/passport/history"
                    static let capsuleList = "api/capsules/list", capsuleDetail = "api/capsules/detail"
                }
            """)
            result = subprocess.run(
                ["python3", TOOL, "--mp-root", mp, "--core", os.path.join(tmp, "Core"),
                 "--tests", os.path.join(tmp, "Tests")],
                check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            body = [line for line in result.stdout.splitlines() if line.startswith("utils/")]
            self.assertEqual(body, [
                "utils/read.js:1\tChinaReviewedRouteCapability.history\tMISSING",
                "utils/read.js:2\tChinaReviewedRouteCapability.capsuleDetail\tMISSING",
                "utils/read.js:3\tChinaReviewedRouteCapability.capsuleList\tMISSING",
            ])

    def test_new_callees_and_non_literal_arguments_keep_only_literal_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            mp = os.path.join(tmp, "xcx")
            write(os.path.join(mp, "pages/scan.js"), r"""
                function sendRequest(options) { return options; }
                function req(url, method, data) { return url; }
                function uploadFile(file) { return file; }
                function request(url, method, data) { return url; }
                subscribe.request(['coopStatus']);
                require('./subscribe.js').request(['refund']);
                sendRequest({ url: '/api/literal', method: 'POST', data: { note: 'n' } });
                sendRequest({
                  url: '/api/shorthand',
                  method: 'POST',
                  data: { note: 'n' },
                  success(res) { return res; }
                });
                sendRequest(Object.assign({}, opts, { url: '/api/assigned', method: 'POST', data: { k: 1 } }));
                sendRequest(Object.assign({ url: '/api/maybe' }, extra));
                sendRequest(payload);
                sendRequest({ url, method, data });
                sendRequest({ url: '/api/hidden-by-spread', method: 'GET', ...extra });
                sendRequest({ ...extra, url: '/api/after-spread', method: 'PUT', data: { z: 1 } });
                req('/api/req-path', 'GET', { b: 1 });
                req('/api/req-no-data', 'GET');
                wx.request({ url: '/api/wx', method: 'GET', data: {} });
                wx.uploadFile({ url: '/api/upload', name: 'file' });
                request('/api/epoch', 'GET', { id: 1 }, ++readEpoch);
                const precise = raw.replace(/"(?:\\.|[^"\\])*"/g, "x");
                sendRequest({ url: '/api/after-regex', method: 'GET', data: {} });
            """)
            write(os.path.join(tmp, "Core", "Routes.swift"), """
                public enum CovRoutes {
                    public static let literal = "api/literal"
                    public static let shorthand = "api/shorthand"
                    public static let assigned = "api/assigned"
                    public static let afterSpread = "api/after-spread"
                    public static let reqPath = "api/req-path"
                    public static let reqNoData = "api/req-no-data"
                    public static let wx = "api/wx"
                    public static let upload = "api/upload"
                    public static let epoch = "api/epoch"
                    public static let afterRegex = "api/after-regex"
                }
            """)
            result = subprocess.run(
                ["python3", TOOL, "--mp-root", mp, "--core", os.path.join(tmp, "Core"),
                 "--tests", os.path.join(tmp, "Tests")],
                check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            body = [line for line in result.stdout.splitlines() if line.startswith("pages/")]
            self.assertEqual(body, [
                "pages/scan.js:7\tCovRoutes.literal\tMISSING",
                "pages/scan.js:8\tCovRoutes.shorthand\tMISSING",
                "pages/scan.js:14\tCovRoutes.assigned\tMISSING",
                "pages/scan.js:15\tMISSING\tMISSING",
                "pages/scan.js:16\tMISSING\tMISSING",
                "pages/scan.js:17\tINDIRECT\tMISSING",
                "pages/scan.js:18\tMISSING\tMISSING",
                "pages/scan.js:19\tCovRoutes.afterSpread\tMISSING",
                "pages/scan.js:20\tCovRoutes.reqPath\tMISSING",
                "pages/scan.js:21\tCovRoutes.reqNoData\tMISSING",
                "pages/scan.js:22\tCovRoutes.wx\tMISSING",
                "pages/scan.js:23\tCovRoutes.upload\tMISSING",
                "pages/scan.js:24\tCovRoutes.epoch\tMISSING",
                "pages/scan.js:26\tCovRoutes.afterRegex\tMISSING",
            ])

    def test_json_body_stringify_and_forwarded_data_pin_without_parsed_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            mp = os.path.join(tmp, "xcx")
            write(os.path.join(mp, "pages/body.js"), """
                function request(url, method, data) { return url; }
                subscribe.request(['coopStatus']);
                require("./subscribe.js").request(['refund']);
                request('/api/json-body', 'POST', jsonBody({ note: 'n' }));
                request('/api/stringified', 'PUT', JSON.stringify({ k: 1 }));
                request('/api/forwarded', 'POST', data);
                request('/api/literal-open', 'POST', { note: 'n', id: 1 });
                request('/api/no-data', 'DELETE');
                request('/api/method-gap', 'PATCH');
                sendRequest({ url: '/api/assign-open', method: 'POST', data: Object.assign({}, payload, { z: 1 }) });
                sendRequest({ url: '/api/assign-lit', method: 'POST', data: Object.assign({}, { a: 1 }, { b: 2 }) });
                sendRequest({ url: '/api/spread', method: 'GET', data: { ...extra, z: 1 } });
                request(url, 'POST', data);
            """)
            write(os.path.join(tmp, "Core", "Routes.swift"), """
                public enum BodyRoutes {
                    public static let jsonBody = "api/json-body"
                    public static let stringified = "api/stringified"
                    public static let forwarded = "api/forwarded"
                    public static let literalOpen = "api/literal-open"
                    public static let noData = "api/no-data"
                    public static let methodGap = "api/method-gap"
                    public static let assignOpen = "api/assign-open"
                    public static let assignLit = "api/assign-lit"
                    public static let spread = "api/spread"
                }
            """)
            write(os.path.join(tmp, "Tests", "BodyPinTests.swift"), """
                final class BodyPinTests: XCTestCase {
                    func testJsonBodyPinsPathAndMethod() {
                        XCTAssertEqual(path, "/api/json-body")
                        XCTAssertEqual(method, "POST")
                    }
                    func testStringifiedPinsPathAndMethod() {
                        XCTAssertEqual(path, "api/stringified")
                        XCTAssertEqual(method, "PUT")
                    }
                    func testForwardedDataPinsPathAndMethod() {
                        XCTAssertEqual(path, "/api/forwarded")
                        XCTAssertEqual(method, "POST")
                    }
                    func testLiteralOpenMissesId() {
                        XCTAssertEqual(path, "/api/literal-open")
                        XCTAssertEqual(method, "POST")
                        XCTAssertEqual(kept, "note")
                    }
                    func testNoDataPinsPathAndMethod() {
                        XCTAssertEqual(path, "/api/no-data")
                        XCTAssertEqual(method, "DELETE")
                    }
                    func testMethodGapHasPathOnly() {
                        XCTAssertEqual(path, "/api/method-gap")
                    }
                    func testAssignOpenPinsPathAndMethod() {
                        XCTAssertEqual(path, "/api/assign-open")
                        XCTAssertEqual(method, "POST")
                    }
                    func testAssignLitMissesB() {
                        XCTAssertEqual(path, "/api/assign-lit")
                        XCTAssertEqual(method, "POST")
                        XCTAssertEqual(kept, "a")
                    }
                    func testSpreadPinsPathAndMethod() {
                        XCTAssertEqual(path, "/api/spread")
                        XCTAssertEqual(method, "GET")
                    }
                }
            """)
            result = subprocess.run(
                ["python3", TOOL, "--mp-root", mp, "--core", os.path.join(tmp, "Core"),
                 "--tests", os.path.join(tmp, "Tests")],
                check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            body = [line for line in result.stdout.splitlines() if line.startswith("pages/")]
            self.assertEqual(body, [
                "pages/body.js:4\tBodyRoutes.jsonBody\tBodyPinTests.testJsonBodyPinsPathAndMethod",
                "pages/body.js:5\tBodyRoutes.stringified\tBodyPinTests.testStringifiedPinsPathAndMethod",
                "pages/body.js:6\tBodyRoutes.forwarded\tBodyPinTests.testForwardedDataPinsPathAndMethod",
                "pages/body.js:7\tBodyRoutes.literalOpen\tMISSING",
                "pages/body.js:8\tBodyRoutes.noData\tBodyPinTests.testNoDataPinsPathAndMethod",
                "pages/body.js:9\tBodyRoutes.methodGap\tMISSING",
                "pages/body.js:10\tBodyRoutes.assignOpen\tBodyPinTests.testAssignOpenPinsPathAndMethod",
                "pages/body.js:11\tBodyRoutes.assignLit\tMISSING",
                "pages/body.js:12\tBodyRoutes.spread\tBodyPinTests.testSpreadPinsPathAndMethod",
                "pages/body.js:13\tINDIRECT\tMISSING",
            ])

    def test_indirect_forwarders_and_core_ternaries_leave_the_other_shapes_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            mp = os.path.join(tmp, "xcx")
            write(os.path.join(mp, "pages/indirect.js"), """
                sendRequest({ url, method: 'POST', data });
                sendRequest({ url: url, method: 'GET' });
                sendRequest(requestJson);
                sendRequest(_request);
                request(options.url, 'POST', data);
                sendRequest({ url: config.url, method: 'POST' });
                sendRequest({ url, method, data, hideLoading: true, ...(opts || {}) });
                sendRequest(Object.assign({}, options, { url }));
                sendRequest({ url: kind === 'payer' ? '/api/fe/payer' : '/api/fe/merchant', method: 'GET' });
                sendRequest({ url: club ? '/api/coop/summary' : (finance ? '/api/coop/finance' : '/api/coop/mybiz'), method: 'POST' });
                sendRequest(opts);
                sendRequest(options);
                sendRequest(request);
                sendRequest(Object.assign({}, options, { hideLoading: true }));
                sendRequest(Object.assign({}, { url }, options));
                sendRequest(Object.assign({ url: '/api/maybe' }, extra));
                sendRequest({ url: siteBaseUrl + '/api/login/code', method: 'POST' });
                sendRequest({ url: (kind === 'payer' ? '/api/fe/payer' : '/api/fe/merchant') + '/export', method: 'GET' });
                request('/api/play/theme/state', 'GET', { topicId: old.topicId, ...(old.activityId ? { activityId: old.activityId } : {}) });
                sendRequest({ url: kept ? '/api/fe/payer' : otherPath, method: 'GET' });
                sendRequest({ url: mode === 'a' ? '/api/fe/payer' : '/api/not-in-core', method: 'GET' });
                sendRequest({ url: dynamicUrl, method: 'POST' });
                sendRequest({ ...(opts || {}), success });
            """)
            write(os.path.join(tmp, "Core", "Routes.swift"), """
                public enum IndirectRoutes {
                    public static let payer = "api/fe/payer"
                    public static let merchant = "api/fe/merchant"
                    public static let summary = "api/coop/summary"
                    public static let finance = "api/coop/finance"
                    public static let mybiz = "api/coop/mybiz"
                    public static let state = "api/play/theme/state"
                    public static let login = "api/login/code"
                }
            """)
            result = subprocess.run(
                ["python3", TOOL, "--mp-root", mp, "--core", os.path.join(tmp, "Core"),
                 "--tests", os.path.join(tmp, "Tests")],
                check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            body = [line for line in result.stdout.splitlines() if line.startswith("pages/")]
            self.assertEqual(body, [
                "pages/indirect.js:1\tINDIRECT\tMISSING",
                "pages/indirect.js:2\tINDIRECT\tMISSING",
                "pages/indirect.js:3\tINDIRECT\tMISSING",
                "pages/indirect.js:4\tINDIRECT\tMISSING",
                "pages/indirect.js:5\tINDIRECT\tMISSING",
                "pages/indirect.js:6\tINDIRECT\tMISSING",
                "pages/indirect.js:7\tINDIRECT\tMISSING",
                "pages/indirect.js:8\tINDIRECT\tMISSING",
                "pages/indirect.js:9\tINDIRECT\tMISSING",
                "pages/indirect.js:10\tINDIRECT\tMISSING",
                "pages/indirect.js:11\tMISSING\tMISSING",
                "pages/indirect.js:12\tMISSING\tMISSING",
                "pages/indirect.js:13\tMISSING\tMISSING",
                "pages/indirect.js:14\tMISSING\tMISSING",
                "pages/indirect.js:15\tMISSING\tMISSING",
                "pages/indirect.js:16\tMISSING\tMISSING",
                "pages/indirect.js:17\tMISSING\tMISSING",
                "pages/indirect.js:18\tMISSING\tMISSING",
                "pages/indirect.js:19\tMISSING\tMISSING",
                "pages/indirect.js:20\tMISSING\tMISSING",
                "pages/indirect.js:21\tMISSING\tMISSING",
                "pages/indirect.js:22\tMISSING\tMISSING",
                "pages/indirect.js:23\tMISSING\tMISSING",
            ])
            self.assertIn(
                "total 23 matched 0 missing_endpoint 13 missing_test 23 matched_indirect 10",
                result.stdout)

    def test_indirect_allowlist_is_file_line_and_a_short_reason(self):
        path = os.path.join(ROOT, "tools", "mp_contract_indirect_allowlist.txt")
        rows = []
        with open(path, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                where, reason = line.split("\t")
                self.assertRegex(where, r"^.+\.js:\d+$")
                if reason.startswith("forwards "):
                    forwarded = reason[len("forwards "):]
                    self.assertTrue(
                        forwarded in ("url", "requestJson", "_request") or forwarded.endswith(".url"),
                        reason)
                else:
                    self.assertTrue(reason.startswith("ternary api/"), reason)
                    self.assertNotIn("+", reason)
                    self.assertGreaterEqual(reason.count("api/"), 2)
                rows.append(where)
        self.assertEqual(len(rows), len(set(rows)))
        self.assertEqual(len(rows), 66)
        previous = ("", 0)
        for where in rows:
            path, line = where.rsplit(":", 1)
            current = (path, int(line))
            self.assertLess(previous, current)
            previous = current


if __name__ == "__main__":
    unittest.main()
