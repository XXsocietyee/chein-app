import SwiftUI
import UIKit

// MARK: - Emergency help (紧急求助)

/// One-shot, foreground location for 「复制我的位置」. Taken only after the player taps that row;
/// never starts continuous updates; injected via `.environment(\.playEmergencyLocationProvider, …)`.
/// Nil ⇒ the copy row is hidden.
@MainActor protocol PlayEmergencyLocationProviding {
    /// WGS-84 coordinate (CoreLocation), or nil when it could not be taken.
    func currentCoordinate() async -> (latitude: Double, longitude: Double)?
}

private struct PlayEmergencyLocationProviderKey: EnvironmentKey { static let defaultValue: (any PlayEmergencyLocationProviding)? = nil }
extension EnvironmentValues {
    var playEmergencyLocationProvider: (any PlayEmergencyLocationProviding)? {
        get { self[PlayEmergencyLocationProviderKey.self] }
        set { self[PlayEmergencyLocationProviderKey.self] = newValue }
    }
}

/// Mini-program `pages/play/utils/play-sos.js` (T-37): 拨打 110 / 拨打 120 / 复制我的位置.
/// US market dials 911 only. Unknown market ⇒ no dial rows (copy row only, if available).
enum PlayEmergencyHelp {
    static func numbers(for market: RegionalMarket?) -> [String] {
        switch market {
        case .china: return ["110", "120"]
        case .unitedStates: return ["911"]
        case nil: return []
        }
    }
    /// Same text as `locationText`: zh copy + map pin. China uses the Amap marker (WGS-84 flagged),
    /// elsewhere an Apple Maps pin. 0,0 or non-finite ⇒ nil.
    static func locationText(latitude: Double, longitude: Double, market: RegionalMarket?, locale: Locale) -> String? {
        guard latitude.isFinite, longitude.isFinite, !(latitude == 0 && longitude == 0) else { return nil }
        let lat = (latitude * 1e6).rounded() / 1e6, lng = (longitude * 1e6).rounded() / 1e6
        let link = market == .china
            ? "https://uri.amap.com/marker?position=\(lng),\(lat)&coordinate=wgs84"
            : "https://maps.apple.com/?ll=\(lat),\(lng)"
        let format = String(localized: LocalizedStringResource("mpd.sos.locationText %@ %@", locale: locale))
        return String(format: format, "\(lat)", "\(lng)") + " " + link
    }
}

/// `cy-option-sheet title="紧急求助"`, native: a short sheet of large rows. Dialing goes through the
/// system confirmation (`tel:`); the location is copied as plain text the player can paste anywhere.
@MainActor struct PlayEmergencyHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Environment(\.playEmergencyLocationProvider) private var locationProvider
    @State private var copying = false
    @State private var notice: LocalizedStringKey?
    private var market: RegionalMarket? { RegionalLaunchConfiguration.market }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlayEmergencyHelp.numbers(for: market), id: \.self) { number in
                        Button {
                            if let url = URL(string: "tel:" + number) { openURL(url) }
                            dismiss()
                        } label: {
                            Label { Text("mpd.sos.call \(number)") } icon: { Image(systemName: "phone.fill") }
                                .cyText(.bodyMedium).foregroundStyle(CYColor.dangerText)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityIdentifier("play.sos.call.\(number)")
                    }
                    if locationProvider != nil {
                        Button { Task { await copyLocation() } } label: {
                            HStack {
                                Label("mpd.sos.copyLocation", systemImage: "location.fill")
                                    .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                if copying { ProgressView() }
                            }.frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .disabled(copying)
                        .accessibilityIdentifier("play.sos.copyLocation")
                    }
                } footer: {
                    if let notice {
                        Text(notice).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("play.sos.notice")
                    } else {
                        Text("mpd.sos.footer").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    }
                }
            }
            .navigationTitle(Text("mpd.sos.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
            }
        }
        .cySheet(detents: [.medium])
        .sensoryFeedback(.success, trigger: notice) { _, new in new == "mpd.sos.copied" }
        .accessibilityIdentifier("play.sos.sheet")
    }

    private func copyLocation() async {
        guard let locationProvider, !copying else { return }
        copying = true; defer { copying = false }
        guard let coordinate = await locationProvider.currentCoordinate(),
              let text = PlayEmergencyHelp.locationText(latitude: coordinate.latitude, longitude: coordinate.longitude, market: market, locale: locale) else {
            notice = "mpd.sos.noLocation"; return
        }
        LocalPasteboard.copy(text)
        notice = "mpd.sos.copied"
    }
}

// MARK: - Chapter picker (切换章节)

/// Per-chapter facts for the 章节选择 sheet (mini-program `chpick`): completed / locked / open, node count.
struct PlayChapterPickRow: Identifiable, Equatable {
    enum State: String { case open, completed, locked }
    let id: Int
    let title: String?
    let nodeCount: Int
    let state: State

