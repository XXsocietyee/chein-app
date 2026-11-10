#if DEBUG
import SwiftUI

/// Registered by the host's offline --uitesting-module objectCards branch only.
@MainActor struct ObjectCardFixtureHostView: View {
    @State private var reader = ObjectCardFixtureReader()
    @State private var revision = 0
    var body: some View {
        NavigationStack {
            ObjectCardsView(reader: reader)
                .id("\(revision)-\(reader.scope)")
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        Text("objects.offline").font(.caption)
                        HStack {
                            CYPillButton(verbatim: "Fail next read", style: .tertiary, fullWidth: false) { reader.failNext = true }.accessibilityIdentifier("objects.fixture.fail")
                            CYPillButton(verbatim: "Change session", style: .tertiary, fullWidth: false) { reader.rotateScope(); revision += 1 }.accessibilityIdentifier("objects.fixture.session")
                            CYPillButton(verbatim: "Deny next read", style: .tertiary, fullWidth: false) { reader.denyNext = true }.accessibilityIdentifier("objects.fixture.deny")
                        }.font(.caption)
                    }.padding(8).background(.regularMaterial)
                }
        }
    }
}
#endif
