import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class K40HomeDiscovery(unittest.TestCase):
    def test_every_menu_city_has_an_on_device_centre_and_locate_never_sends_the_coordinate(self):
        host = (ROOT / "App/SessionHomeFeedView.swift").read_text()
        menu = (ROOT / "App/HomeSearchTabParityViews.swift").read_text()
        start = menu.index("static let manualOptions")
        end = menu.index("static let english", start)
        cities = ["北京", "上海", "广州", "深圳", "杭州", "成都", "重庆", "武汉", "西安", "南京",
                  "苏州", "天津", "长沙", "郑州", "青岛", "厦门", "昆明", "沈阳", "济南", "合肥"]
        for city in cities:
            self.assertIn(f'"{city}"', menu[start:end])
            self.assertIn(f'"{city}":', host)
        locate = host[host.index("private func agreeAndLocateHomeCity()"):host.index("private func selectHomeCity(")]
        self.assertIn("HomeCityCentre.nearest(to: fix.coordinate)", locate)
        self.assertNotIn("reverse-geocode", locate)
        self.assertNotIn("reverse-geocode", host)

    def test_role_chip_is_a_label_and_merchant_apply_stays_filtered(self):
        views = (ROOT / "App/HomeSearchTabParityViews.swift").read_text()
        row = views[views.index("private var greetingRow"):views.index("private var cityControl")]
        self.assertIn('Label("account.role.merchant"', row)
        self.assertNotIn("Button", row)
        self.assertNotIn("NavigationLink", row)
        gate = (ROOT / "Core/PlayerLaunch.swift").read_text()
        self.assertIn("merchantCenterEnabled", gate)
        banners = (ROOT / "Core/HomeSearchTabParity.swift").read_text()
        self.assertIn("PlayerLaunch.isHidden", banners)

    def test_associated_play_uses_the_public_info_read(self):
        section = (ROOT / "App/ActivityAssociatedPlaysSection.swift").read_text()
        detail = (ROOT / "App/ActivityDetailView.swift").read_text()
        self.assertIn("ActivityAssociatedPlaysSection(plays:", detail)
        self.assertIn("DiscoveryTemplateDetailView(id: $0, reader: session)", detail)
        self.assertIn("play.publicTemplateID", section)
        self.assertNotIn("scope=my", section)
        self.assertNotIn("myinfo", section)
        self.assertNotIn("api/template/myinfo", detail)

    def test_home_and_search_admits_the_public_play_template_route_without_growing_glue(self):
        composition = (ROOT / "App/AppCompositionRoot.swift").read_text().splitlines()
        self.assertLessEqual(len(composition), 4175)
        joined = "\n".join(composition)
        self.assertIn("PublicPlayTemplateReadRoute.accepts(request, baseURL: api.baseURL)", joined)
        self.assertLessEqual(len((ROOT / "App/AppSession.swift").read_text().splitlines()), 7977)
        route = (ROOT / "Core/PublicPlayTemplateReadRoute.swift").read_text()
        self.assertIn('appendingPathComponent("api/template/info")', route)
        self.assertIn('appendingPathComponent("api/template/list")', route)
        self.assertIn('appendingPathComponent("api/template/homeData")', route)
        self.assertNotIn('appendingPathComponent("api/template/myinfo")', route)


if __name__ == "__main__":
    unittest.main()
