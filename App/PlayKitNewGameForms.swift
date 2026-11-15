import SwiftUI

extension PlayKitScreen {
    @ViewBuilder var trueFalseForm: some View {
        artwork(raw["imageUrl"].text)
        HStack(spacing: CYSpacing.sm) {
            CYChoiceRow(
                label: appLocalized("playkit.trueFalse.true", locale: .current),
                selected: selected.contains("true"),
                multi: false,
                enabled: enabled,
                marker: "✓"
            ) {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.selection)
                selected = ["true"]
                dirty = true
            }
            .accessibilityIdentifier("playkit.trueFalse.true")

            CYChoiceRow(
                label: appLocalized("playkit.trueFalse.false", locale: .current),
                selected: selected.contains("false"),
                multi: false,
                enabled: enabled,
                marker: "✕"
            ) {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.selection)
                selected = ["false"]
                dirty = true
            }
            .accessibilityIdentifier("playkit.trueFalse.false")
        }
        submitButton(
            "SUBMIT_TRUE_FALSE",
            payload: ["answer": .bool(selected.contains("true"))],
            valid: selected.contains("true") || selected.contains("false")
        )
        if projection.complete, let explanation = raw["explanation"].text, !explanation.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("playkit.trueFalse.explanation").font(CYTypography.caption).foregroundStyle(.secondary)
                Text(verbatim: explanation).font(CYTypography.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.md)
            .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.glassFill))
            .accessibilityIdentifier("playkit.trueFalse.explanation")
        }
        attempts
    }

    @ViewBuilder var imageGuessForm: some View {
        let revealPercent = max(0, min(100, raw["revealPercent"].integer ?? (projection.complete ? 100 : 35)))
        let revealLevel = raw["revealLevel"].integer ?? 0
        let totalClues = raw["totalClues"].integer ?? 0
        let blurRadius: CGFloat = projection.complete ? 0 : CGFloat(max(0, 100 - revealPercent)) * 0.16

        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            artwork(raw["imageUrl"].text)
                .blur(radius: blurRadius)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .accessibilityIdentifier("playkit.imageGuess.artwork")

            HStack(spacing: CYSpacing.sm) {
                CYStatusChip(
                    verbatim: appLocalized("playkit.imageGuess.revealPct \(revealPercent)", locale: .current),
                    tone: projection.complete ? .success : .info,
                    systemImage: projection.complete ? "eye.fill" : "sparkles"
                )
                if totalClues > 0 {
                    Text("playkit.imageGuess.cluesCount \(revealLevel) \(totalClues)")
                        .font(CYTypography.meta).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }

        let clues = (raw["revealedClues"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !clues.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                ForEach(Array(clues.enumerated()), id: \.offset) { index, clue in
                    Text(verbatim: "\(index + 1). \(clue)").font(CYTypography.bodyCompact)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.md)
            .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.glassFill))
        }

        if totalClues > revealLevel && enabled {
            CYPillButton("playkit.imageGuess.revealNext", style: .secondary) {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.selection)
                prepare("SUBMIT_IMAGE_GUESS", ["action": .string("REVEAL_STEP")], {})
            }
            .accessibilityIdentifier("playkit.imageGuess.revealNext")
        }

        TextField("playkit.imageGuess.guessPlaceholder", text: textBinding(limit: 200))
            .cyField()
            .disabled(!enabled)
            .accessibilityIdentifier("playkit.imageGuess.input")

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        submitButton("SUBMIT_IMAGE_GUESS", payload: ["guess": .string(trimmed)], valid: !trimmed.isEmpty)

        if projection.complete, let answer = raw["answer"].text, !answer.isEmpty {
            LabeledContent("playkit.qa.revealedAnswer") {
                Text(verbatim: answer)
            }
            .accessibilityIdentifier("playkit.imageGuess.answer")
        }
        attempts
    }

    @ViewBuilder var jigsawForm: some View {
        PlayKitJigsawBoardView(
            segment: raw,
            approvedHosts: approvedArtworkHosts,
            enabled: enabled,
            onDirty: { dirty = true },
            requestReview: prepare
        )
        .id(runtimeIdentity)
    }

    @ViewBuilder var scratchCardForm: some View {
        let threshold = CYScratchProgressTracker.clampThreshold(raw["threshold"].double)
        CYScratchCard(
            coverLabel: raw["coverLabel"].text,
            threshold: threshold,
            enabled: enabled,
            revealed: projection.complete
        ) { progress in
            prepare("SUBMIT_SCRATCH_CARD", ["progress": .number(progress)], {})
        } content: {
            VStack(spacing: CYSpacing.sm) {
                if let prize = raw["prizeText"].text, !prize.isEmpty {
                    Text(verbatim: prize)
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityIdentifier("playkit.scratchCard.prize")
                } else {
                    Text("playkit.scratch.revealedPlaceholder")
                        .font(CYTypography.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                }
                if let url = raw["revealImageUrl"].text, !url.isEmpty {
                    artwork(url)
                }
            }
        }
    }
}

