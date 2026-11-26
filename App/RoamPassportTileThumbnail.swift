import SwiftUI

/// ROAM-8b (MP pages/roam/index.wxml:186-205, utils/roam-passport-tiles.js `latestTrackThumb` / `latestStampImage`):
/// the 漫游记录 tile draws the newest walk's track and the 集邮册 tile the newest stamp photo; an empty value keeps the
/// MP 3D illustration. The track arrives as the MP `data:image/svg+xml` thumbnail; iOS cannot decode SVG through
/// `UIImage`, so the same `polyline` points (100×100 viewBox) are drawn natively. Photos go through the bounded loader.
@MainActor struct RoamPassportTileThumbnail<Illustration: View>: View {
    let source: String
    @ViewBuilder var illustration: () -> Illustration

    var body: some View {
        Group {
            if source.hasPrefix("data:image/svg+xml"), let points = Self.polyline(source), points.count >= 2 {
                RoamPassportTrackShape(points: points)
            } else if source.hasPrefix("https://") {
                BoundedMediaThumbnail(url: source) { illustration() }
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            } else {
                illustration()
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }

    /// Reads `points="x,y x,y …"` out of the base64 SVG built by `RoamPassportHome.latestTrackThumbnail`.
    static func polyline(_ dataURL: String) -> [CGPoint]? {
        guard let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
              let svg = String(data: data, encoding: .utf8),
              let start = svg.range(of: "points=\"") else { return nil }
        let rest = svg[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let points: [CGPoint] = rest[..<end].split(separator: " ").compactMap { pair in
            let xy = pair.split(separator: ",")
            guard xy.count == 2, let x = Double(xy[0]), let y = Double(xy[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
        return points
    }
}

/// MP thumbnail look: dark square, light stroke (no lime token in the design system) 3/100, round caps, end dot r 4/100.
private struct RoamPassportTrackShape: View {
    let points: [CGPoint]
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            var path = Path()
            for (index, point) in points.enumerated() {
                let p = CGPoint(x: point.x * scale, y: point.y * scale)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                let r = 4 * scale
                context.fill(Path(ellipseIn: CGRect(x: last.x * scale - r, y: last.y * scale - r, width: r * 2, height: r * 2)),
                             with: .color(.white))
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
    }
}
