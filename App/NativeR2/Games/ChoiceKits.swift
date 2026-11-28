import SwiftUI
import UIKit

// Native r2 games-b, Template 6: Story choice & progress (bingo is drawn by half A).
// Apple reference: Books reader (text first, choices as plain list rows), Music Now Playing
// (compact play / pause), Fitness Awards grid (bingo). Same actions and payloads as before.

// MARK: - branch

@MainActor struct ChoiceBranchKit: View {
    let context: GamesBKitContext
    var cast: CastStoryContext? = nil
    private var raw: PlayWireValue { context.segment }
    private var pick: Binding<String> {
        Binding(get: { context.selection.wrappedValue.first ?? "" },
                set: { context.selection.wrappedValue = $0.isEmpty ? [] : [$0]; context.markDirty() })
    }
    /// MP `playkit-branch`: step title → story body → numbered option lines (pick, can change) → 确认选择 on the bottom
    /// bar (`nativeKitSubmitB`); a single option (a feedback step's 继续) confirms on tap; the end step shows 结局.
    var body: some View {
        Section {
            if let echo = CastBranchEcho(branch: raw) {
                CastBranchEchoLabel(echo: echo, config: cast?.config)
            }
            if let title = raw["currentStep"]["title"].text, !title.isEmpty {
                Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            }
            if let body = raw["currentStep"]["body"].text, !body.isEmpty {
                Text(verbatim: body).font(.body)
            }
        }
        let options = context.projection.options
        let ended = context.projection.complete || raw["currentStep"]["terminal"].bool == true
        if options.isEmpty, !ended {
            ContentUnavailableView("playkit.branch.waiting", systemImage: "arrow.triangle.branch")
                .accessibilityIdentifier("playkit.branch.waiting")
        }
        if !ended, options.count == 1, let only = options.first {
            Section {
                Button {
                    pick.wrappedValue = only.id
                    context.submit("CHOOSE", ["optionId": .string(only.id)])
                } label: {
                    Label { Text(verbatim: only.label) } icon: { Text(verbatim: "1").monospacedDigit() }
                }
                .disabled(!context.enabled)
                .accessibilityLabel(Text(verbatim: only.label))
                .accessibilityIdentifier("playkit.branch.option." + only.id)
            }
        } else if !ended, options.count > 1 {
            Section {
                Picker(selection: pick) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        Text(verbatim: "\(index + 1) · \(option.label)")
                            .accessibilityLabel(Text(verbatim: option.label))
                            .accessibilityIdentifier("playkit.branch.option." + option.id)
                            .tag(option.id)
                    }
                } label: {
                    Text("nativeR2.gamesB.branch.choose")
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(!context.enabled)
            }
        }
        if ended {
            Section {
                Label("playkit.branch.endMark", systemImage: "book.closed")
                    .font(.headline)
                    .accessibilityIdentifier("playkit.branch.ended")
            }
        }
    }
}

// MARK: - musiccorner

@MainActor struct ChoiceMusicCornerKit: View {
    let context: GamesBKitContext
    let mediaScope: UUID
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    private var raw: PlayWireValue { context.segment }
    private func text(_ key: String) -> String? {
        let value = raw[key].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
    /// MP `playkit-musiccorner` body: eyebrow (shell header, MP default 治愈音乐角) · 到点 · title (shell header) → player
    /// (track · time, play / pause, progress) → hint → 继续 (the bottom bar, `nativeKitSubmitB`). Default track 店主的歌单.
    var body: some View {
        Section {
            if raw["arrived"].bool == true {
                Label("playkitLegacy.music.arrived", systemImage: "mappin")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("playkit.musicCorner.arrived")
            }
            LabeledContent {
                if let seconds = raw["durationSeconds"].integer, seconds > 0 {
                    Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60)).monospacedDigit()
                        .accessibilityLabel(Text("playkitLegacy.music.duration"))
                }
            } label: {
                Label {
                    if let track = text("trackName") { Text(verbatim: track).font(.headline) }
                    else { Text("playkit.music.defaultTrack").font(.headline) }
                } icon: { Image(systemName: "music.note") }
            }
            // Existing playback code (play / pause, progress, load failure + retry).
            PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
        } footer: {
            if let hint = text("hint") { Text(verbatim: hint) }
        }
    }
}

// MARK: - dailysign