@MainActor private struct PlayKitJigsawBoardView: View {
    let segment: PlayWireValue
    let approvedHosts: Set<String>
    let enabled: Bool
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest

    @State private var order: [Int] = []
    @State private var pickedIndex: Int? = nil

    private var rows: Int { max(2, min(4, segment["rows"].integer ?? 2)) }
    private var cols: Int { max(2, min(4, segment["cols"].integer ?? 2)) }
    private var total: Int { rows * cols }
    private var serverOrder: [Int] {
        let raw = (segment["order"].array ?? []).compactMap(\.integer)
        if raw.count == total && Set(raw) == Set(0..<total) { return raw }
        return Array(0..<total)
    }
    private var isValidOrder: Bool {
        order.count == total && Set(order) == Set(0..<total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playkit.jigsaw.instructions").font(.footnote).foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: CYSpacing.xs), count: cols),
                spacing: CYSpacing.xs
            ) {
                ForEach(Array(order.enumerated()), id: \.offset) { position, piece in
                    let isSelected = pickedIndex == position
                    Button {
                        tapTile(at: position)
                    } label: {
                        ZStack(alignment: .topLeading) {
                            tileArtwork(piece: piece)
                            Text(verbatim: "#\(piece + 1)")
                                .font(CYTypography.caption).monospacedDigit()
                                .padding(.horizontal, CYSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(CYNight.ink2.opacity(0.85)))
                                .foregroundStyle(CYColor.textPrimary)
                                .padding(CYSpacing.xs)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYNight.glassFill))
                        .overlay(
                            RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                                .strokeBorder(isSelected ? CYNight.lantern : CYNight.glassEdgeTop, lineWidth: isSelected ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .accessibilityLabel(Text("playkit.jigsaw.tileLabel \(piece + 1) \(position + 1)"))
                    .accessibilityIdentifier("playkit.jigsaw.tile.\(position)")
                }
            }
            .accessibilityIdentifier("playkit.jigsaw.grid")

            if let moves = segment["moves"].integer, moves > 0 {
                LabeledContent("playkit.attempts") { Text(verbatim: String(moves)) }
            }

            CYPillButton("playkit.jigsaw.submit") {
                requestReview("SUBMIT_JIGSAW", ["order": .array(order.map(PlayWireValue.int))], {})
            }
            .disabled(!enabled || !isValidOrder)
            .accessibilityIdentifier("playkit.submit.jigsaw")
        }
        .onAppear {
            if order.isEmpty { order = serverOrder }
        }
        .onChange(of: serverOrder) { _, incoming in
            order = incoming
            pickedIndex = nil
        }
        .onChange(of: segment["solved"].bool == true) { wasSolved, nowSolved in
            if !wasSolved && nowSolved {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.jigsawSolved)
            }
        }
    }

    @ViewBuilder private func tileArtwork(piece: Int) -> some View {
        if let url = segment["imageUrl"].text, !url.isEmpty {
            let srcRow = piece / cols
            let srcCol = piece % cols
            GeometryReader { proxy in
                let fullW = proxy.size.width * CGFloat(cols)
                let fullH = proxy.size.height * CGFloat(rows)
                PlayKitArtwork(source: url, approvedHosts: approvedHosts)
                    .frame(width: fullW, height: fullH)
                    .offset(x: -CGFloat(srcCol) * proxy.size.width, y: -CGFloat(srcRow) * proxy.size.height)
            }
            .clipped()
        } else {
            Color.clear
        }
    }

    private func tapTile(at index: Int) {
        guard enabled, order.indices.contains(index) else { return }
        UIKitHapticsDriver.ensureInstalled()
        if let first = pickedIndex, first != index, order.indices.contains(first) {
            order.swapAt(first, index)
            pickedIndex = nil
            onDirty()
            HapticsService.shared.play(.jigsawSwap)
        } else {
            pickedIndex = pickedIndex == index ? nil : index
            HapticsService.shared.play(.selection)
        }
    }
}
