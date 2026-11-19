import SwiftUI

/// The designed default cover (`Club/Default Cover` / `Media/Cover` default, skill-r2 SR2-06): what a topic, a theme or a
/// collection shows when it has no photo, or when photos cannot load (TEST has no image storage). Never a 图片暂不可用
/// line in the hero: a raised gradient, the name's first character at 12 % as a watermark, a dashed route mark and a
/// small symbol disc. Decorative: hidden from VoiceOver (the title follows the cover in text).
struct CYDesignedCover: View {
    let title: String
    var symbol: String = "point.topleft.down.to.point.bottomright.curvepath"
    var cornerRadius: CGFloat = CYRadius.xl
    /// Small caption on the cover (e.g. 城市定向). nil hides it.
    var caption: String? = nil

    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var watermark: CGFloat = 96
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36

    private var initial: String { title.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "城" }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [palette.bgRaised, palette.bgElevated], startPoint: .topLeading, endPoint: .bottomTrailing)
            CYRouteMark()
                .stroke(palette.textPrimary.opacity(0.14), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 7]))
                .padding(28)
            Text(verbatim: initial)
                .font(.system(size: watermark, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.textPrimary.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, CYSpacing.lg)
                .padding(.top, CYSpacing.sm)
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: disc, height: disc)
                    .background(palette.borderStrong, in: Circle())
                if let caption {
                    Text(verbatim: caption).font(CYTypography.label.weight(.semibold)).foregroundStyle(palette.textSecondary)
                }
            }
            .padding(CYSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// A gentle three-stop route curve with two stop dots, drawn into any rect.
struct CYRouteMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let a = CGPoint(x: rect.minX, y: rect.maxY * 0.78)
        let b = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.42)
        let c = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18)
        path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.30))
        path.addQuadCurve(to: c, control: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.maxY * 0.62))
        for point in [a, b, c] { path.addEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)) }
        return path
    }
}
