import SwiftUI

extension PlayKitScreen {
    @ViewBuilder var legacyBody: some View {
        switch kind {
        case .blindTaste: blindTasteBody
        case .diyName: namingBody
        case .slowTask: PlayKitSlowTaskBody(segment: raw, enabled: enabled, requestReview: prepare)
        case .musicCorner:
            if raw["arrived"].bool == true {
                CYStatusChip("playkitLegacy.music.arrived", tone: .success, systemImage: "mappin").singleLine()
                    .accessibilityIdentifier("playkit.musicCorner.arrived")
            }
            if let track = raw["trackName"].text { Text(verbatim: track).cyText(.sheetTitle) }
            if let seconds = raw["durationSeconds"].integer, seconds > 0 {
                LabeledContent("playkitLegacy.music.duration") { Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60)).monospacedDigit() }
            }
            PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
        case .silentOrder:
            // Mini-program order: rule, witness code with its caption, then the clock.
            if let rule = raw["rule"].text, !rule.isEmpty { Text(verbatim: rule).cyText(.sectionTitle) }
            VStack(spacing: CYSpacing.sm) {
                if let qr = raw["qrUrl"].text, !qr.isEmpty { artwork(qr).frame(maxWidth: 200) }
                else { CYStatusChip("playkitLegacy.silent.noWitnessCode", tone: .neutral, systemImage: "qrcode") }
                Text("playkitLegacy.silent.qrCaption").cyText(.meta).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("playkit.silentOrder.witness")
            PlayKitSilentOrderBody(segment: raw, active: model.isCurrent, onDirty: { dirty = true })
        case .timeWindow:
            NativeTimeWindowHostView(advanced: model, segment: raw)
        default: EmptyView()
        }
    }
    @ViewBuilder private var blindTasteBody: some View {
        // Three numbered steps (collect, taste with eyes closed, answer); the full sentence stays for VoiceOver.
        PlayKitBlindSteps(keys: ["playkitLegacy.blind.step1", "playkitLegacy.blind.step2", "playkitLegacy.blind.step3"])
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: stepsSentence))
        Text("playkitLegacy.blind.question").cyText(.body).foregroundStyle(.secondary)
        VStack(spacing: 0) {
            Divider()
            ForEach(projection.options) { option in
                let on = selected.contains(option.id)
                Button { selected = [option.id]; dirty = true } label: {
                    HStack(spacing: CYSpacing.lg) {
                        Text(verbatim: option.id).font(CYTypography.bodyMedium.italic()).foregroundStyle(on ? .primary : .secondary)
                        Text(verbatim: option.label).font(on ? CYTypography.cardTitle : CYTypography.body).foregroundStyle(on ? .primary : .secondary)
                        Spacer(minLength: 0)
                        if on { Image(systemName: "square.fill").font(.caption2).accessibilityHidden(true) }
                    }
                    .frame(minHeight: 56).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(!enabled)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("playkit.blindTaste.option." + option.id)
                Divider()
            }
        }
        if let xp = raw["xpLabel"].text, !xp.isEmpty { Text(verbatim: xp).cyText(.meta) }
        if raw["solved"].bool == true { Text("playkit.result.passed") }
        else if (raw["attempts"].integer ?? 0) > 0 { Text("playkitLegacy.blind.tryAgain") }
        attempts
        submitButton("SUBMIT_BLIND_TASTE", payload: ["key": .string(selected.first ?? "")], valid: !selected.isEmpty)
    }
    private var stepsSentence: String {
        if let steps = raw["steps"].text, !steps.isEmpty { return steps }
        return (raw["steps"].array ?? []).compactMap(\.text).joined(separator: ", ")
    }
    @ViewBuilder private var namingBody: some View {
        let maxLength = max(1, raw["maxLength"].integer ?? 16)
        if let photo = raw["photoUrl"].text, !photo.isEmpty {
            artwork(photo).frame(maxWidth: 120, alignment: .leading)
                .accessibilityLabel(Text("playkitLegacy.name.photo"))
        }
        // N-KIT-CHOICE (r10): a plain system field (MP pages/playkit/components playkit-diy-name input).
        TextField("playkitLegacy.name.placeholder", text: textBinding(limit: maxLength), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .disabled(!enabled)
            .accessibilityIdentifier("playkit.diyName.field")
        LabeledContent("playkit.characters") { Text(verbatim: "\(text.utf16.count) / \(maxLength)").monospacedDigit() }
        let suggestions = (raw["suggestions"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !suggestions.isEmpty {
            Text("playkitLegacy.name.suggestions").cyText(.meta).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button { text = PlayKitInputContract.limitText(suggestion, toUTF16: maxLength); dirty = true } label: {
                            Text(verbatim: appQuoted(suggestion, locale: .current)).cyText(.label)
                        }
                        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                        .disabled(!enabled)
                    }
                }
            }
        }
        Text("playkitLegacy.name.audience").cyText(.bodyCompact)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Button { prepare("SUBMIT_DIY_NAME", ["name": .string(trimmed)]) } label: {
            if let label = raw["ctaLabel"].text, !label.isEmpty { Text(verbatim: label) } else { Text("playkitLegacy.name.submit") }
        }
        .buttonStyle(.borderedProminent).disabled(!enabled || trimmed.isEmpty)
        .accessibilityIdentifier("playkit.submit." + kind.rawValue)
    }
}

