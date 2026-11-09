import SwiftUI

/// Generated cover art for headers that have no photo: a deterministic dark gradient with a large faint SF Symbol.
/// Decoration only (hidden from VoiceOver); never stands in for server imagery.
struct CYCoverArt: View {
    let seed: String
    let symbol: String
    var cornerRadius: CGFloat = CYRadius.lg

    private var hue: Double {
        let sum = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }
        return Double(sum) / 360
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.42),
                                    Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(.white.opacity(0.14))
                .offset(x: 12, y: 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}
