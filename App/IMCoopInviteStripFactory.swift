import SwiftUI

/// Builds the value for the `imCoopInviteStrip` environment hook. Without a cooperation reader the strip is
/// absent (the message center keeps its plain list); the strip itself hides when signed out or unconfigured.
enum IMCoopInviteStripFactory {
    @MainActor static func make(reader: (any CooperationReading)?) -> (@MainActor () -> AnyView)? {
        guard PlayerLaunch.merchantCenterEnabled, let reader else { return nil } // Lane G: no coop strip in Release
        return { AnyView(IMCoopInviteStripView(reader: reader)) }
    }
}
