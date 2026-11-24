import SwiftUI

/// Public-library prose and two-image preview only; the owner namespace has its
/// own view. The injected reader remains disabled by default in normal composition.
@MainActor struct DiscoveryPlayTemplatePresentationView: View {
    let presentation: DiscoveryPlayTemplatePresentation
    let scope: UUID
    let imageReader: any RetainedPublicImageReading
    /// The detail head (B57 `xb-head`) already names the publisher; it passes false to avoid a second row.
    var showsPublisher = true

    var body: some View {
        if showsPublisher, let publisher = presentation.publisher {
            Section {
                Text(verbatim: publisher)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("discovery.template.publisherValue")
                    .discoveryPresentationRow()
            } header: {
                DiscoverySectionHeader("discovery.template.publisher")
            }
            .discoveryCardRow()
        }
        if presentation.useCount != nil {
            Section {
                LabeledContent("discovery.template.useCount", value: presentation.useCountText)
                    .cyText(.numericBody)
                    .monospacedDigit()
                    .accessibilityIdentifier("discovery.template.useCount")
                    .discoveryPresentationRow()
            }
            .discoveryCardRow()
        }
        if !presentation.gallerySources.isEmpty {
            Section {
                NativeMediaGalleryEntry(sources: presentation.gallerySources, scope: scope,
                                        titleKey: "discovery.template.images", reader: imageReader)
                    .discoveryPresentationRow()
            } header: {
                DiscoverySectionHeader("discovery.template.images")
            }
            .discoveryCardRow()
        }
        if presentation.hasStory {
            Section {
                if let text = presentation.storyText {
                    Text(verbatim: text)
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("discovery.template.storyText")
                        .discoveryPresentationRow()
                }
                if presentation.storyImage != nil {
                    Text("discovery.template.storyImageInGallery")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("discovery.template.storyImage")
                        .discoveryPresentationRow()
                }
            } header: {
                DiscoverySectionHeader("discovery.template.story")
            }
            .discoveryCardRow()
        }
    }
}

private extension View {
    /// 16pt gutters inside the parent detail list. Replaces the row inset; it does not add a second title.
    func discoveryPresentationRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
    }
}
