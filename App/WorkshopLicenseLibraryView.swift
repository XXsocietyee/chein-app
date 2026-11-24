import SwiftUI

/// Presentation only: an internal error key is never user-facing copy or a business result.
enum WorkshopLicenseLibraryPresentation {
    static func messageKey(_ key: String) -> String {
        key == "error.licensesUnavailable" ? "workshopCommerce.error.licensesUnavailable" : "workshopCommerce.library.readUnavailable"
    }
    static func statusKey(_ status: String) -> String? {
        ["ACTIVE", "SUSPENDED", "REVOKED"].contains(status) ? "workshopCommerce.state." + status : nil
    }
    static func showsEmpty(hasRead: Bool, busy: Bool, count: Int, message: String?) -> Bool {
        hasRead && !busy && count == 0 && message == nil
    }
}

/// Reads the original durable license ledger. Opening this screen never recovers a purchase.
@MainActor struct WorkshopLicenseLibraryView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var controller: WorkshopCommerceController?
    @State private var hasReadLicenses = false
    var body: some View {
        List {
            if scenePhase == .active {
                Section {
                    licenseLibraryText("library.boundary")
                        .cyText(.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let controller, controller.isCurrent {
                    ForEach(controller.licenses, id: \.licenseId) { item in
                        Section {
                            NavigationLink {
                                WorkshopCommerceLicenseDetailView(controller: controller, licenseId: item.licenseId)
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                                    Text(verbatim: item.moduleId).cyText(.sectionTitle)
                                    Text(verbatim: item.purchasedVersionId).cyText(.body).foregroundStyle(.secondary)
                                    if let key = WorkshopLicenseLibraryPresentation.statusKey(item.status) {
                                        WorkshopCommerceLibraryState(label: Text(LocalizedStringKey(key), tableName: "WorkshopCommerce"), raw: item.status)
                                    } else {
                                        // Keep an unrecognised original state visible; never invent ACTIVE.
                                        Text(verbatim: item.status).cyText(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                    }
                                }.fixedSize(horizontal: false, vertical: true)
                                    .accessibilityElement(children: .combine)
                                    .padding(.vertical, Theme.Space.s2)
                            }.accessibilityIdentifier("modLicense.original." + item.licenseId)
                            let original = ModInstallationIdentity(licenseId: item.licenseId, moduleId: item.moduleId,
                                releaseId: item.purchasedVersionId, contentHash: item.terms.contentHash, termsHash: item.terms.hash)
                            ModInstallationOriginalRecoveryLink(reference: original, makeController: { session.makeModInstallationController(reference: $0) })
                            ModUpgradeOriginalRecoveryLink(reference: original)
                            if item.status == "ACTIVE" {
                                let reference = ModInstallationIdentity(licenseId: item.licenseId, moduleId: item.moduleId,
                                    releaseId: item.purchasedVersionId, contentHash: item.terms.contentHash, termsHash: item.terms.hash)
                                ModInstallationLicenseLink(reference: reference, makeController: { session.makeModInstallationController(reference: $0) },
                                    makeInstallationPair: { reference in
                                        guard let pair = session.makeModInstallationWithOriginalReader(reference: reference) else { return nil }
                                        return (pair.controller, pair.originalReader)
                                    })
                                ModUpgradeLicenseLink(reference: reference)
                            }
                        }
                    }
                    Section {
                        if controller.busy || !hasReadLicenses {
                            CYLoadingStateView(rows: 1).accessibilityLabel(licenseLibraryText("library.loading"))
                                .accessibilityIdentifier("workshopLicenseLibrary.loading")
                        }
                        if let message = controller.licensesMessageKey {
                            Label {
                                Text(LocalizedStringKey(WorkshopLicenseLibraryPresentation.messageKey(message)), tableName: "WorkshopCommerce")
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: { Image(systemName: "exclamationmark.triangle").accessibilityHidden(true) }
                            .padding(.vertical, Theme.Space.s2)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("workshopLicenseLibrary.readError")
                        }
                        if WorkshopLicenseLibraryPresentation.showsEmpty(hasRead: hasReadLicenses, busy: controller.busy,
                                                                         count: controller.licenses.count, message: controller.licensesMessageKey) {
                            WorkshopCommerceLibraryNotice(text: licenseLibraryText("library.empty"), symbol: "tray")
                        }
                        CYPillButton(LocalizedStringKey("workshopCommerce.library.refresh"), style: .secondary, tableName: "WorkshopCommerce") { Task { await read() } }
                            .disabled(controller.busy)
                        if controller.hasMoreLicenses {
                            CYPillButton(LocalizedStringKey("workshopCommerce.library.nextPage"), style: .secondary, tableName: "WorkshopCommerce") { Task { await read(more: true) } }
                                .disabled(controller.busy)
                        }
                    } header: { licenseLibraryText("library.readState") }
                } else {
                    Section {
                        WorkshopCommerceLibraryNotice(text: licenseLibraryText("library.unavailable"), symbol: "icloud.slash")
                        CYPillButton(LocalizedStringKey("workshopCommerce.library.reopen"), style: .secondary, tableName: "WorkshopCommerce") { Task { await read() } }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyText(.body)
        .modifier(WorkshopLibrarySurface())
        .navigationTitle(String(localized: LocalizedStringResource("workshopCommerce.library.title", table: "WorkshopCommerce", locale: locale))).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task { await read() }
        .onChange(of: session.sessionRevision) { _, _ in Task { await read() } }
        .onChange(of: session.account?.id) { _, _ in Task { await read() } }
        .onChange(of: session.account?.effectiveRole) { _, _ in Task { await read() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await read() } } }
        // Pushing the existing detail must not invalidate its shared read-only controller.
    }
    private func read(more: Bool = false) async {
        guard scenePhase == .active, !Task.isCancelled else { return }
        if controller?.isCurrent != true {
            controller?.invalidate(); hasReadLicenses = false
            controller = session.makeWorkshopCommerceController(readOnly: true)
        }
        guard let controller, controller.isCurrent else { return }
        await controller.loadLicenses(more: more) // GET only, never recover()/restoreOwned()/create().
        guard scenePhase == .active, !Task.isCancelled, self.controller === controller, controller.isCurrent else { return }
        hasReadLicenses = true
    }
}

private func licenseLibraryText(_ key: String) -> Text {
    Text(LocalizedStringKey("workshopCommerce." + key), tableName: "WorkshopCommerce")
}
