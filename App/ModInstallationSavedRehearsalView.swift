import SwiftUI

func installedRehearsalLocalized(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "installedRehearsal." + key), table: "InstalledDraftRehearsal", locale: locale))
}

/// A sheet over the same editor, never a replacement editor or installed runtime.
@MainActor struct ModInstallationSavedRehearsalView: View {
    let rehearsal: ModInstallationSavedRehearsal
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var heroArtHeight: CGFloat = 160
    private func text(_ key: String) -> String { installedRehearsalLocalized(key, locale: locale) }
    private func shown(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
    }
    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = rehearsal.snapshot {
                    if rehearsal.started { started(snapshot) } else { review(snapshot) }
                } else { unavailable }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(text("return")) { rehearsal.retire(); dismiss() }
                    .accessibilityIdentifier("installedRehearsal.return")
            } }
        }
        .privacySensitive()
        .accessibilityIdentifier("installedRehearsal.root")
        .onAppear { if scenePhase == .active { rehearsal.appear() } else { rehearsal.retire() } }
        .onDisappear { rehearsal.retire() }
        .task {
            // Observe local lease/grant expiry even while the user is idle.
            // No network refresh, license polling or draft writes occur here.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard rehearsal.available else { rehearsal.retire(); return }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { rehearsal.retire() } }
        .onChange(of: rehearsal.available) { _, available in if !available { rehearsal.retire() } }
    }

    /// The embedded rehearsal sets its own bar title. This screen keeps that title and does not add a second one.
    private func started(_ snapshot: ModInstallationSavedRehearsalSnapshot) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: text("boundary"))
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, CYSpacing.pageHorizontal)
            Text(verbatim: "#\(snapshot.saved.templateId) · \(shown(snapshot.saved.draftContentHash))")
                .cyText(.meta).monospaced()
                .foregroundStyle(CYColor.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, CYSpacing.pageHorizontal)
            TemplateCreatorRehearsalView(draft: snapshot.advanced, family: .branch,
                branchAdmission: { rehearsal.admitBranch() }, showsReview: false)
                .id(rehearsal.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgPage.ignoresSafeArea())
        .navigationTitle(text("title")).navigationBarTitleDisplayMode(.inline)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYHeroHeader(verbatim: text("title"))
            CYEmptyState(
                systemImage: "theatermasks",
                "installedRehearsal.unavailable",
                tableName: "InstalledDraftRehearsal",
                messageIdentifier: "installedRehearsal.unavailable",
                kind: .failure
            )
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CYColor.bgPage.ignoresSafeArea())
        .cyHeroScreen()
    }

    private func review(_ snapshot: ModInstallationSavedRehearsalSnapshot) -> some View {
        Form {
            Section {
                CYHeroHeader(verbatim: text("title")) {
                    CYCoverArt(seed: snapshot.saved.draftContentHash, symbol: "theatermasks", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                        .frame(height: heroArtHeight)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                Text(verbatim: text("savedOnly"))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: text("licenseChecked"))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: text("boundary"))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                fact(text("templateId"), String(snapshot.saved.templateId))
                fact(text("licenseId"), shown(snapshot.installation.licenseId))
                fact(text("moduleId"), shown(snapshot.installation.moduleId))
                fact(text("releaseId"), shown(snapshot.installation.releaseId))
                fact(text("installationId"), shown(snapshot.installation.requestId))
                fact(text("draftHash"), shown(snapshot.saved.draftContentHash))
                fact(text("contentHash"), shown(snapshot.installation.contentHash))
                fact(text("termsHash"), shown(snapshot.installation.termsHash))
                fact(text("bindingHash"), shown(snapshot.saved.bindingHash))
                ForEach(snapshot.installation.bindings) { binding in
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(verbatim: "\(binding.kind.rawValue) · \(binding.key) · \(binding.label) (#\(binding.resourceId))")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: shown(binding.fingerprint))
                            .cyText(.meta).monospaced()
                            .foregroundStyle(CYColor.textSecondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                }
            } header: {
                Text(LocalizedStringKey(stringLiteral: text("identity")))
                    .accessibilityAddTraits(.isHeader)
            }
            Section {
                ForEach(snapshot.saved.fields.keys.sorted(), id: \.self) { key in
                    Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation")
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: shown(snapshot.saved.fields[key] ?? ""))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup(text("fullSnapshot")) {
                    Text(verbatim: shown(snapshot.saved.snapshotJson))
                        .cyText(.meta).monospaced()
                        .foregroundStyle(CYColor.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text(LocalizedStringKey(stringLiteral: text("savedFields")))
                    .accessibilityAddTraits(.isHeader)
            }
            Section {
                CYPillButton(verbatim: text("start"), systemImage: "play.fill") { rehearsal.start() }
                    .disabled(!rehearsal.available)
                    .accessibilityIdentifier("installedRehearsal.start")
                    .listRowBackground(Color.clear)
            }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .accessibilityIdentifier("installedRehearsal.review")
    }

    /// Label above the value so a hash wraps at large Dynamic Type instead of truncating.
    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: title)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: value)
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
