import SwiftUI

/// Maps a `cyToast` call to a `.status` island: same text, tone and optional undo; the island's 4 s lifetime
/// (or the call's longer duration) replaces the pill's timer.
@MainActor enum CYToastIslandBridge {
    static func post(_ text: IslandText, tone: CYToastTone, undoTitle: LocalizedStringKey?, duration: Double,
                     onUndo: (() -> Void)?) {
        var actions: [IslandAction] = []
        if let undoTitle, let onUndo {
            actions.append(IslandAction(title: .localized(undoTitle), systemImage: "arrow.uturn.backward", prominent: true) { onUndo() })
        }
        let seconds = max(4, duration.isFinite ? duration : 4)
        IslandCenter.shared.show(IslandItem(kind: .status(islandTone(tone)), title: text,
                                            systemImage: tone == .undoable ? tone.systemImage : nil,
                                            actions: actions,
                                            lifetime: .milliseconds(Int(seconds * 1000)),
                                            startsExpanded: !actions.isEmpty))
    }

    static func islandTone(_ tone: CYToastTone) -> IslandTone {
        switch tone {
        case .info, .undoable: return .info
        case .success: return .success
        case .warning: return .warning
        }
    }
}