    static func rows(_ snapshot: PlaySnapshot) -> [PlayChapterPickRow] {
        snapshot.result.chapters.map { chapter in
            let nodes = snapshot.visibleNodes.filter { $0.chapterID == chapter.id }
            let state: State = !nodes.isEmpty && nodes.allSatisfy(snapshot.isLocked) ? .locked
                : (!nodes.isEmpty && nodes.allSatisfy(snapshot.isDone) ? .completed : .open)
            return .init(id: chapter.id, title: chapter.name, nodeCount: nodes.count, state: state)
        }
    }
}

/// Mini-program `.chpick`: a list of chapters, the current one checked, completed ones marked
/// 「已完成 · N 处地点」, locked ones dimmed and not selectable. Still reachable after the run is
/// complete (f-play V3-08: 走完后回看换章). Picking narrows the place list to that chapter.
@MainActor struct PlayChapterPickerSheet: View {
    let rows: [PlayChapterPickRow]
    let current: Int?
    let onPick: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { onPick(nil); dismiss() } label: {
                        row(title: Text("mpd.chapters.all"), subtitle: Text("mpd.chapters.allSub \(rows.reduce(0) { $0 + $1.nodeCount })"), selected: current == nil)
                    }
                    .accessibilityIdentifier("play.chapterPick.all")
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                        Button { onPick(item.id); dismiss() } label: {
                            row(title: item.title.map { Text(verbatim: $0) } ?? Text("mpd.chapters.number \(index + 1)"),
                                subtitle: subtitle(item), selected: current == item.id, locked: item.state == .locked)
                        }
                        .disabled(item.state == .locked)
                        .accessibilityValue(Text(LocalizedStringKey("mpd.chapters.state." + item.state.rawValue)))
                        .accessibilityIdentifier("play.chapterPick.\(item.id)")
                    }
                }
            }
            .navigationTitle(Text("mpd.chapters.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } } }
        }
        .cySheet()
    }

    private func subtitle(_ item: PlayChapterPickRow) -> Text {
        switch item.state {
        case .completed: return Text("mpd.chapters.completedSub \(item.nodeCount)")
        case .locked: return Text("mpd.chapters.lockedSub \(item.nodeCount)")
        case .open: return Text("mpd.chapters.openSub \(item.nodeCount)")
        }
    }

    private func row(title: Text, subtitle: Text, selected: Bool, locked: Bool = false) -> some View {
        HStack(spacing: CYSpacing.md) {
            Image(systemName: locked ? "lock.fill" : "book.pages")
                .foregroundStyle(locked ? CYColor.textTertiary : CYColor.textSecondary).frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                title.cyText(.bodyMedium).foregroundStyle(locked ? CYColor.textTertiary : CYColor.textPrimary)
                subtitle.cyText(.meta).foregroundStyle(CYColor.textTertiary).monospacedDigit()
            }
            Spacer(minLength: CYSpacing.sm)
            if selected { Image(systemName: "checkmark").font(CYTypography.label).foregroundStyle(CYColor.brand).accessibilityHidden(true) }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Tools menu

/// Mini-program 游玩工具层 (`sessionTools`): 切换章节 (free exploration, or city orientation with more
/// than one chapter) and 紧急求助 (hidden in preview). One toolbar menu so the glass controls stay at three.
@MainActor struct PlayToolsMenu: View {
    let showsChapters: Bool
    let showsEmergency: Bool
    let openChapters: () -> Void
    let openEmergency: () -> Void
    /// PLAY-3: MP 游玩工具 扫码到达 (`onScanArriveFromTools`, mode != 2). Opens the current stop, whose scan task
    /// owns the camera and the `api/play/checkin` write. nil hides the row (no single current stop).
    var openScanArrival: (() -> Void)? = nil
    var body: some View {
        if showsChapters || showsEmergency || openScanArrival != nil {
            Menu {
                if let openScanArrival {
                    Button(action: openScanArrival) { Label("play.tools.scanArrive", systemImage: "qrcode.viewfinder") }
                        .accessibilityHint(Text("play.tools.scanArrive.hint"))
                        .accessibilityIdentifier("play.tools.scanArrive")
                }
                if showsChapters {
                    Button(action: openChapters) { Label("mpd.chapters.switch", systemImage: "book.pages") }
                        .accessibilityIdentifier("play.tools.chapters")
                }
                if showsEmergency {
                    Button(role: .destructive, action: openEmergency) { Label("mpd.sos.title", systemImage: "exclamationmark.triangle.fill") }
                        .accessibilityIdentifier("play.tools.sos")
                }
            } label: {
                Label("mpd.tools.title", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("play.tools")
        }
    }
}
