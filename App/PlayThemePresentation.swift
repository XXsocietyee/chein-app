import SwiftUI

/// Theme-level facts the mini-program reads from `/api/play/nodes` (`topicAiGenerated`, `topicCover`,
/// `productType`) and `cms_topic.look_json`, injected via `.environment(\.playThemePresentationReader, …)`.
/// Absent reader / absent fact ⇒ the native screen behaves as before (no look, no AI label, pack shown).
struct PlayThemePresentationFacts: Equatable {
    /// `look_json` → `CYThemeLook(style:palette:neon:)`; nil = legacy look.
    var look: CYThemeLook?
    /// `topicAiGenerated === true` (backend AigcLabel: publishMode == ai_simple).
    var aiGenerated = false
    /// `productType`; anything other than 2 (free exploration pack product) skips the card pack.
    var productType: Int?
    /// Cover behind the opening title card (`topicCover || chapter.cover`).
    var coverURL: URL?

    /// Mini-program `skipPack = d.productType !== undefined && d.productType !== 2`.
    var skipsCardPack: Bool { productType.map { $0 != 2 } ?? false }
}

@MainActor protocol PlayThemePresentationReading {
    func facts(topicID: Int) -> PlayThemePresentationFacts?
}

private struct PlayThemePresentationReaderKey: EnvironmentKey { static let defaultValue: (any PlayThemePresentationReading)? = nil }
extension EnvironmentValues {
    var playThemePresentationReader: (any PlayThemePresentationReading)? {
        get { self[PlayThemePresentationReaderKey.self] }
        set { self[PlayThemePresentationReaderKey.self] = newValue }
    }
}

enum PlayThemeCoverResolver {
    /// One chain with station art: a chapter image, then the route cover. The title card
    /// still prefers `PlayThemeServerFacts.coverURL` when the reader already resolved one.
    static func url(chapterCover: String?, topicCover: String?) -> URL? {
        let image = PlayStationImageResolver.station(stationImage: nil, chapterImages: PlayStationImageResolver.list(chapterCover), routeCover: topicCover)
        guard let source = image.source else { return nil }
        return PlayThemeServerFacts.coverURL(PlayStationImageResolver.secured(source))
    }
}

enum PlayThemeIntro {
    /// Mini-program `introLine`: first authored line, first sentence, ≤ 40 characters, trailing separators trimmed.
    static func line(_ description: String?) -> String {
        let first = (description ?? "").split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        let text = first.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard let range = text.range(of: "^[^。！？!?]{1,40}[。！？!?]?", options: .regularExpression) else { return "" }
        return String(text[range]).replacingOccurrences(of: "[\\s｜|·、，,：:；;—-]+$", with: "", options: .regularExpression)
    }
}

