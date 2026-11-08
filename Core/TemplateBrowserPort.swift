import Foundation

/// Port of mini-program `pages/template/index` list-state rules (pure value logic, no network).
public enum TemplateBrowserPort {
    /// Cover image is shown only for a plain https URL; anything else (nil, blank, http, credentials)
    /// renders the mini-program's "封面暂不可用" placeholder instead of a broken box.
    public static func coverURL(_ raw: String?) -> URL? { RoamStampSlipPhotoPort.displayURL(raw) }

    /// `.wxml`: the "正在同步最新内容…" line shows only while a refresh runs over already-loaded rows;
    /// the first load uses the skeleton/spinner instead.
    public static func showsSyncingLine(isLoading: Bool, hasLoadedRows: Bool) -> Bool { isLoading && hasLoadedRows }

    /// `.wxml`: the "其他模板 / 不筛掉，继续显示" hint belongs to the tail list only.
    public static func showsOtherTemplatesHint(otherCount: Int) -> Bool { otherCount > 0 }
}
