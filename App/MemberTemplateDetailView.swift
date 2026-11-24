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
                CYSkeleton()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("memberTemplate.loading"))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
            }
            if let failure {
                Section {
                    if let message {
                        Text(verbatim: message)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(failure), kind: .failure)
                    }
                    CYPillButton("action.retry", systemImage: "arrow.clockwise") { Task { await load() } }
                        .disabled(loading)
                        .e1ActionRow()
                }
            }
            if let detail {
                let item = detail.overview
                Section {
                    CYImageCard(
                        verbatim: item.title,
                        fallback: "discovery.untitledPlay",
                        meta: item.description,
                        imageURL: TemplateBrowserPort.coverURL(detail.gallery.first ?? item.imgUrl)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                    DiscoveryPlayMetadata(item: item)
                    if let draft = detail.draftStatus {
                        if draft == 0 { CYStatusChip("memberTemplate.draft", tone: .neutral, systemImage: "pencil") }
                        else if draft == 1 { CYStatusChip("memberTemplate.published", tone: .success, systemImage: "checkmark.circle.fill") }
                    }
                    if let feedback = detail.reviewFeedback {
                        Text("discovery.templateDetail.reviewFeedback \(feedback)")
                            .cyText(.body)
                            .foregroundStyle(CYColor.warningText)
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
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        CYSectionHeader("discovery.verification")
                    }
                }
                if !detail.story.isEmpty {
                    Section {
                        ForEach(detail.story) { part in
                            VStack(alignment: .leading, spacing: CYSpacing.md) {
                                if let tag = part.tag, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    CYStatusChip(verbatim: tag, tone: .neutral, systemImage: "tag")
                                }
                                if let text = part.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(verbatim: text)
                                        .cyText(.body)
                                        .foregroundStyle(CYColor.textPrimary)
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
                        CYSectionHeader("memberTemplate.story")
                    }
                } else { textSection("memberTemplate.story", value: item.storyText) }
                textSection("discovery.creator", value: item.publisher)
            }
        }.listStyle(.insetGrouped).cyGroupedSurface().navigationTitle(Text("memberTemplate.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive().accessibilityIdentifier("memberTemplate.detail")
        .task(id: reader.scope) { detail = nil; await load() }
        .refreshable { await load() }
        .onDisappear { generation = UUID(); detail = nil }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private func textSection(_ label: LocalizedStringKey, value: String?) -> some View {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section {
                Text(verbatim: value)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } header: {
                CYSectionHeader(label)
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
