import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text()


class AddressListPageReadyContract(unittest.TestCase):
    def test_model_keeps_unknown_counts_as_em_dash(self):
        model = read("Core/ProfileContracts.swift")
        service = read("Core/ProfileService.swift")
        self.assertIn("case loading, empty, error, unknown, ready", model)
        self.assertIn('public static let unknownMark = "—"', model)
        self.assertNotIn("rows.count", model[model.index("struct ProfileParticipantListPage"):])
        self.assertNotIn("cards.count", model)
        self.assertIn("participantListFacts", service)
        self.assertEqual(service.count('"api/user/address/list"'), 2)
        self.assertIn("return result.rows", service)
        for flag in ("showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertNotIn(flag + " = true", model)
            self.assertNotIn(flag + "=true", model)

    def test_list_card_does_not_add_contact_fields(self):
        model = read("Core/ProfileContracts.swift")
        card = model.split("struct ProfileParticipantListCard", 1)[1].split("struct ProfileParticipantListPage", 1)[0]
        for banned in ("email", "areaCode", "province", "detailAddress"):
            self.assertNotIn(banned, card)
        self.assertIn("mobilePhone", card)
        self.assertIn("fullName", card)

    def test_note_lists_missing_keys_and_tests_cover_states(self):
        note = read("docs/release/page-ready/pages-address-address.md")
        self.assertIn("pages/address/address", note)
        self.assertIn("profile.participants.refreshing", note)
        self.assertIn("participant.list.deleteTitle", note)
        self.assertIn("—", note)
        tests = read("Tests/CoreTests/ParticipantAddressListPageTests.swift")
        self.assertIn("testMissingAndNullTotalsStayEmDashWhileLiteralZeroStaysZero", tests)
        self.assertIn("testOutcomeUnknownClearsTheCountToAnEmDash", tests)
        self.assertNotIn("xcodebuild", tests)


if __name__ == "__main__":
    unittest.main()
