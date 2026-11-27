"""Activity review source wiring only; no Swift/Apple runtime acceptance."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ActivityReviewChecks(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_reviews_are_read_from_allowed_detail_and_mounted_after_tickets(self):
        model = self.read('Core/ActivityDetail.swift')
        self.assertIn('reviews=try ActivityReviews(from:decoder)', model)
        view = self.read('App/ActivityDetailView.swift')
        # One mount in the classic detail list and one in the native-r2 city event list (3ec3d687f).
        self.assertEqual(view.count('ActivityReviewsSection(reviews: detail.reviews)'), 2)
        city = view.split('private func cityEventDetail(', 1)[1].split('private func cityEventCTA(', 1)[0]
        self.assertEqual(city.count('ActivityReviewsSection(reviews: detail.reviews)'), 1)
        # mp-home r3 continue: the city list mounts the reviews right after 票种 (MP order), people before 票种.
        city_list = (ROOT / 'App/NativeR2/CityOrientation/CityOrientationEventDetailList.swift').read_text()
        self.assertIn('reviews: AnyView(ActivityReviewsSection(reviews: detail.reviews))', city)
        self.assertLess(city_list.index('if let people { people }'), city_list.index('Section("nativeR2.city.event.tickets")'))
        self.assertLess(city_list.index('Section("nativeR2.city.event.tickets")'), city_list.index('if let reviews { reviews }'))
        self.assertLess(city_list.index('if let reviews { reviews }'), city_list.index('more()'))
        self.assertNotIn('Map(initialPosition', city_list)
        self.assertLess(city.index('ActivityReviewsSection('), city.index('moreInfoSections(detail)'))
        view = view.replace(city, '')
        # U9-B: as in the mini-program, reviews follow the tickets on the first fold, before the "More info" toggle.
        self.assertLess(view.index('E1IconHeader(systemImage: "ticket"'), view.index('ActivityReviewsSection('))
        self.assertLess(view.index('ActivityReviewsSection('), view.index('accessibilityIdentifier("activity.more.toggle")'))
        self.assertLess(view.index('accessibilityIdentifier("activity.more.toggle")'), view.index('if showsMoreInfo { moreInfoSections(detail) }'))
        more = view.split('private func moreInfoSections', 1)[1].split('private func profileAction', 1)[0]
        self.assertNotIn('ActivityReviewsSection(reviews: detail.reviews)', more)
        self.assertIn('.accessibilityIdentifier("activity.openReview")', view)
        gate = view.split('case .clubRequired', 1)[1].split('case .allowed', 1)[0]
        self.assertNotIn('ActivityReviewsSection', gate)
        self.assertIn('.id(session.contentDetailRevision)', view)
        self.assertIn('phase = .loading;loadedProfileIdentity=nil', view)
        self.assertIn('if generation == operation, profileIdentity == peopleProfile?.reader.identity,', view)
        self.assertIn('ContextualReviewComposer(target: .activity(id)', view)
        self.assertIn('Button { showsReview = true } label: {', view)
        # R10-PC-C-N4 (native r2): the 写评价 row is a system Label (MP scene-play-activity-detail/index.wxml:138 opens the sheet).
        self.assertIn('Label("context.review.title", systemImage: "square.and.pencil")', view)

    def test_bounded_preview_is_not_count_average_or_authority(self):
        model = self.read('Core/ActivityReviews.swift')
        for token in ['case averageRating, commentCount, commentList',
                      'guard preview.count <= 5 else { throw APIError.malformedResponse }',
                      'commentCount == 0 && preview.isEmpty',
                      '$0.isFinite && (0...5).contains($0)',
                      '(0...5).contains($0)',
                      'case memberNickname, createTime, rating, contents']:
            self.assertIn(token, model)
        for token in ['commentCount = preview.count', 'reduce(', 'memberId', 'ownerId', '/api/', 'URLSession', 'token', 'phone']:
            self.assertNotIn(token, model)

    def test_display_handles_unknowns_and_preserves_plain_text(self):
        view = self.read('App/ActivityReviewsSection.swift')
        for token in ['if !reviews.hasConfirmedNoReviews', 'if let average = reviews.averageRating',
                      'if let count = reviews.commentCount', 'if reviews.preview.isEmpty',
                      'Text("activity.reviews.previewUnavailable")', 'Text("activity.reviews.empty")',
                      'Text(verbatim: contents)', 'Text(verbatim: name)',
                      # en-layout r3: the server date is re-rendered for English (Chinese and unparsable text unchanged).
                      'Text(verbatim: LocaleDisplay.civil(date, locale: locale))',
                      'ForEach(Array(reviews.preview.enumerated()), id: \\.offset)',
                      '.textSelection(.enabled)', '.fixedSize(horizontal: false, vertical: true)']:
            self.assertIn(token, view)
        for token in ['Button', 'NavigationLink', 'URLSession', '.task(', '@State', '.lineLimit(', 'AsyncImage', 'https://']:
            self.assertNotIn(token, view)
        # Only static SF Symbol glyphs (the star rating) are allowed; no loaded images.
        self.assertEqual(view.count('Image('), view.count('Image(systemName:'))
        catalog = json.loads(self.read('Resources/Localizable.xcstrings'))['strings']
        for suffix in ['title', 'average', 'total', 'rating', 'ratingUnknown', 'countUnknown',
                       'empty', 'previewUnavailable', 'previewHint', 'authorUnknown', 'textUnavailable']:
            self.assertEqual(set(catalog['activity.reviews.' + suffix]['localizations']), {'en', 'zh-Hans'})

    def test_authored_domain_and_synthetic_ui_coverage(self):
        tests = self.read('Tests/CoreTests/ActivityReviewsTests.swift')
        for token in ['testReadsServerScoreAndTotalSeparatelyFromPreview',
                      'testMissingAndNullMetadataStayUnknown', 'testKnownZeroIsDistinctFromAnUnavailablePreview',
                      'testRatingsAndCountsAreValidatedWithoutCoercionOrClamping',
                      'testMalformedListsAndRowsCannotBecomeEmptySuccess',
                      'testPreviewIsBoundedToFiveRowsWithoutDeduplicatingUnnamedReviews',
                      'testBlankDisplayFieldsStayUnavailableAndRealTextIsPreserved',
                      'testClubGateNeverDecodesHiddenReviews']:
            self.assertIn(token, tests)
        ui = self.read('Tests/AppUITests/ActivityFlowTests.swift')
        for token in ['testReviewPreviewKeepsServerTotalAndSurvivesBackAndReopen',
                      'testKnownEmptyReviewsDoNotShowAZeroStarRating',
                      'testMissingReviewsRemainUnknownRatherThanEmptyOrFiveStars']:
            self.assertIn(token, ui)
        fixture = self.read('App/ActivityFixtureSupport.swift')
        self.assertTrue(fixture.startswith('#if DEBUG'))
        for token in ['case reviews', 'case reviewsEmpty', 'case reviewsUnknown']:
            self.assertIn(token, fixture)
        self.assertNotIn('https://', fixture)


if __name__ == '__main__':
    unittest.main()
