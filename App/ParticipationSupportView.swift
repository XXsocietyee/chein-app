import SwiftUI

struct ParticipationSupportView: View {
    var configuration: ParticipationSupportConfiguration? = nil
    var body: some View {
        Form {
            CYHeroHeader("participationSupport.title")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                G01JourneyNotice(message: Text("participationSupport.purpose"), symbol: "message")
                if let configuration {
                    Link(destination: configuration.url) {
                        Label { Text(verbatim: configuration.name) } icon: { Image(systemName: "arrow.up.right.square") }
                    }.accessibilityIdentifier("participationSupport.open")
                        .cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
                    Text("participationSupport.privacy").cyText(.bodyCompact).foregroundStyle(.secondary)
                } else {
                    Label("participationSupport.notConfigured", systemImage: "message.badge.filled.fill")
                        .cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("participationSupport.notConfigured")
                    Text("participationSupport.configurationBoundary").cyText(.bodyCompact).foregroundStyle(.secondary)
                }
            }
        }.cyHeroScreen()
            .modifier(G01JourneyFormStyle())
    }
}
