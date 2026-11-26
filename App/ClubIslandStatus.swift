import SwiftUI

/// G-037 (design P1, L7): club, team and cooperation notices go to the top island (`IslandCenter`, native r2 M4) as
/// `.status` items with their real tone (failures read as errors, not as a neutral pill). The binding is handed to the
/// island and cleared, exactly as `cyToast` cleared it. One dedupe key per surface, so a second notice from the same
/// screen updates the card in place instead of queueing behind it. With `nativeR2.island` off, the old bottom pill
/// (`cyToast`) is unchanged. VoiceOver: `IslandOverlay` posts the announcement for every presentation.
private struct ClubIslandStatusModifier: ViewModifier {
    @Binding var message: LocalizedStringKey?
    let tone: IslandTone
    let surface: String

    @ViewBuilder func body(content: Content) -> some View {
        if IslandCenter.isEnabled {
            content.onChange(of: message, initial: true) { _, next in
                guard let next else { return }
                IslandCenter.shared.show(IslandItem(kind: .status(tone), title: .localized(next),
                                                    dedupeKey: "club.status." + surface))
                message = nil
            }
        } else {
            content.cyToast(message: $message, tone: ClubIslandStatusTone.toast(tone))
        }
    }
}

private struct ClubIslandVerbatimStatusModifier: ViewModifier {
    @Binding var message: String?
    let tone: IslandTone
    let surface: String

    @ViewBuilder func body(content: Content) -> some View {
        if IslandCenter.isEnabled {
            content.onChange(of: message, initial: true) { _, next in
                guard let next, !next.isEmpty else { return }
                IslandCenter.shared.show(IslandItem(kind: .status(tone), title: .verbatim(next),
                                                    dedupeKey: "club.status." + surface))
                message = nil
            }
        } else {
            content.cyToast(verbatimMessage: $message, tone: ClubIslandStatusTone.toast(tone))
        }
    }
}

enum ClubIslandStatusTone {
    /// The bottom pill has no error tone; a failure keeps its warning look there.
    static func toast(_ tone: IslandTone) -> CYToastTone {
        switch tone {
        case .info: return .info
        case .success: return .success
        case .warning, .error: return .warning
        }
    }

    /// Result keys that name a failure read as errors on the island.
    static func forResultKey(_ key: String) -> IslandTone {
        let lowered = key.lowercased()
        if lowered.contains("fail") || lowered.contains("error") { return .error }
        return .success
    }
}

extension View {
    /// A club / team / cooperation notice on the top island (`.cyToast` fallback while the island flag is off).
    func clubIslandStatus(message: Binding<LocalizedStringKey?>, tone: IslandTone = .info, surface: String) -> some View {
        modifier(ClubIslandStatusModifier(message: message, tone: tone, surface: surface))
    }

    /// The same for an already localized runtime string.
    func clubIslandStatus(verbatimMessage: Binding<String?>, tone: IslandTone = .info, surface: String) -> some View {
        modifier(ClubIslandVerbatimStatusModifier(message: verbatimMessage, tone: tone, surface: surface))
    }
}
