#if DEBUG
import SwiftUI

/// Wave 3 B2 fixture: the real `HomeTodayCard` with a synthetic finger that taps near the upper right of the card
/// at 1.0 s and every 2.6 s after, so the dip, wave and recovery can be recorded without touch injection.
/// `--design-fixture wave-today-roam | wave-today-ticket | wave-today-club` (add `--uitesting-reduce-motion` for the RM take).
struct WaveTodayFixture: View {
    enum Kind { case roam, ticket, club }
    let kind: Kind
    @State private var wave = CYPressWaveModel()
    @QuestifyReduceMotion private var reduceMotion

    private var choice: HomeTodayChoice {
        switch kind {
        case .roam: return .roam
        case .ticket: return .ticket(HomeTodayFixtures.ticket)
        case .club: return .clubEvent(HomeTodayFixtures.clubEvent)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HomeTodayCard(choice: choice, onTicket: {}, onClubEvent: {}, onStartRoam: {}, waveModel: wave)
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.jumbo)
        // mp-home r3 (sweep 11-28 04:50): the club event shows a full card (bundled MP cover + meeting-point map).
        .environment(\.homeTodayFixtureCover, kind == .club ? MPAsset.BannerCover.clubCityCamera : nil)
        .cyDomainPageBackground()
        .themeDomain(.player)
        .task {
            try? await Task.sleep(for: .seconds(1))
            while !Task.isCancelled {
                await wave.simulateTap(at: CGPoint(x: 280, y: 70), waveOn: cyLightAllowed(reduceMotion: reduceMotion), reduceMotion: reduceMotion)
                try? await Task.sleep(for: .seconds(2.6))
            }
        }
    }
}
#endif
