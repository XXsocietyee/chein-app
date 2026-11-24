import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - 3D Icosahedron D20 & D6 Pips Interactive View (Ported from d20-renderer.js & playkit-journey-check)

@available(macOS 14.0, *)
@MainActor struct DiceD20CanvasView: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var canvasHeight: CGFloat = 150
    let values: [Int]
    let kept: Int?
    let rollMode: String // "normal" | "advantage" | "disadvantage"
    let rolling: Bool
    /// When set (and Reduce Motion is off) the die tumbles while `rolling` and eases onto the rolled face afterwards.
    /// Left nil, the canvas draws one still frame, exactly as before.
    var animationStart: Date? = nil

    var body: some View {
        let count = (rollMode == "normal") ? 1 : 2
        Group {
            if let start = animationStart, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !rolling && Date().timeIntervalSince(start) > 2.2)) { timeline in
                    canvas(count: count, elapsedMs: max(0, timeline.date.timeIntervalSince(start) * 1000.0))
                }
            } else {
                canvas(count: count, elapsedMs: nil)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: canvasHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func canvas(count: Int, elapsedMs: Double?) -> some View {
        let state = makeRendererState(count: count, elapsedMs: elapsedMs)
        return Canvas { context, size in
            for item in state.lastRenderItems {
                drawDie(context: context, size: size, item: item)
            }
        }
    }

    private var accessibilitySummary: String {
        if rolling { return String(localized: LocalizedStringResource("playx.dice.a11y.rolling", defaultValue: "D20 is rolling", locale: locale)) }
        if let kept {
            return String(format: String(localized: LocalizedStringResource("playx.dice.a11y.result", defaultValue: "D20 shows %lld", locale: locale)), kept)
        }
        return String(localized: LocalizedStringResource("playx.dice.a11y.idle", defaultValue: "D20 ready to roll", locale: locale))
    }

    private func makeRendererState(count: Int, elapsedMs: Double?) -> DiceD20RendererState {
        let renderer = DiceD20RendererState(width: 280, height: 150, count: count)
        if rolling {
            renderer.roll(reducedMotion: false, nowMs: 0)
            renderer.step(nowMs: elapsedMs ?? 250)
        } else if !values.isEmpty, let kept {
            let safeValues = values.map { max(1, min(20, $0)) }
            let safeKept = max(1, min(20, kept))
            if let elapsedMs {
                _ = try? renderer.settle(values: safeValues, kept: safeKept, immediate: false, nowMs: 0)
                renderer.step(nowMs: elapsedMs)
            } else {
                _ = try? renderer.settle(values: safeValues, kept: safeKept, immediate: true)
            }
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
            let baseSize = max(Theme.length("--cy-type-body"), 1)
            let scale = max(12, radius * 0.36) / baseSize
            // Drawn into a GraphicsContext, which needs a `Text` (not a View): the static token font, scaled by the
            // layer below.
            let text = Text("\(frontVal)")
                .cyText(.numericBody)
                .foregroundStyle(labelColor.opacity(item.alpha))
            context.drawLayer { layer in
                layer.translateBy(x: cx, y: cy)
                layer.scaleBy(x: scale, y: scale)
                layer.draw(text, at: .zero, anchor: .center)
            }
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
        let isCrit = receipt.nat == "CRIT"

        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if !natTag.isEmpty {
                    CYStatusChip(verbatim: natTag, tone: isCrit ? .warning : .danger, systemImage: isCrit ? "star.fill" : "exclamationmark.triangle")
                }
                if !margin.isEmpty {
                    Text(verbatim: margin)
                        .cyText(.label)
                        .foregroundStyle(receipt.success == true ? CYColor.successText : CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let dc = receipt.dc, !receipt.detailsHidden {
                    Text(verbatim: "DC \(dc)")
                        .cyText(.numericBody)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !receipt.detailsHidden, receipt.kept != nil {
                ProgressView(value: pct, total: 100)
                    .tint(isCrit ? CYColor.warningText : (receipt.success == true ? CYColor.successText : CYColor.rare))
                    .accessibilityHidden(true)
            }

            if !receipt.breakdownRows.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    ForEach(Array(receipt.breakdownRows.enumerated()), id: \.offset) { _, row in
                        CYListRow(verbatim: row.label, trailing: .value(shownCount(row.value)))
                    }
                }
            }
        }
    }

    /// Blank breakdown values are unknown. A literal 0 stays 0.
    private func shownCount(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
