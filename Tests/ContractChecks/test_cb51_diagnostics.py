"""CB51 flag and privacy contracts. No Swift toolchain and no device trace."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLAG = "QUESTIFY_CB51_DIAGNOSTICS"
SECRET = "secret-token-sample account-id-sample 31.230416,121.473701"
SAMPLES = ("secret-token-sample", "account-id-sample", "31.230416", "121.473701")
SIGNPOSTS = ("cb51.mapFrame", "cb51.listScroll", "cb51.imageDecode", "cb51.metricSummary")
METRICS = ("crashDiagnostic", "hangDiagnostic", "cpuExceptionDiagnostic", "diskWriteExceptionDiagnostic")


def is_enabled(environment):
    return environment.get(FLAG) == "1"


def record(environment, calls):
    """Same rules as CB51LocalDiagnostics: unlabeled secrets are dropped."""
    enabled = is_enabled(environment)
    records = []
    if not enabled:
        return enabled, records, ""
    for kind, name, count, _secret in calls:
        if kind == "measure":
            records.append((name, 1))
        elif kind == "metric" and count >= 0:
            records.append((name, count))
    rendered = "\n".join(f"{name} {count}" for name, count in records)
    return enabled, records, rendered


class CB51DiagnosticsContracts(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_flag_off_records_no_secrets(self):
        for environment in ({}, {FLAG: ""}, {FLAG: "0"}, {FLAG: "true"}, {FLAG: "yes"}, {FLAG: "1 "}):
            enabled, records, rendered = record(environment, [
                ("measure", "cb51.mapFrame", 1, SECRET),
                ("metric", "crashDiagnostic", 2, SECRET),
            ])
            self.assertFalse(enabled)
            self.assertEqual(records, [])
            self.assertEqual(rendered, "")
            for sample in SAMPLES:
                self.assertNotIn(sample, rendered)

    def test_flag_on_keeps_name_and_count_only(self):
        enabled, records, rendered = record({FLAG: "1"}, [
            ("measure", "cb51.listScroll", 1, SECRET),
            ("metric", "cpuExceptionDiagnostic", 3, SECRET),
            ("metric", "diskWriteExceptionDiagnostic", -1, SECRET),
        ])
        self.assertTrue(enabled)
        self.assertEqual(records, [("cb51.listScroll", 1), ("cpuExceptionDiagnostic", 3)])
        self.assertEqual(rendered, "cb51.listScroll 1\ncpuExceptionDiagnostic 3")
        for sample in SAMPLES:
            self.assertNotIn(sample, rendered)

    def test_swift_recorder_matches_the_flag_and_drops_the_secret(self):
        source = self.read("Core/CB51LocalDiagnostics.swift")
        self.assertIn('public static let debugFlag = "QUESTIFY_CB51_DIAGNOSTICS"', source)
        self.assertIn('environment[debugFlag] == "1"', source)
        self.assertIn("signposter = enabled ? OSSignposter(subsystem: Self.subsystem, category: .pointsOfInterest) : nil", source)
        self.assertIn("public mutating func measure(_ point: CB51Signpost, _: String = \"\")", source)
        self.assertIn("public mutating func recordMetric(_ category: MetricKitDiagnosticCategory, count: Int, _: String = \"\")", source)
        self.assertIn("guard enabled, let signposter else { return }", source)
        self.assertIn("guard enabled, count >= 0 else { return }", source)
        self.assertIn("signposter.beginInterval(point.signpostName)", source)
        self.assertIn("signposter.endInterval(point.signpostName, state)", source)
        self.assertIn('records.append(CB51DiagnosticRecord(name: point.rawValue, count: 1))', source)
        self.assertIn("records.append(CB51DiagnosticRecord(name: category.rawValue, count: count))", source)
        self.assertIn('public static let recordedFields = ["name", "count"]', source)
        self.assertNotIn("beginInterval(point.signpostName,", source)
        self.assertNotIn("OSLogMessage", source)
        self.assertNotIn("import MetricKit", source)
        self.assertNotIn("MXMetricManager", source)
        self.assertNotIn("CLLocation", source)
        self.assertNotIn("startUpdatingLocation", source)
        self.assertNotIn("requestAlwaysAuthorization", source)
        self.assertNotIn("UIBackgroundModes", source)
        self.assertNotIn("allowsBackgroundLocationUpdates", source)
        for sample in SAMPLES:
            self.assertNotIn(sample, source)
        for name in SIGNPOSTS:
            self.assertEqual(source.count(f'"{name}"'), 2)

    def test_swift_test_asserts_the_samples_are_absent(self):
        source = self.read("Tests/CoreTests/CB51LocalDiagnosticsTests.swift")
        self.assertIn(SECRET, source)
        self.assertIn('XCTAssertFalse(diagnostics.rendered().contains("secret-token-sample"))', source)
        self.assertIn('XCTAssertFalse(rendered.contains("secret-token-sample"))', source)
        self.assertIn('XCTAssertFalse(rendered.contains("account-id-sample"))', source)
        self.assertIn('XCTAssertFalse(rendered.contains("31.230416"))', source)
        self.assertIn('XCTAssertFalse(rendered.contains("121.473701"))', source)

    def test_version_background_location_and_packages_stay_put(self):
        base = self.read("Config/Base.xcconfig")
        self.assertIn("MARKETING_VERSION = 1.0.0", base)
        self.assertIn("CURRENT_PROJECT_VERSION = 2", base)
        self.assertNotIn(FLAG, base)
        info = self.read("Config/Info.plist")
        entitlements = self.read("Config/Questify.entitlements")
        # OWN-D-07: Info.plist declares the session-scoped location background mode (and P-083 story audio).
        # P-083: plus the audio mode for story narration on the Lock Screen.
        self.assertIn("<key>UIBackgroundModes</key><array><string>audio</string><string>location</string></array>", info)
        for text in (entitlements, base):
            self.assertNotIn("UIBackgroundModes", text)
        for text in (info, entitlements, base):
            self.assertNotIn("NSLocationAlwaysUsageDescription", text)
            self.assertNotIn("NSLocationAlwaysAndWhenInUseUsageDescription", text)
        package = self.read("Package.swift")
        self.assertNotIn("url:", package.lower())
        for vendor in ("firebase", "sentry", "bugsnag", "crashlytics", "datadog", "amplitude"):
            self.assertNotIn(vendor, package.lower())
        self.assertEqual(
            self.read("Core/CrashResilienceAndMetricKitDiagnosticsAudit.swift").count("case "),
            4,
        )
        for name in METRICS:
            self.assertIn(f"case {name}", self.read("Core/CrashResilienceAndMetricKitDiagnosticsAudit.swift"))


if __name__ == "__main__":
    unittest.main()
