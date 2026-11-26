import SwiftUI

/// MC8-01-1 / MC8-01-6 (pages/merchant/index/index.wxml:145-215): the workbench 项目 row — a horizontal strip of the
/// first open projects (status, type, N 张待核销, title, place), 全部 N → 项目 list, and the cy_logo_mark cover when a
/// project has no image. It reads `merchantProjects(access:)` (the read the 项目 list already uses) once per
/// workbench reload; a failed read leaves the section out (MP: errors stay blank, no orphan title).
/// Cover uses `imgUrl` / `topicImgUrl`. The visit line is the upcoming-runs read (verify-record permission).
struct MerchantWorkbenchProjectCards<Reader: MerchantReading>: View {
    @ObservedObject var reader: Reader
    let access: MerchantAccess
    let reloadKey: UInt64
    let allProjects: () -> AnyView
    @State private var page: MerchantProjectPage?
    @State private var visits: [MerchantUpcomingRun] = []
    @State private var loading = false

    private static var visibleLimit: Int { 4 }

    var body: some View {
        Group {
            if let page, !page.rows.isEmpty {
                let cards = Array(page.rows.prefix(Self.visibleLimit))
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CYSpacing.sm) {
                            ForEach(cards) { project in
                                NavigationLink { allProjects() } label: { card(project) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("merchant.workbench.project.\(project.id)")
                            }
                            if page.total > cards.count {
                                NavigationLink { allProjects() } label: { moreCard(page.total - cards.count) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("merchant.workbench.projects.more")
                            }
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.md, bottom: 0, trailing: CYSpacing.md))
                } header: {
                    HStack {
                        Text("merchantR8.projects.title")
                        Spacer()
                        NavigationLink { allProjects() } label: { Text("merchantR8.projects.all \(page.total)") }
                            .accessibilityIdentifier("merchant.workbench.projects.all")
                    }
                }
            } else if page == nil && loading {
                Section { CYSkeleton(variant: .card) }
            }
        }
        .task(id: reloadKey) { await load() }
    }

    private func load() async {
        guard access.active, access.allows(.projects) else { page = nil; return }
        loading = true
        defer { loading = false }
        do {
            let value = try await reader.merchantProjects(access: access)
            guard !Task.isCancelled else { return }
            page = value
            if access.allows(.verifyRecordRead) {
                visits = (try? await reader.merchantUpcomingRuns(access: access)) ?? []
            } else { visits = [] }
        } catch {
            guard !Task.isCancelled else { return }
            page = nil
        }
    }

    private func card(_ project: MerchantProject) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(CYColor.bgRaised)
                if let thumb = project.thumb {
                    CYCachedAsyncImage(thumb, role: .cover)
                        .frame(width: 200, height: 150)
                        .clipped()
                        .accessibilityHidden(true)
                } else {
                    MPAsset.BrandLogo.cyLogoMark.resizable().scaledToFit().padding(28).opacity(0.35)
                        .accessibilityHidden(true)
                }
                HStack {
                    if let state = project.stateText ?? project.acceptStatusText, !state.isEmpty {
                        CYStatusChip(verbatim: state, tone: .neutral)
                    }
                    Spacer(minLength: 0)
                    if let type = project.projectTypeText, !type.isEmpty {
                        CYStatusChip(verbatim: type, tone: .neutral)
                    }
                }
                .padding(CYSpacing.xs)
            }
            .frame(width: 200, height: 150)
            if let pending = project.pendingVerifyCount, pending > 0 {
                Text("merchantR8.projects.pending \(pending > 99 ? "99+" : String(pending))")
                    .cyText(.caption).foregroundStyle(CYColor.brandStrong)
            }
            Text(verbatim: project.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(1)
            if let place = project.addressName, !place.isEmpty {
                Text(verbatim: place).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1)
            }
            if let topic = project.visitTopicID,
               let visit = MerchantUpcomingVisit.line(runs: visits, topicID: topic, roleJoin: project.isJoinCard),
               !visit.isEmpty {
                Text(verbatim: visit).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(2)
            }
        }
        .frame(width: 200, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func moreCard(_ remaining: Int) -> some View {
        VStack(spacing: CYSpacing.xxs) {
            Text(verbatim: "+\(remaining)").cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
            Text("merchantR8.projects.more").cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        .frame(width: 120, height: 150)
        .background(RoundedRectangle(cornerRadius: 12).fill(CYColor.bgRaised))
        .accessibilityElement(children: .combine)
    }
}
