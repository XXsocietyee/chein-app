"""Native wiring guards only; Swift and UI execution require Apple tooling."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TopicTemplateNameSearchContracts(unittest.TestCase):
    def test_local_name_only_literal_search_has_no_transport_or_cached_rows(self):
        core = (ROOT / 'Core/DiscoveryContracts.swift').read_text()
        search = core.split('public struct DiscoveryTopicTemplateNameSearch:', 1)[1].split('public struct DiscoveryTemplateHome:', 1)[0]
        self.assertIn('keyword = text.trimmingCharacters(in: whitespace)', search)
        self.assertIn('let needle = keyword.lowercased()', search)
        self.assertIn('$0.name.lowercased().range(of: needle, options: .literal)', search)
        self.assertIn('guard isActive else { return rows }', search)
        for forbidden in ['subtitle', 'localizedCaseInsensitiveContains', 'URLSession', 'token', 'sorted(', 'Set<', 'previewOnly ==']:
            self.assertNotIn(forbidden, search)

    def test_one_capsule_opens_global_search_without_a_local_field_or_post(self):
        view = (ROOT / 'App/DiscoveryTemplateBrowserView.swift').read_text()
        self.assertIn('Text("discovery.searchAll")', view)
        self.assertEqual(view.count('SessionGlobalSearchView()'), 2)
        self.assertIn('.environment(\\.globalTemplateSearch, .session(session))', view)
        self.assertIn('searchDestination _:', view)
        self.assertNotIn('searchDestination()', view)
        self.assertNotIn('_ = searchDestination', view)
        self.assertNotIn('TextField(', view)
        self.assertNotIn('DiscoveryTopicTemplateNameSearch', view)
        self.assertNotIn('discovery.topicNameSearch', view)
        self.assertNotIn('Text("discovery.search"', view)
        self.assertIn('shelfChipRow(SearchDiscoveryFilterParity.topicTags', view)
        self.assertIn('shelfChipRow(SearchDiscoveryFilterParity.gameTags', view)
        self.assertIn('let shown = SearchDiscoveryFilterParity.topics(catalog, matching: tags.selection)', view)
        self.assertIn('AppCompositionRoot(deployment: .unconfigured)', view)
        entrance = view.split('@ViewBuilder private var templateShelfSearch:', 1)[1].split('private func filterChip', 1)[0]
        for forbidden in ['URLSession', 'httpMethod', 'POST', 'discoveryPlayTemplates']:
            self.assertNotIn(forbidden, entrance)
        self.assertNotIn('requestedKeyword', view)
        self.assertIn('discoveryPlayTemplates(keyword: "", packType: .single)', view)
        search = (ROOT / 'App/GlobalSearchView.swift').read_text()
        self.assertIn('guard filter.canSearch else', search)
        self.assertIn('emptySearchNotice = LocalizedStringKey("searchMap.needKeywordOrCategory")', search)

    def test_unchanged_request_authority_and_stateful_detail_identity_are_preserved(self):
        view = (ROOT / 'App/DiscoveryTemplateBrowserView.swift').read_text()
        self.assertIn('reader.publicTopicTemplateCatalogRequest()', view)
        # The load moved into the topics state object but still uses the unchanged catalog request.
        self.assertIn('let rows = try await request.read()', view)
        self.assertIn('if error as? APIError == .unauthorized { request.onUnauthorized() }', view)
        self.assertIn('selected.identity == reader.discoveryPresentationIdentity', view)
        # R7-PC-A7-1 (r8 re-pin): the row opens the MP topic-preview deck over the same selected coordinator.
        self.assertIn('DiscoveryTopicTemplateDeckHost(coordinator: selected.coordinator, readonly: false,', view)
        self.assertIn('.id(selected.id)', view)
        service = (ROOT / 'Core/DiscoveryService.swift').read_text()
        read = service.split('public func topicTemplates(', 1)[1].split('public func publicTopicTemplate(', 1)[0]
        self.assertIn('fields: nil', read)
        for forbidden in ['keyword', 'pageNum', 'pageSize']:
            self.assertNotIn(forbidden, read)
        self.assertIn('authoringFactory(selected.source)', (ROOT / 'App/DiscoveryTemplateDetailView.swift').read_text())
        self.assertNotIn('authoringFactory(', view.split('private func topicSection', 1)[1].split('private func gameSection', 1)[0])

    def test_search_all_copy_and_authored_behavior_inventory(self):
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())['strings']
        for lang in ['en', 'zh-Hans']:
            self.assertEqual(catalog['discovery.searchAll']['localizations'][lang]['stringUnit']['state'], 'translated')
        core = (ROOT / 'Tests/CoreTests/DiscoveryContractTests.swift').read_text()
        for name in ['TrimsAndUsesCaseInsensitiveNameSubstring', 'IgnoresSubtitleAndUnrelatedFields',
                     'PreservesSourceOrderCategoryPriorityAndPreviewFlags', 'IsLiteralWithoutAccentOrWidthFolding',
                     'UsesMiniTrimWhitespaceIncludingBOM', 'ProjectsOnlyCurrentRowsAndDoesNotCacheMatches']:
            self.assertIn('func testTopicNameSearch' + name, core)
        app = (ROOT / 'Tests/AppUnitTests/PublicTemplateCompositionTests.swift').read_text()
        self.assertIn('func testLocalTopicNameSearchUsesReloadedCatalogWithoutChangingWireShape', app)
        self.assertIn('func testLocalTopicNameSearchCannotRestoreSupersededCatalogResults', app)
        ui = ROOT / 'Tests/AppUITests/TopicTemplateNameSearchFlowTests.swift'
        text = ui.read_text()
        self.assertEqual(text.count('    func test'), 3)
        self.assertNotIn('discovery.topicNameSearch', text)
        self.assertNotIn('"discovery.search"', text)
        self.assertIn('discovery.globalSearch', text)
        self.assertIn('searchMap.keyword', text)
        self.assertIn('--uitesting-max-text', text)
        self.assertIn('dynamicTypeSize: "accessibility5"', text)
        self.assertIn(str(ui.relative_to(ROOT)), (ROOT / 'Questify.xcodeproj/project.pbxproj').read_text())


if __name__ == '__main__':
    unittest.main()
