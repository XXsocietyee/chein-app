import SwiftUI

/// Public-library prose and two-image preview only; the owner namespace has its
/// own view. The injected reader remains disabled by default in normal composition.
@MainActor struct DiscoveryPlayTemplatePresentationView: View {
    let presentation: DiscoveryPlayTemplatePresentation
    let scope: UUID
    let imageReader: any RetainedPublicImageReading
    /// The detail head (B57 `xb-head`) already names the publisher; it passes false to avoid a second row.
    var showsPublisher = true
    /// mp-r3-publish: MP templatedetail puts the image mosaic first and 创作者说 near the end (before 评价), so the
    /// detail renders `.media` and `.story` at those two places. `.all` keeps everything together.
    enum Part { case all, media, story }
    var part: Part = .all

    var body: some View {
        if part != .story { mediaSections }
        if part != .media { storySection }
    }

    @ViewBuilder private var mediaSections: some View {
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
    }

    @ViewBuilder private var storySection: some View {
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