/// MP `pages/playkit/components/playkit-dailysign`: the slip in MP order — title row (今日城市签 · MM / DD) → 出发
/// address (opens Maps) + the time it was printed | 签号 NO. 0000 + 你是第几位 (only with a server serial) → 留签人 ·
/// 留于 (MP defaults when empty, never a dash) → the previous visitor's photo (only when sent) → 留给你的一句 under
/// the scratch layer → hint 刮开今日签文. The print / tear steps follow the MP's own Reduce Motion path (the slip is
/// already torn). 收下这张签 sits in the shell's bottom bar and unlocks once the line is revealed (`stage` 1);
/// once claimed the line stays revealed, 保存到相册 appears here and 出发 closes the kit (MP `ds__cta`).
@MainActor struct ChoiceDailySignKit: View {
    let context: GamesBKitContext
    /// `PlayKitScreen.profileStep`: 1 once the line is scratched open (read by the bottom bar).
    @Binding var stage: Int
    @State private var shareImage: Image?
    @State private var printedAt = Date()
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var raw: PlayWireValue { context.segment }
    private var lines: [String] { (raw["lines"].array ?? []).compactMap(\.text).filter { !$0.isEmpty } }
    private func text(_ key: String) -> String? {
        let value = (raw[key].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    private var claimed: Bool { text("claimedDate") != nil }
    private var isRevealed: Bool { claimed || stage >= 1 || lines.isEmpty }
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                slip(scratchable: true)
            }
            .accessibilityIdentifier("playkit.dailySign.ticket")
            .sensoryFeedback(.success, trigger: stage >= 1, condition: CYHapticTransition.turnedOn)
            .onChange(of: claimed, initial: true) { _, next in if next { renderShareImage() } }
        } footer: {
            if !isRevealed { Text("playkit.daily.scratchHint") }
        }
        // Kept (owner question 3 is open): the message the app already sends with CLAIM_DAILY_SIGN.
        if !claimed {
            Section {
                TextField("playkit.daily.message", text: context.text, axis: .vertical)
                    .lineLimit(1...4)
                    .submitLabel(.done)
                    .disabled(!context.enabled)
            } footer: {
                Text("playkit.daily.audience")
            }
        }
        // 收下这张签 (CLAIM_DAILY_SIGN) and 出发 are the shell's bottom button (`nativeKitSubmitB`).
        if claimed {
            Section {
                if let rendered = shareImage {
                    ShareLink(item: rendered, preview: SharePreview(Text("playkit.daily.ticketTitle"), image: rendered)) {
                        Label("nativeR2.gamesB.daily.save", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("nativeR2.gamesB.daily.save")
                } else {
                    Label("playkit.daily.saving", systemImage: "hourglass").foregroundStyle(.secondary)
                }
            }
        }
    }

    /// MP `buildDailySign`: 月 / 日 in the service zone (Asia/Shanghai), e.g. 11 / 28.
    private var dateLabel: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let parts = calendar.dateComponents([.month, .day], from: Date())
        return String(format: "%02d / %02d", parts.month ?? 0, parts.day ?? 0)
    }
    /// MP `timeLabel`: the phone's HH:MM when the slip was printed.
    private var timeLabel: String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: printedAt)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
    /// MP: `NO. ` + four digits, only when the server sent a serial above 0.
    private var serialLabel: String? {
        guard let serial = raw["serial"].integer, serial > 0 else { return nil }
        return String(format: "NO. %04d", serial)
    }

    @ViewBuilder private func slip(scratchable: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("playkit.daily.ticketTitle").font(.headline)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: dateLabel).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
        }
        Divider()
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                departure(scratchable: scratchable)
                Spacer(minLength: CYSpacing.md)
                serial(alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                departure(scratchable: scratchable)
                serial(alignment: .leading)
            }
        }
        Divider()
        HStack(alignment: .top, spacing: CYSpacing.md) {
            field("playkit.daily.signer") {
                if let signer = text("signer") { Text(verbatim: signer) } else { Text("playkit.daily.signerDefault") }
            }
            field("playkit.daily.leftAt") {
                if let left = text("leftAt") { Text(verbatim: left).monospacedDigit() } else { Text("playkit.daily.leftAtDefault") }
            }
        }
        if let photo = text("photoUrl") {
            Divider()
            PlayKitArtwork(source: photo, approvedHosts: context.approvedHosts)
                .accessibilityLabel(Text("playkit.daily.photoLabel"))
            HStack {
                if let signer = text("signer") { Text("playkit.daily.photoBy \(signer)") } else { Text("playkit.daily.photoByThem") }
                Spacer(minLength: CYSpacing.sm)
                if let left = text("leftAt") { Text(verbatim: left).monospacedDigit() }
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        if !lines.isEmpty {
            Divider()
            Text("playkit.daily.lineForYou").font(.footnote).foregroundStyle(.secondary)
            if scratchable {
                CYScratchCard(
                    coverLabel: appLocalized("playkit.daily.lineForYou", locale: locale),
                    threshold: 0.45,
                    revealed: isRevealed,
                    onReveal: { _ in withAnimation(CYMotion.resolve(CYMotion.release, reduceMotion: reduceMotion)) { stage = max(stage, 1) } }
                ) { poem }
            } else {
                poem
            }
        }
    }
    private var poem: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(verbatim: line).font(.body) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private func departure(scratchable: Bool) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("playkit.daily.departure").font(.caption).foregroundStyle(.secondary)
            if let address = text("address") {
                if scratchable {
                    Button {
                        MyProjectAddressLink.open(address: address, name: nil, openURL: openURL)
                    } label: {
                        Text(verbatim: address).font(.body).multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("myProject.address.open \(address)"))
                    .accessibilityIdentifier("playkit.dailySign.address")
                } else {
                    Text(verbatim: address).font(.body)
                }
            }
            Text(verbatim: timeLabel).font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private func serial(alignment: HorizontalAlignment) -> some View {
        if let serialLabel {
            VStack(alignment: alignment, spacing: CYSpacing.xs) {
                Text("playkit.daily.serial").font(.caption).foregroundStyle(.secondary)
                Text(verbatim: serialLabel).font(.title2.bold()).monospacedDigit()
                Text("playkit.daily.serialHint").font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
    private func field<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            value().font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    /// The share sheet's "Save Image" replaces the MP canvas poster (`dailysign-poster.js`); same slip, line shown.
    private func renderShareImage() {
        let snapshot = VStack(alignment: .leading, spacing: CYSpacing.md) { slip(scratchable: false) }
            .padding()
            .frame(width: 360)
            .background(Color(uiColor: .systemBackground))
            .environment(\.locale, locale)
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = displayScale
        if let image = renderer.cgImage { shareImage = Image(decorative: image, scale: displayScale) }
    }
}
