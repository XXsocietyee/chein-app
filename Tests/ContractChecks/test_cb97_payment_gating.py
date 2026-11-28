"""Release money-write switches stay off, and a write is not admitted while its switch is off.

Source contract only. This VM has no Swift compiler. The test does not turn a switch on
and does not choose a payment route.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
GATE = "Core/ChinaReviewedRouteCapability.swift"
SWITCHES = {
    "payment": "paymentEnabled",
    "payout": "payoutEnabled",
    "withdrawal": "withdrawalEnabled",
    "virtualGoods": "virtualGoodsEnabled",
}
# Minimum write paths. A path removed from kind(for:) makes a Release write ungated.
REQUIRED = {
    "payment": {
        "/api/registration/pay",
        "/api/registration/pay/app",
        "/api/pay/create",
    },
    "payout": {"/api/club/settlement/withdraw"},
    "withdrawal": {"/api/withdrawal/create", "/api/asset/withdraw", "/api/wallet/withdraw"},
    "virtualGoods": {
        "/api/cart/cart/add",
        "/api/cart/add",
        "/api/cart/update",
        "/api/cart/delete",
        "/api/cart/order/settlement",
        "/api/mod-commerce/orders",
        "/api/mod-commerce/native-transactions/restore",
    },
}
# Reads and non-money exits. Classifying one of these as a money write would hide a live route.
NOT_MONEY = [
    "/api/withdrawal/list",
    "/api/wallet/stages",
    "/api/club/settlement/summary",
    "/api/cart/list",
    "/api/cart/settlement",
    "/api/product/list",
    "/api/coop/offer/withdraw",
    "/api/team/withdraw",
    "/api/merchant/chapter-application/withdraw",
]


def read(path):
    return (ROOT / path).read_text()


def slice_between(text, start, end):
    i = text.index(start)
    j = text.index(end, i + len(start))
    return text[i:j]


def func_body(text, name):
    marker = f"func {name}"
    start = text.index(marker)
    rest = text[start + 1 :]
    match = re.search(r"\n    func ", rest)
    stop = start + 1 + (match.start() if match else len(rest))
    return text[start:stop]


def functions(source):
    parts = re.split(
        r"\n(?=[ \t]*(?:public |private |internal |fileprivate |open |override |static )*"
        r"(?:func |init\())",
        source,
    )
    return parts


def normalize(path):
    raw = path.split("?", 1)[0].split("#", 1)[0]
    if not raw.startswith("/"):
        raw = "/" + raw
    while "//" in raw:
        raw = raw.replace("//", "/")
    parts = []
    for segment in raw.split("/"):
        if segment and segment.isdigit():
            parts.append("{}")
        elif len(segment) >= 2 and segment.startswith("{") and segment.endswith("}"):
            parts.append("{}")
        elif 32 <= len(segment) <= 36 and all(c == "-" or c in "0123456789abcdefABCDEF" for c in segment):
            parts.append("{}")
        else:
            parts.append(segment)
    joined = "/".join(parts)
    if len(joined) > 1 and joined.endswith("/"):
        joined = joined[:-1]
    return joined


class ReleasePaymentGatingTests(unittest.TestCase):
    def setUp(self):
        self.gate = read(GATE)
        self.kind_src = slice_between(self.gate, "public static func kind(for rawPath: String)", "public struct ChinaReviewedProductionTransport")
        self.exact = {}
        for match in re.finditer(
            r"case ((?:\"/api/[^\"]+\"(?:,\s*)?)+):\s*return \.(\w+)",
            self.kind_src,
        ):
            for path in re.findall(r"\"(/api/[^\"]+)\"", match.group(1)):
                self.exact[path] = match.group(2)
        self.switches = {kind: False for kind in SWITCHES}

    def kind(self, path):
        key = normalize(path)
        if key in self.exact:
            return self.exact[key]
        if 'key.hasPrefix("/api/fund/preflight")' in self.kind_src and key.startswith("/api/fund/preflight"):
            return "withdrawal"
        if 'key.hasPrefix("/api/mod-commerce/")' in self.kind_src and key.startswith("/api/mod-commerce/"):
            if (
                key.endswith("/payment")
                or key.endswith("/native-dispatch")
                or key.endswith("/native-transaction")
                or key in {"/api/mod-commerce/native-transactions/restore", "/api/mod-commerce/orders"}
            ):
                return "virtualGoods"
        return None

    def blocks(self, path, switches=None):
        switches = self.switches if switches is None else switches
        found = self.kind(path)
        if found is None:
            return False
        return not switches[found]

    def forced_off(self, key):
        if key == "/api/login":
            return "password-login"
        if (
            key == "/api/withdrawal/create"
            or key.startswith("/api/fund/preflight")
            or key in {"/api/asset/withdraw", "/api/club/settlement/withdraw", "/api/wallet/withdraw"}
        ):
            return "bank-withdrawal"
        if (
            key == "/api/cart"
            or key.startswith("/api/cart/")
            or key in {"/api/product/info", "/api/product/list", "/api/registration/pay", "/api/registration/pay/app", "/api/pay/create"}
        ):
            return "virtual-goods"
        return None

    def admits(self, path, wired, switches=None):
        """Same order as admitsChinaProductionCall: own switch, then forcedOff, then the catalog."""
        if self.blocks(path, switches):
            return False
        key = normalize(path)
        if self.forced_off(key):
            return False
        return key in wired

    def test_each_release_switch_is_its_own_constant_and_off(self):
        body = slice_between(self.gate, "public enum ReleaseMoneyWriteSwitch", "public static func isEnabled")
        for kind, name in SWITCHES.items():
            self.assertIn(f"public static var {name}: Bool {{ testDerivation?(.{kind}) ?? false }}", body, kind)
            self.assertNotIn(f"public static let {name} = true", self.gate, kind)
        enabled = slice_between(self.gate, "public static func isEnabled", "public static func blocks")
        for kind, name in SWITCHES.items():
            self.assertIn(f"case .{kind}: return {name}", enabled)
        blocks = slice_between(self.gate, "public static func blocks", "public static func kind")
        self.assertIn("return !isEnabled(kind)", blocks)
        self.assertNotIn("return true", blocks)

    def test_required_writes_stay_classified_on_their_own_switch(self):
        for kind, paths in REQUIRED.items():
            for path in paths:
                self.assertEqual(self.kind(path), kind, path)
        for path in NOT_MONEY:
            self.assertIsNone(self.kind(path), path)
        self.assertEqual(self.kind("/api/registration/pay/other"), None)
        self.assertEqual(self.kind("/api/fund/preflight/71/confirm"), "withdrawal")
        self.assertEqual(self.kind("/api/mod-commerce/orders/offer-1/payment"), "virtualGoods")
        self.assertIsNone(self.kind("/api/mod-commerce/offers"))

    def test_admit_asks_the_switch_before_the_wired_catalog(self):
        admit = func_body(self.gate, "admitsChinaProductionCall(_ path: String)")
        self.assertLess(admit.index("ReleaseMoneyWriteSwitch.blocks"), admit.index("wiredPatterns.contains"))
        forced = func_body(self.gate, "forcedOff(")
        for fragment in (
            'key == "/api/login"',
            'key == "/api/withdrawal/create"',
            'key.hasPrefix("/api/fund/preflight")',
            'key == "/api/asset/withdraw"',
            'key == "/api/club/settlement/withdraw"',
            'key == "/api/wallet/withdraw"',
            'key.hasPrefix("/api/cart/")',
            'key == "/api/registration/pay"',
            'key == "/api/registration/pay/app"',
            'key == "/api/pay/create"',
        ):
            self.assertIn(fragment, forced)
        wired_blob = slice_between(self.gate, "private static let wiredPatterns", "public enum ReleaseMoneyWriteKind")
        wired = set(re.findall(r"\"(/api/[^\"]+)\"", wired_blob))
        samples = [path for paths in REQUIRED.values() for path in paths]
        samples += [
            "/api/fund/preflight/bank-withdrawal",
            "/api/fund/preflight/71/confirm",
            "/api/mod-commerce/orders/offer-1/payment",
            "/api/mod-commerce/orders/offer-1/native-dispatch",
            "/api/mod-commerce/orders/offer-1/native-transaction",
        ]
        poisoned = set(wired)
        poisoned.update(normalize(path) for path in samples)
        for path in samples:
            self.assertTrue(self.blocks(path), path)
            self.assertFalse(self.admits(path, wired), path)
            # A later catalog edit must not make the write reachable while its switch is off.
            self.assertFalse(self.admits(path, poisoned), path)
        self.assertTrue(self.admits("/api/withdrawal/list", wired))
        self.assertTrue(self.admits("/api/coop/offer/withdraw", wired))
        self.assertFalse(self.admits("/api/cart/list", wired))

    def test_one_switch_does_not_open_another_kind(self):
        samples = {
            "payment": ["/api/registration/pay", "/api/registration/pay/app", "/api/pay/create"],
            "payout": ["/api/club/settlement/withdraw"],
            "withdrawal": ["/api/withdrawal/create", "/api/asset/withdraw", "/api/wallet/withdraw", "/api/fund/preflight/9/confirm"],
            "virtualGoods": ["/api/cart/order/settlement", "/api/mod-commerce/orders/offer-1/payment"],
        }
        for opened in SWITCHES:
            switches = {kind: kind == opened for kind in SWITCHES}
            for kind, paths in samples.items():
                for path in paths:
                    if kind == opened:
                        self.assertFalse(self.blocks(path, switches), path)
                    else:
                        self.assertTrue(self.blocks(path, switches), path)
        for path in NOT_MONEY:
            self.assertFalse(self.blocks(path), path)

    def test_release_call_sites_check_the_matching_switch(self):
        session = read("App/AppSession.swift")
        flow = func_body(session, "topicSelfPlayFlow(")
        self.assertLess(flow.index("ReleaseMoneyWriteSwitch.paymentEnabled"), flow.index("factory.configuration.selfPlayPayment"))
        self.assertIn("runtimeDependencies.selfPlayPayment ?? nativeWeChatPaymentAdapter", flow)
        allowed = func_body(session, "nativeWeChatPaymentAdapter") if "func nativeWeChatPaymentAdapter" in session else session
        # The adapter is a property. The closure is the gate.
        closure = slice_between(session, "allowed: { [weak self] in", "context: { [weak self] in self?.currentRuntimeDependencyContext }")
        self.assertIn("ReleaseMoneyWriteSwitch.paymentEnabled", closure)
        self.assertLess(closure.index("ReleaseMoneyWriteSwitch.paymentEnabled"), closure.index("selfPlayPayment"))
        dispatcher = func_body(session, "makeOrderLifecycleDispatcher(")
        self.assertLess(
            dispatcher.index("ReleaseMoneyWriteSwitch.paymentEnabled"),
            dispatcher.index("runtimeDependencies.selfPlayPayment ?? nativeWeChatPaymentAdapter"),
        )
        bank = func_body(session, "makeBankWithdrawalContext(")
        self.assertLess(bank.index("ReleaseMoneyWriteSwitch.withdrawalEnabled"), bank.index("enableReviewedWrites: true"))
        self.assertIn("factory.permits(.bankPrepare)", bank)
        self.assertIn("factory.permits(.bankConsentRead)", bank)
        workshop = func_body(session, "makeWorkshopCommerceController(")
        self.assertIn("ReleaseMoneyWriteSwitch.virtualGoodsEnabled && !readOnly", workshop)
        # sessionDependencies moved to the player-write lease file; the money switches stay closed there.
        deps = func_body(read("App/ReviewedPlayerWriteLeases.swift"), "sessionDependencies(")
        self.assertIn("externalCheckoutApproved: false", deps)
        # Gap #9 (1128 plan, fix/1128b-team-reg): device payment is approved in Release; the WeChat SDK path keeps its
        # own build flag and the pay route stays behind ReleaseMoneyWriteSwitch in the firewall. External checkout stays closed.
        self.assertIn("devicePaymentApproved: true", deps)
        self.assertIn("weChatPaymentConfiguration: WeChatPaymentBuildSettings.current", deps)
        self.assertNotIn("bankCreate", deps)
        self.assertNotIn("bankPrepare", deps)
        self.assertNotIn("topicSelfPlayPay", deps)
        self.assertNotIn("selfPlayPayment: true", deps)
        service = read("Core/WorkshopCommerceService.swift")
        send = func_body(service, "send<")
        self.assertLess(send.index("ReleaseMoneyWriteSwitch.blocks"), send.index("session.data"))
        self.assertIn("public static let paymentEnabled = false", read("Core/CommerceOrderReadback.swift"))
        self.assertIn("public var paymentAndCashEnabled: Bool { false }", read("Core/MerchantAICommerceGates.swift"))
        self.assertIn("selfPlayPayment: Bool = false", read("Core/BusinessRuntimeConfiguration.swift"))
        self.assertIn("selfPlayExternalCheckoutApproved: Bool = false", read("Core/BusinessRuntimeConfiguration.swift"))
        self.assertIn("enableReviewedWrites: Bool = false", read("Core/BankWithdrawalAdapter.swift"))
        self.assertIn("enableReviewedWrites: Bool = false", read("Core/WalletCommerceSafety.swift"))
        self.assertNotIn("WalletCommerceDormantAdapter(", session)
        self.assertIn("public var isProductionDispatchEnabled: Bool { false }", read("Core/OrderLifecycleDormantAdapter.swift"))

    def test_a_sending_function_cannot_name_a_write_without_its_switch(self):
        offenders = []
        for folder in ("App", "Core"):
            for path in (ROOT / folder).rglob("*.swift"):
                if path.name == "ChinaReviewedRouteCapability.swift":
                    continue
                for chunk in functions(path.read_text()):
                    literals = re.findall(r"\"(api/[^\"\\]+)\"", chunk)
                    kinds = {self.kind(literal) for literal in literals}
                    kinds.discard(None)
                    if not kinds:
                        continue
                    sends = "transport.send" in chunk or "session.data" in chunk
                    if sends and "ReleaseMoneyWriteSwitch" not in chunk:
                        offenders.append(f"{path.relative_to(ROOT)}:{sorted(kinds)}")
        self.assertEqual(offenders, [])

    def test_payout_write_has_no_sender_outside_the_switch(self):
        found = []
        for folder in ("App", "Core"):
            for path in (ROOT / folder).rglob("*.swift"):
                if "api/club/settlement/withdraw" in path.read_text():
                    found.append(str(path.relative_to(ROOT)))
        self.assertEqual(found, [GATE])


if __name__ == "__main__":
    unittest.main()