@MainActor struct PlayKitSlowTaskBody: View {
    let segment: PlayWireValue; let enabled: Bool; let requestReview: PlayKitReviewRequest
    @State private var revealed = false
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if segment["claimed"].bool == true {
                CYScratchCard(
                    coverLabel: appLocalized("playkitLegacy.slow.reveal", locale: locale),
                    threshold: 0.4,
                    revealed: revealed,
                    onReveal: { _ in revealed = true }
                ) {
                    if let text = segment["unlockText"].text, !text.isEmpty {
                        Text(verbatim: text).cyText(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("playkit.slowTask.unlockText")
                    } else {
                        Text("playkitLegacy.slow.emptyReadback")
                    }
                }
            } else if segment["started"].bool == true {
                if let days = segment["daysLeft"].integer, days > 0 {
                    Text("playkitLegacy.slow.daysLeftCount \(days)").cyText(.dataXL).monospacedDigit()
                        .accessibilityIdentifier("playkit.slowTask.daysLeft")
                    if let hint = segment["waitHint"].text, !hint.isEmpty { Text(verbatim: hint) }
                } else if segment["daysLeft"].integer == 0 {
                    Text("playkitLegacy.slow.ready")
                    Button { requestReview("CLAIM_SLOW_TASK", [:], {}) } label: {
                        if let label = segment["unlockLabel"].text, !label.isEmpty { Text(verbatim: label) } else { Text("playkitLegacy.slow.claim") }
                    }.buttonStyle(.borderedProminent).disabled(!enabled)
                } else { Text("playkit.configurationInvalid") }
            } else {
                if let hint = segment["startHint"].text, !hint.isEmpty { Text(verbatim: hint) }
                Button { requestReview("START_SLOW_TASK", [:], {}) } label: {
                    if let label = segment["startLabel"].text, !label.isEmpty { Text(verbatim: label) } else { Text("playkitLegacy.slow.start") }
                }.buttonStyle(.borderedProminent).disabled(!enabled)
            }
        }
        .cyHapticEvent(.claimSuccess, trigger: segment["claimed"].bool == true) { old, next in !old && next }
    }
}

/// A foreground companion clock, not challenge evidence. There is intentionally
/// no action callback and no completion, score or reward mutation.
@MainActor struct PlayKitSilentOrderBody: View {
    let segment: PlayWireValue; let active: Bool; let onDirty: () -> Void
    @State private var startedAt: TimeInterval?
    @State private var elapsed = 0
    @State private var gaveUp = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let seconds = elapsed + (startedAt.map { Int(max(0, ProcessInfo.processInfo.systemUptime - $0)) } ?? 0)
                Label {
                    Text("playkitLegacy.silent.performed \(String(format: "%02d:%02d", seconds / 60, seconds % 60))").monospacedDigit()
                } icon: { Image(systemName: "clock") }
                .font(CYTypography.bodyMedium.italic())
                .foregroundStyle(CYNight.lantern)
            }
            if gaveUp { Text("playkitLegacy.silent.stopped") }
            else if startedAt == nil {
                Button("playkitLegacy.silent.start") { startedAt = ProcessInfo.processInfo.systemUptime; onDirty() }.disabled(!active)
            } else {
                Button(role: .destructive) {
                    var transition = PlayKitSilentOrderGiveUp(running: startedAt != nil, gaveUp: gaveUp)
                    transition.giveUp()
                    stop()
                    gaveUp = transition.gaveUp
                    onDirty()
                } label: { Label("playkitLegacy.silent.giveUp", systemImage: "arrow.right").labelStyle(PlayKitTrailingIconLabelStyle()) }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(!active)
            }
        }
        .onAppear { elapsed = max(0, segment["elapsedSeconds"].integer ?? 0) }
        .onChange(of: active) { _, value in if !value { stop() } }
        .onChange(of: scenePhase) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
    }
    private func stop() { if let startedAt { elapsed += Int(max(0, ProcessInfo.processInfo.systemUptime - startedAt)); self.startedAt = nil } }
}

/// Text first, icon after: the mini-program's trailing-arrow link.
struct PlayKitTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: CYSpacing.xs) { configuration.title; configuration.icon }
    }
}

/// a11y-dt r3: the blind-taste step numbers grow with Dynamic Type (no fixed 36 pt circle), and the three steps
/// stack vertically when they no longer fit side by side (AX sizes, long English).
private struct PlayKitBlindSteps: View {
    let keys: [String]
    @ScaledMetric(relativeTo: .body) private var badge: CGFloat = 36

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.xl) { steps }
            VStack(spacing: CYSpacing.md) { steps }
        }
    }

    @ViewBuilder private var steps: some View {
        ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
            VStack(spacing: CYSpacing.xs) {
                Text(verbatim: String(index + 1)).font(CYTypography.bodyMedium.italic()).monospacedDigit()
                    .frame(width: badge, height: badge).background(Circle().fill(Color.primary.opacity(0.9)))
                    .foregroundStyle(CYColor.bgSurface)
                Text(LocalizedStringKey(key)).cyText(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
