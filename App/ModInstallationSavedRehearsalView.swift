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
    private func text(_ key: String) -> String { installedRehearsalLocalized(key, locale: locale) }
    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = rehearsal.snapshot {
                    if rehearsal.started {
                        VStack(alignment: .leading) {
                            Text(text("boundary")).font(.footnote).padding(.horizontal)
                            Text(verbatim: "#\(snapshot.saved.templateId) · \(snapshot.saved.draftContentHash)").font(.caption.monospaced()).padding(.horizontal)
                            TemplateCreatorRehearsalView(draft: snapshot.advanced, family: .branch,
                                branchAdmission: { rehearsal.admitBranch() }, showsReview: false)
                                .id(rehearsal.id)
                        }
                    } else { review(snapshot) }
                } else { Text(text("unavailable")).padding().accessibilityIdentifier("installedRehearsal.unavailable") }
            }
            .navigationTitle(text("title"))
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(text("return")) { rehearsal.retire(); dismiss() }.accessibilityIdentifier("installedRehearsal.return")
            } }
        }.privacySensitive().accessibilityIdentifier("installedRehearsal.root")
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
    private func review(_ snapshot: ModInstallationSavedRehearsalSnapshot) -> some View {
        Form {
            Section {
                Text(text("savedOnly"))
                Text(text("licenseChecked"))
                Text(text("boundary"))
            }
            Section {
                LabeledContent(text("templateId"), value: String(snapshot.saved.templateId))
                LabeledContent(text("licenseId"), value: snapshot.installation.licenseId)
                LabeledContent(text("moduleId"), value: snapshot.installation.moduleId)
                LabeledContent(text("releaseId"), value: snapshot.installation.releaseId)
                LabeledContent(text("installationId"), value: snapshot.installation.requestId)
                LabeledContent(text("draftHash"), value: snapshot.saved.draftContentHash)
                LabeledContent(text("contentHash"), value: snapshot.installation.contentHash)
                LabeledContent(text("termsHash"), value: snapshot.installation.termsHash)
                LabeledContent(text("bindingHash"), value: snapshot.saved.bindingHash)
                ForEach(snapshot.installation.bindings) { binding in
                    Text(verbatim: "\(binding.kind.rawValue) · \(binding.key) · \(binding.label) (#\(binding.resourceId))")
                    Text(verbatim: binding.fingerprint).font(.caption.monospaced())
                }
            } header: { Text(text("identity")) }
            Section {
                ForEach(snapshot.saved.fields.keys.sorted(), id: \.self) { key in
                    Text(LocalizedStringKey("modInstallation.field." + key), tableName: "ModInstallation").font(.headline)
                    Text(verbatim: snapshot.saved.fields[key] ?? "").textSelection(.enabled)
                }
                DisclosureGroup(text("fullSnapshot")) {
                    Text(verbatim: snapshot.saved.snapshotJson).font(.caption.monospaced()).textSelection(.enabled)
                }
            } header: { Text(text("savedFields")) }
            CYPillButton(verbatim: text("start")) { rehearsal.start() }.listRowBackground(Color.clear).disabled(!rehearsal.available)
                .accessibilityIdentifier("installedRehearsal.start")
        }.accessibilityIdentifier("installedRehearsal.review")
    }
}