/// Mini-program `.st-intro` 主题开场标题卡: full-screen cover, kicker 「城瘾 · 城市定向 · AI 生成」,
/// topic title (≤ 2 lines), intro line, one 「开始游戏」 button. Shown once per topic on this device.
/// Look-aware; the cover is dimmed and blurred as in the prototype. Reduce Motion: fade only.
@MainActor struct PlayThemeTitleCard: View {
    let title: String
    let line: String
    let modeKey: LocalizedStringKey
    let aiGenerated: Bool
    var coverURL: URL?
    let onStart: () -> Void
    @Environment(\.cyThemeLook) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let colors = look?.colors ?? CYThemeLook.legacyColors
        ZStack {
            colors.bg.swiftUIColor.ignoresSafeArea()
            if let coverURL {
                AsyncImage(url: coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .opacity(0.55).blur(radius: 2).saturation(0.5)
                .ignoresSafeArea()
                .overlay(LinearGradient(colors: [colors.bg.swiftUIColor.opacity(0.2), colors.bg.swiftUIColor.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                Spacer()
                HStack(spacing: 0) {
                    Text("mpd.titleCard.brand")
                    Text(verbatim: " · ")
                    Text(modeKey)
                    if aiGenerated {
                        Text(verbatim: " · ")
                        Text("mpd.aigc.label").accessibilityIdentifier("play.titleCard.aigc")
                    }
                }
                .cyText(.caption)
                .foregroundStyle(colors.mute.swiftUIColor)
                .offset(y: shown || reduceMotion ? 0 : 12).opacity(shown ? 1 : 0)
                Text(verbatim: title)
                    .cyText(.display).lineLimit(2).minimumScaleFactor(0.8)
                    .cyLookTitle()
                    .foregroundStyle(look == nil ? colors.ink.swiftUIColor : (look?.style == .cyber ? colors.a.swiftUIColor : colors.ink.swiftUIColor))
                    .accessibilityAddTraits(.isHeader)
                    .offset(y: shown || reduceMotion ? 0 : 18).opacity(shown ? 1 : 0)
                if !line.isEmpty {
                    Text(verbatim: line).cyText(.body)
                        .foregroundStyle(colors.mute.swiftUIColor)
                        .offset(y: shown || reduceMotion ? 0 : 18).opacity(shown ? 1 : 0)
                }
                Spacer()
                Button(action: onStart) { Text("mpd.titleCard.start") }
                    .buttonStyle(CYLookButtonStyle(kind: .primary))
                    .accessibilityIdentifier("play.titleCard.start")
                    .opacity(shown ? 1 : 0)
            }
            .padding(.horizontal, CYSpacing.xxl).padding(.bottom, CYSpacing.xl)
        }
        .foregroundStyle(colors.ink.swiftUIColor)
        .environment(\.colorScheme, look?.colorScheme ?? .dark)
        .onAppear {
            withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance.delay(0.1)) { shown = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("play.titleCard")
    }
}

/// Per-device memory of title cards already shown (mini-program `storyResume.intro`).
enum PlayThemeTitleCardMemory {
    private static let key = "cy_playTitleCardSeen"
    static func seen(_ topicID: Int) -> Bool {
        (UserDefaults.standard.array(forKey: key) as? [Int])?.contains(topicID) ?? false
    }
    static func markSeen(_ topicID: Int) {
        var ids = (UserDefaults.standard.array(forKey: key) as? [Int]) ?? []
        guard !ids.contains(topicID) else { return }
        ids.append(topicID)
        UserDefaults.standard.set(Array(ids.suffix(200)), forKey: key)
    }
}

// MARK: - 再玩一次 (post-clear replay)

/// Mini-program finish sheet / `cy-theme-records`: 「再玩一次」 when the server says `replayAllowed === true`.
/// Nil, or `allowed == false`, keeps the button hidden. A false `replay()` is an unconfirmed outcome.
@MainActor protocol PlayThemeReplayBinding: AnyObject {
    var allowed: Bool { get }
    /// True while a saved request id is still unconfirmed. The visible unknown mark is an em dash.
    var showsUnknown: Bool { get }
    /// Loads `replayAllowed` for this finish-sheet session.
    func focus(sessionID: Int) async -> Bool
    /// Posts only when that session is still allowed. Returns true only after the read-back matches.
    func replay() async -> Bool
}

private struct PlayThemeReplayKey: EnvironmentKey { static let defaultValue: (any PlayThemeReplayBinding)? = nil }
extension EnvironmentValues {
    var playThemeReplay: (any PlayThemeReplayBinding)? {
        get { self[PlayThemeReplayKey.self] }
        set { self[PlayThemeReplayKey.self] = newValue }
    }
}

@MainActor struct PlayThemeReplayButton: View {
    var sessionID: Int
    @Environment(\.playThemeReplay) private var binding
    @State private var allowed = false
    @State private var busy = false
    @State private var unconfirmed = false
    var body: some View {
        Group {
            if allowed {
                Button {
                    guard !busy, let binding else { return }
                    Task {
                        busy = true
                        let confirmed = await binding.replay()
                        unconfirmed = !confirmed && binding.showsUnknown
                        allowed = binding.allowed
                        busy = false
                    }
                } label: {
                    Label(LocalizedStringKey(busy ? "mpd.replay.busy" : "mpd.replay.title"), systemImage: "arrow.counterclockwise")
                }
                .disabled(busy)
                .accessibilityIdentifier("playx.themeRecords.replay")
                if unconfirmed {
                    Text("mpd.replay.unknown")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.warningText)
                        .accessibilityLabel(Text("mpd.replay.unconfirmed"))
                }
            }
        }
        .task(id: sessionID) { await load() }
    }

    func load() async {
        guard sessionID > 0, let binding else { allowed = false; unconfirmed = false; return }
        allowed = await binding.focus(sessionID: sessionID)
        unconfirmed = binding.showsUnknown
    }
}
