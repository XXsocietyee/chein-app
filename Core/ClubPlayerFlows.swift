import Foundation

/// Player club create and host-apply steps from `pages/club/create` and `pages/club/apply`.
/// Copy and step rules only. This file does not send a request or mark a route live.
public enum ClubCreateSteps {
    public static let count = 4

    /// Step 2 (directions) is optional. A blocked name stays on step 3.
    public static func canAdvance(step: Int, clubType: String, name: String, nameBlocked: Bool, city: String) -> Bool {
        func blank(_ value: String) -> Bool { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        switch step {
        case 1: return !blank(clubType)
        case 2: return true
        case 3: return !blank(name) && !nameBlocked
        case 4: return !blank(city)
        default: return false
        }
    }
}

/// `joinPolicy == 1` is the only join that asks for a message. Open join sends none.
public enum ClubPlayerJoin {
    public static func requiresMessage(joinPolicy: Int) -> Bool { joinPolicy == 1 }
}

/// Read-only `/api/club/name-check`. A missing answer does not mean the name is free or taken.
public enum ClubNameCheck {
    public static let path = "api/club/name-check"
    public static let takenFallback = "俱乐部名称已被使用，请换一个"

    public enum Result: Equatable {
        case available
        case taken(String)
        case unchecked
    }

    public static func shouldQuery(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Taken stops the wizard. Available and unchecked both allow the next step;
    /// unchecked is not treated as a server "available".
    public static func allowsAdvance(_ result: Result) -> Bool {
        if case .taken = result { return false }
        return true
    }

    public static func interpret(available: Bool?, reason: String?) -> Result {
        guard let available else { return .unchecked }
        if available { return .available }
        let trimmed = (reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return .taken(trimmed.isEmpty ? takenFallback : trimmed)
    }

    /// HTTP or JSON that is not a name-check answer becomes `.unchecked` (the mini-program `fail` path).
    public static func decode(data: Data, status: Int) -> Result {
        guard (200..<300).contains(status),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.code.ok else { return .unchecked }
        return interpret(available: envelope.data?.available, reason: envelope.data?.reason)
    }

    /// Mini-program `isNameTaken`: Chinese 名称 + 已被使用/已存在/重复, plus the English server wording.
    public static func isTakenMessage(_ message: String?) -> Bool {
        let text = message ?? ""
        let chinese = text.contains("名称") && (text.contains("已被使用") || text.contains("已存在") || text.contains("重复"))
        let folded = text.lowercased()
        let english = folded.contains("name") && (folded.contains("taken") || folded.contains("already") || folded.contains("exists") || folded.contains("duplicate"))
        return chinese || english
    }

    private struct Envelope: Decodable {
        let code: FlexCode
        let data: Payload?
        struct Payload: Decodable {
            let available: Bool?
            let reason: String?
        }
    }

    private struct FlexCode: Decodable {
        let ok: Bool
        init(from decoder: Decoder) throws {
            let box = try decoder.singleValueContainer()
            if let number = try? box.decode(Int.self) { ok = number == 200; return }
            if let text = try? box.decode(String.self) { ok = text == "200"; return }
            ok = false
        }
    }
}

/// zh-Hans and English sentences for the player wizards. Views pass the environment locale.
/// Catalog keys are in docs/port/strings/cursor-r8-club.json. A missing catalog entry keeps the same literal.
public enum ClubPlayerCopy {
    public static func createIntroTitle(_ locale: Locale) -> String {
        sentence("club.player.createIntroTitle", "建一个俱乐部", "Create a club", locale: locale)
    }
    public static func createStart(_ locale: Locale) -> String {
        sentence("club.player.createStart", "开始创建", "Start", locale: locale)
    }
    public static func next(_ locale: Locale) -> String {
        sentence("club.player.next", "下一步", "Next", locale: locale)
    }
    public static func applyIntroTitle(_ locale: Locale) -> String {
        sentence("club.player.applyIntroTitle", "把你带的人，\n变成你的俱乐部", "Turn the people you lead\ninto your club", locale: locale)
    }
    public static func applyStart(_ locale: Locale) -> String {
        sentence("club.player.applyStart", "成为主理人", "Become a host", locale: locale)
    }
    public static func applyTitle(step: Int, locale: Locale) -> String {
        switch step {
        case 1: return sentence("club.player.applyTitle.1", "先认识一下你", "Let’s start with you", locale: locale)
        case 2: return sentence("club.player.applyTitle.2", "你带过多少场？", "How many events have you led?", locale: locale)
        case 3: return sentence("club.player.applyTitle.3", "你能自己做哪些？", "What can you do yourself?", locale: locale)
        default: return sentence("club.player.applyTitle.4", "有资质就传一份", "Add a credential if you have one", locale: locale)
        }
    }
    public static func createTitle(step: Int, locale: Locale) -> String {
        switch step {
        case 1: return sentence("club.player.createTitle.1", "选择你的俱乐部类型", "Choose your club type", locale: locale)
        case 2: return sentence("club.player.createTitle.2", "哪些最符合你的活动方向？", "Which directions fit your events?", locale: locale)
        case 3: return sentence("club.player.createTitle.3", "完善俱乐部资料", "Complete the club profile", locale: locale)
        default: return sentence("club.player.createTitle.4", "你的俱乐部在哪座城市？", "Which city is your club in?", locale: locale)
        }
    }
    public static func progress(_ step: Int) -> String { "\(step) / 4" }
    public static func progressLabel(_ step: Int, locale: Locale) -> String {
        counted("club.player.progressLabel", step, "第\(step)步，共4步", "Step \(step) of 4", locale: locale)
    }
    public static func needType(_ locale: Locale) -> String {
        sentence("club.player.needType", "请选择俱乐部类型", "Choose a club type", locale: locale)
    }
    public static func needName(_ locale: Locale) -> String {
        sentence("club.player.needName", "请给俱乐部起个名字", "Give the club a name", locale: locale)
    }
    public static func needCity(_ locale: Locale) -> String {
        sentence("club.player.needCity", "请填写所在城市", "Enter the city", locale: locale)
    }
    public static func directionLimit(_ locale: Locale) -> String {
        sentence("club.player.directionLimit", "最多选 3 个", "Choose up to 3", locale: locale)
    }
    public static func directionCount(_ count: Int, locale: Locale) -> String {
        counted("club.player.directionCount", count, "已选 \(count) / 3", "\(count) of 3 selected", locale: locale)
    }
    public static func checkingName(_ locale: Locale) -> String {
        sentence("club.player.checkingName", "正在检查名称", "Checking the name", locale: locale)
    }
    public static func applyNameGap(_ locale: Locale) -> String {
        sentence("club.player.applyNameGap", "请填写称呼", "Enter what people should call you", locale: locale)
    }
    public static func applyPhoneGap(_ locale: Locale) -> String {
        sentence("club.player.applyPhoneGap", "请填写联系方式", "Enter a way to reach you", locale: locale)
    }
    public static func applyExperienceGap(_ locale: Locale) -> String {
        sentence("club.player.applyExperienceGap", "请选择你带过多少场", "Choose how many events you’ve led", locale: locale)
    }
    public static func quitRejoin(needsApproval: Bool, locale: Locale) -> String {
        if needsApproval {
            return sentence("club.player.quitRejoin.approval", "要重新申请并等主理人通过", "You’ll need to apply again and wait for the host", locale: locale)
        }
        return sentence("club.player.quitRejoin.open", "可以直接再点「加入俱乐部」，不需要审批", "You can tap Join again. No approval is needed.", locale: locale)
    }
    public static func confirmResult(_ locale: Locale) -> String {
        sentence("club.player.confirmResult", "确认结果", "Confirm the result", locale: locale)
    }

    private static func sentence(_ key: String, _ zh: String, _ en: String, locale: Locale) -> String {
        let language = ChannelCopy.isChinese(locale) ? "zh-Hans" : "en"
        if let value = localized(key, language: language) { return value }
        return ChannelCopy.text(zh, en, locale: locale)
    }

    private static func counted(_ key: String, _ count: Int, _ zh: String, _ en: String, locale: Locale) -> String {
        let language = ChannelCopy.isChinese(locale) ? "zh-Hans" : "en"
        if let format = localized(key, language: language) {
            return String(format: format, locale: Locale(identifier: language), count)
        }
        return ChannelCopy.text(zh, en, locale: locale)
    }

    private static func localized(_ key: String, language: String) -> String? {
        guard let catalogPath = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: catalogPath) else { return nil }
        let value = bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
        if value.isEmpty || value == "\u{0}" || value == key { return nil }
        return value
    }
}
