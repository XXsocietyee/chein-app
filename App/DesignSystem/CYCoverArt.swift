import SwiftUI

/// Deterministic generated cover art for entities that have no photo (club, conversation, group).
/// Same seed => same colours, so a row never flickers between renders. Decorative: hidden from VoiceOver.
struct CYCoverArt: View {
    let seed: String
    var systemImage: String = "person.3.fill"
    var symbolSize: CGFloat = 36

    private var hue: Double {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Double(h % 360) / 360
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.62),
                                    Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: .topTrailing, startRadius: 4, endRadius: 160)
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .accessibilityHidden(true)
    }
}
