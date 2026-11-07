import SwiftUI
import QuestifyCore

// MARK: - 3D Icosahedron D20 & D6 Pips Interactive View (Ported from d20-renderer.js & playkit-journey-check)

@available(macOS 14.0, *)
@MainActor struct DiceD20CanvasView: View {
    let values: [Int]
    let kept: Int?
    let rollMode: String // "normal" | "advantage" | "disadvantage"
    let rolling: Bool

    var body: some View {
        let count = (rollMode == "normal") ? 1 : 2
        let state = makeRendererState(count: count)
        Canvas { context, size in
            for item in state.lastRenderItems {
                drawDie(context: context, size: size, item: item)
            }
        }
        .frame(height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if rolling { return "D20 正在掷骰" }
        if let kept {
            return "D20 骰面点数 \(kept)"
        }
        return "D20 待掷骰"
    }

    private func makeRendererState(count: Int) -> DiceD20RendererState {
        let renderer = DiceD20RendererState(width: 280, height: 150, count: count)
        if rolling {
            renderer.roll(reducedMotion: false, nowMs: 250)
            renderer.step(nowMs: 500)
        } else if !values.isEmpty, let kept {
            let safeValues = values.map { max(1, min(20, $0)) }
            let safeKept = max(1, min(20, kept))
            _ = try? renderer.settle(values: safeValues, kept: safeKept, immediate: true)
        }
        return renderer
    }

    private func drawDie(context: GraphicsContext, size: CGSize, item: DiceD20DieRenderItem) {
        let scaleX = size.width / 280.0
        let scaleY = size.height / 150.0
        let scale = min(scaleX, scaleY)
        let cx = item.centerX * scaleX
        let cy = item.centerY * scaleY
        let radius = item.radius * scale
        let light = DiceVec3(-0.35, 0.55, 0.76)

        let projectedFaces = DiceD20Geometry.faces.map { face -> (face: DiceD20Face, normal: DiceVec3, pts: [CGPoint]) in
            let n = DiceD20Geometry.rotate(item.orientation, face.normal)
            let pts = face.points.map { p -> CGPoint in
                let rp = DiceD20Geometry.rotate(item.orientation, p)
                return CGPoint(x: cx + rp.x * radius, y: cy - rp.y * radius)
            }
            return (face, n, pts)
        }
        .filter { $0.normal.z > -0.08 }
        .sorted { $0.normal.z < $1.normal.z }

        for entry in projectedFaces {
            guard entry.pts.count == 3 else { continue }
            var path = Path()
            path.move(to: entry.pts[0])
            path.addLine(to: entry.pts[1])
            path.addLine(to: entry.pts[2])
            path.closeSubpath()

            let shade = max(0.0, entry.normal.dot(light))
            let fillColor: Color = item.gold
                ? Color(red: min(1.0, (192.0 + shade * 52.0) / 255.0),
                        green: min(1.0, (148.0 + shade * 48.0) / 255.0),
                        blue: min(1.0, (54.0 + shade * 28.0) / 255.0))
                : Color(red: min(1.0, (38.0 + shade * 42.0) / 255.0),
                        green: min(1.0, (43.0 + shade * 46.0) / 255.0),
                        blue: min(1.0, (58.0 + shade * 58.0) / 255.0))
            let strokeColor: Color = item.gold
                ? Color(red: 1.0, green: 0.93, blue: 0.72).opacity(0.75 * item.alpha)
                : Color(red: 0.78, green: 0.83, blue: 0.96).opacity(0.42 * item.alpha)

            context.fill(path, with: .color(fillColor.opacity(item.alpha)))
            context.stroke(path, with: .color(strokeColor), lineWidth: 1.0)
        }

        if let frontVal = item.frontValue {
            let labelColor = item.gold ? Color(red: 0.17, green: 0.11, blue: 0.02) : Color.white
            let text = Text("\(frontVal)")
                .font(.system(size: max(12, radius * 0.36), weight: .bold, design: .rounded))
                .foregroundStyle(labelColor.opacity(item.alpha))
            context.draw(text, at: CGPoint(x: cx, y: cy), anchor: .center)
        }
    }
}

@available(macOS 14.0, *)
@MainActor struct DiceJourneyReceiptSummaryCard: View {
    let receipt: DiceJourneyCheckReceiptView

    var body: some View {
        let natTag = DiceJourneyCheckRules.natTag(receipt)
        let margin = DiceJourneyCheckRules.marginText(receipt)
        let pct = DiceJourneyCheckRules.trackPct(receipt.kept)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if !natTag.isEmpty {
                    Text(natTag)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(receipt.nat == "CRIT" ? Color.yellow.opacity(0.25) : Color.red.opacity(0.2), in: Capsule())
                }
                if !margin.isEmpty {
                    Text(margin)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(receipt.success == true ? .green : .secondary)
                }
                Spacer()
                if let dc = receipt.dc, !receipt.detailsHidden {
                    Text("DC \(dc)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !receipt.detailsHidden, receipt.kept != nil {
                ProgressView(value: pct, total: 100)
                    .tint(receipt.nat == "CRIT" ? .yellow : (receipt.success == true ? .green : .orange))
            }

            if !receipt.breakdownRows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(receipt.breakdownRows.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(row.value)
                                .font(.caption.monospacedDigit().weight(.medium))
                        }
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
