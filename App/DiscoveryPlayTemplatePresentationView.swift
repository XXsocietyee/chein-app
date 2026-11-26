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
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("discovery.template.publisherValue")
            } header: {
                DiscoverySectionHeader("discovery.template.publisher")
            }
            .discoveryCardRow()
        }
        if presentation.useCount != nil {
            Section {
                LabeledContent("discovery.template.useCount", value: presentation.useCountText)
                    .monospacedDigit()
                    .accessibilityIdentifier("discovery.template.useCount")
            }
            .discoveryCardRow()
        }
        if !presentation.gallerySources.isEmpty {
            Section {
                NativeMediaGalleryEntry(sources: presentation.gallerySources, scope: scope,
                                        titleKey: "discovery.template.images", reader: imageReader)
            } header: {
                DiscoverySectionHeader("discovery.template.images")
            }
            .discoveryCardRow()
        }
        if presentation.hasStory {
            Section {
                if let text = presentation.storyText {
                    Text(verbatim: text)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("discovery.template.storyText")
                    }
                if presentation.storyImage != nil {
                    Text("discovery.template.storyImageInGallery")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("discovery.template.storyImage")
                    }
            } header: {
                // Round 4 image parity: MP 创作者说 header art (templatedetail.wxml:196 `art/3d/bulb.png`).
                DiscoverySectionHeader("discovery.template.story", art: MPAsset.FeatureIcon.bulb)
            }
            .discoveryCardRow()
        }
    }
}
