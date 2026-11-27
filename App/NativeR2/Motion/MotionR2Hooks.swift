import SwiftUI

// Host-specific wrappers so each flow file only needs a one-line hook.

/// R8 + R11 + R12 at the city-orientation finish line: the edge glows once, the walked distance (or time) is a huge
/// number over a mood gradient, and the route completion fills a flame. Flag off: nothing (the existing metrics grid
/// stays the summary).
struct MotionR2FinishHeroSection: View {
    let walkedMeters: Double
    let elapsedSeconds: Int
    let doneCount: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(doneCount) / Double(total) : 0 }

    var body: some View {
        if NativeR2Flags.motion2, walkedMeters > 0 || elapsedSeconds > 0 {
            Section {
                if walkedMeters > 0 {
                    MotionR2MoodHero(value: CityOrientationFormat.distance(walkedMeters), numericValue: walkedMeters,
                                     captionKey: "motion2.finish.distance", mood: MotionR2Mood.forFraction(fraction))
                } else {
                    MotionR2MoodHero(value: PlayRunElapsedText.format(elapsedSeconds), numericValue: Double(elapsedSeconds),
                                     captionKey: "motion2.finish.time", mood: MotionR2Mood.forFraction(fraction))
                }
                if total > 0 {
                    MotionR2FillGauge(fraction: fraction, valueText: "\(doneCount)/\(total)", captionKey: "motion2.finish.intensity")
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .listRowBackground(Color.clear)
        }
    }
}
