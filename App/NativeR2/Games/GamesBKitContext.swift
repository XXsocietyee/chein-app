import SwiftUI

/// Native r2 games-b (templates 4-6: Camera, Chance, Story choice).
///
/// The minimal host contract the B kits are written against until the shared
/// `NativeGameShell` (games-a lane) lands. It carries only what the existing
/// `PlayKitScreen` already owns: the segment, the projection, the interaction gate,
/// the selection state and the single review outlet (`prepare`). No new request,
/// no new scoring: every kit calls `prepare` with the same action and payload as before.
@MainActor struct GamesBKitContext {
    let kind: PlayKitScreenKind
    let segment: PlayWireValue
    let projection: PlayKitScreenProjection
    /// `PlayKitScreen.enabled`: the model can interact, the kit is open and no review is up.
    let enabled: Bool
    /// The server is working on the last write (`model.phase == "submitting"`).
    let busy: Bool
    let approvedHosts: Set<String>
    /// Single-choice selection shared with the shell (`PlayKitScreen.selected`).
    let selection: Binding<Set<String>>
    /// Free text shared with the shell (`PlayKitScreen.textBinding`).
    let text: Binding<String>
    let markDirty: () -> Void
    /// The frozen review outlet. Same signature as `PlayKitReviewRequest`.
    let prepare: PlayKitReviewRequest

    func submit(_ action: String, _ payload: [String: PlayWireValue] = [:]) {
        prepare(action, payload, {})
    }
}

extension PlayKitScreen {
    /// Built from the existing screen state; nothing here is new state.
    var gamesBContext: GamesBKitContext {
        GamesBKitContext(
            kind: kind,
            segment: raw,
            projection: projection,
            enabled: enabled,
            busy: model.phase == "submitting",
            approvedHosts: approvedArtworkHosts,
            selection: $selected,
            text: textBinding(limit: kind == .dailySign ? PlayKitShortMessageLimit.resolve(raw["textMax"]) : 4096),
            markDirty: { dirty = true },
            prepare: { action, payload, completion in prepare(action, payload, completion) }
        )
    }
}
