"""Literal request( coverage. This does not parse JavaScript."""
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


if __name__ == "__main__":
    unittest.main()
