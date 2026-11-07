import Foundation

// MARK: - External game library presentation rules (pure)
// The imported-game feature stays behind a launch flag (App Store guideline 4.7 review is an owner decision)
// and stays sandboxed: no payments and no unsandboxed JavaScript bridges. See `ExternalGameValidator`.

public enum ExternalGameLinkCheck: Equatable, Sendable {
    case empty
    case invalid
    /// Well-formed HTTPS link, but this build has no download transport for packages.
    case validButNotDownloadable
}

public enum ExternalGameLibraryPresentation {
    public static let launchFlagKey = "externalGames"

    /// Whether the app can fetch a package from a link. No approved download transport exists yet, so
    /// link and QR imports must say so instead of staging a package the player did not choose.
    public static let linkDownloadAvailable = false

    public static func isEnabled(flags: LaunchFeatureFlags) -> Bool {
        flags.isOn(launchFlagKey)
    }

    public static func checkLink(_ raw: String) -> ExternalGameLinkCheck {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let url = URL(string: trimmed), (try? ExternalGameValidator.validateImportURL(url)) != nil else {
            return .invalid
        }
        return .validButNotDownloadable
    }

    public static func message(for check: ExternalGameLinkCheck) -> String {
        switch check {
        case .empty:
            return W8Text.t("请输入游戏包的 HTTPS 链接。", "Enter the HTTPS link of the game package.")
        case .invalid:
            return W8Text.t("只支持不带账号信息的 HTTPS 链接。", "Only HTTPS links without embedded credentials are supported.")
        case .validButNotDownloadable:
            return W8Text.t("链接格式正确，但此版本暂时无法从链接下载游戏包。请改用「从文件导入」。", "The link looks valid, but this version can't download game packages from links yet. Use \"Import from file\" instead.")
        }
    }
}
