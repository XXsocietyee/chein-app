import SwiftUI

/// The whole destination owns its reader; list-row recycling cannot retire the profile.
@MainActor struct ProfilePublicInfoHost<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var reader: ProfilePublicInfoReader?
    private let content: (ProfilePublicInfoReader) -> Content
    init(reader: ProfilePublicInfoReader?, @ViewBuilder content: @escaping (ProfilePublicInfoReader) -> Content) {
        _reader = State(initialValue: reader); self.content = content
    }
    /// A pushed profile is on screen during an inactive navigation transition.
    /// Only a real background scene stops the independent public-info read.
    private var pageIsForeground: Bool { scenePhase != .background }
    var body: some View {
        ZStack {
            if let reader {
                if reader.hasAppeared {
                    content(reader)
                        .onAppear { reader.appear(foreground: pageIsForeground) }
                        .onDisappear { reader.disappear() }
                } else { ProgressView() }
            } else { SocialIssueView(error: APIError.unauthorized) }
        }
        .task { reader?.appear(foreground: pageIsForeground) }
        .onAppear { reader?.appear(foreground: pageIsForeground) }
        .onDisappear { reader?.disappear() }
        .onChange(of: scenePhase) { _, phase in reader?.setForeground(phase != .background) }
        .refreshable { reader?.requestRefresh() }
    }
}
