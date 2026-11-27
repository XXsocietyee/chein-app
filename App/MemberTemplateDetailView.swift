import SwiftUI

@MainActor struct SessionMemberTemplateDetailView: View {
    let id: MemberPlayTemplateID
    @EnvironmentObject private var session: AppSession
    var body: some View {
        MemberTemplateDetailView(id: id, reader: session.playerJourneyReader)
            .id(session.playerJourneyReader.scope)
    }
}
/// Owned-shelf-only reader. Participation keeps its existing broader member-detail service.
@MainActor struct SessionOwnedMemberTemplateDetailView: View {
    let id: MemberPlayTemplateID
    @EnvironmentObject private var session: AppSession
    var body: some View {
        MemberTemplateDetailView(id: id, reader: session.makeOwnedMemberTemplateReader())
            .id(session.templateShelfViewIdentity)
    }
}
/// A navigation destination rather than an editing sheet: back never commits a draft.
@MainActor struct MemberTemplateDetailView: View {
    let id: MemberPlayTemplateID
    let reader: any MemberTemplateReading
    var imageReader: (any RetainedPublicImageReading)? = nil
    @State private var detail: MemberTemplateDetail?
    @State private var failure: String?
    @State private var message: String?
    @State private var loading = false
    @State private var generation = UUID()
    var body: some View {
        List {
            if loading {
                ProgressView { Text("memberTemplate.loading") }
                    .frame(maxWidth: .infinity)
            }
            if let failure {
                Section {
                    if let message {
                        Label {
                            Text(verbatim: message)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(LocalizedStringKey(failure), systemImage: "exclamationmark.triangle")
                    }
                    Button { Task { await load() } } label: {
                        Label("action.retry", systemImage: "arrow.clockwise")
                    }
                    .disabled(loading)
                }
            }
            if let detail {
                let item = detail.overview
                Section {
                    // One optional image header in the first section, then the title (App Store product page order).
                    if let cover = TemplateBrowserPort.coverURL(detail.gallery.first ?? item.imgUrl), cover.scheme?.lowercased() == "https" {
                        Color.clear
                            .aspectRatio(16.0 / 10.0, contentMode: .fit)
                            .overlay {
                                AsyncImage(url: cover) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() } else { ProgressView() }
                                }
                            }
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        (item.title.isEmpty ? Text("discovery.untitledPlay") : Text(verbatim: item.title))
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let meta = item.description, !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(verbatim: meta)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    DiscoveryPlayMetadata(item: item)
                    if let draft = detail.draftStatus {
                        if draft == 0 {
                            Label("memberTemplate.draft", systemImage: "pencil").foregroundStyle(.secondary)
                        } else if draft == 1 {
                            Label {
                                Text("memberTemplate.published")
                            } icon: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    if let feedback = detail.reviewFeedback {
                        Text("discovery.templateDetail.reviewFeedback \(feedback)")
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("memberTemplate.reviewFeedback")
                    }
                    if !detail.gallery.isEmpty {
                        NativeMediaGalleryEntry(sources: detail.gallery, scope: reader.scope,
                            titleKey: "memberTemplate.title", reader: imageReader)
                        // U02-05: per-image attribution for the first eight; a failed or unreviewed read draws nothing.
                        ForEach(Array(detail.gallery.prefix(8).enumerated()), id: \.offset) { AssetCreditText(reference: $0.element) }
                    }
                }
                textSection("discovery.introduction", value: item.description)
                textSection("discovery.rules", value: item.ruleInstructions)
                textSection("discovery.materials", value: item.requiredMaterials)
                textSection("discovery.location", value: item.usageLocation)
                if let verification = item.verification {
                    Section {
                        Text(verification.label)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text("discovery.verification")
                    }
                }
                if !detail.story.isEmpty {
                    Section {
                        ForEach(detail.story) { part in
                            VStack(alignment: .leading, spacing: 8) {
                                if let tag = part.tag, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Label(tag, systemImage: "tag")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                if let text = part.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(verbatim: text)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                }
                                if !part.images.isEmpty {
                                    NativeMediaGalleryEntry(sources: part.images, scope: reader.scope,
                                        titleKey: "memberTemplate.story", reader: imageReader)
                                }
                            }
                        }
                    } header: {
                        Text("memberTemplate.story")
                    }
                } else { textSection("memberTemplate.story", value: item.storyText) }
                textSection("discovery.creator", value: item.publisher)
            }
        }.listStyle(.insetGrouped).navigationTitle(Text("memberTemplate.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive().accessibilityIdentifier("memberTemplate.detail")
        .task(id: reader.scope) { detail = nil; await load() }
        .refreshable { await load() }
        .onDisappear { generation = UUID(); detail = nil }
        .themeDomain(.player)
    }
    @ViewBuilder private func textSection(_ label: LocalizedStringKey, value: String?) -> some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section {
                Text(verbatim: value)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } header: {
                Text(label)
            }
        }
    }
    private func load() async {
        let request = UUID(); generation = request; let scope = reader.scope
        loading = true; failure = nil; message = nil; detail = nil
        defer { if generation == request { loading = false } }
        do {
            let value = try await reader.memberTemplate(id: id)
            guard !Task.isCancelled, generation == request, reader.scope == scope, value.id == id else { return }
            detail = value
        } catch {
            guard !Task.isCancelled, generation == request, reader.scope == scope else { return }
            if error as? APIError == .unauthorized { failure = "memberTemplate.login" }
            else if error as? APIError == .notConfigured { failure = "memberTemplate.notConfigured" }
            else { failure = "memberTemplate.failed"; message = (error as? PlayerJourneyFailure)?.message }
        }
    }
}
