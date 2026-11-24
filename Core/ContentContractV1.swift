import Foundation

/// Shared content-contract v1 checks from
/// `docs/release/zip-v35/chengyinhub-admin/src/test/resources/contracts/content-contract-v1-vectors.json`
/// and `docs/release/zip-v35/docs/contracts/content-schema.v1.json`.
/// This evaluates the golden vectors. It is not the live play judge: `UGGameplayReader` still
/// refuses hangman, accusation, help, and skip writes, and `UGHangman.judgesLocally` stays false.
public enum ContentContractV1 {
    public static let contract = "chengyin-content-contract-v1"
    public static let contractVersion = 1

    /// Play sections named by `x-cy-sections` with kind PLAY. Accusation is a presentation block.
    public static let playSections: Set<String> = [
        "timer", "random", "branch", "leaderboard", "multiplayer", "timeWindow", "blindTaste",
        "silentOrder", "diyName", "musicCorner", "steps", "dailySign", "slowTask", "estimate",
        "pricePair", "hiddenObject", "predict", "qa", "scan", "sort", "match", "classify",
        "compare", "profile", "photoCheck", "album", "note", "typeIn", "coinFlip", "diceRoll",
        "reaction", "ballShake", "quietHold", "compass", "shout", "countdown", "stopwatch", "hangman"
    ]

    public struct Rejection: Error, Equatable {
        public let message: String
        public init(message: String) { self.message = message }
    }

    public struct SaveReport: Equatable {
        public let mechanic: Bool
        public let present: String
        public let ladderSize: Int?
        public let quota: Int?
    }

    public struct HangmanSafeConfig: Equatable {
        public let enabled: Bool
        public let length: Int
        public let blankCount: Int
        public let caseSensitive: Bool
    }

    public struct HangmanBoard: Equatable {
        public let display: String
        public let length: Int
        public let blankCount: Int
        public let solved: Bool
    }

    public struct HangmanSubmission: Equatable {
        public let verdict: String
        public let answerText: String?
        public let display: String
        public let solved: Bool
        public let alreadySolved: Bool
    }

    public struct HintLayer: Equatable {
        public let level: Int
        public let type: String
        public let usable: Bool
        public let unlocked: Bool
        public let free: Bool
        public let costPoints: Int
        public let freeQuota: Int
        public let reason: String?
    }

    public struct SkipFact: Equatable {
        public let configured: Bool
        public let usable: Bool
    }

    public struct AccusationOutcome: Equatable {
        public let verdict: String
        public let correct: Bool
        public let early: Bool
        public let recordCode: String?
        public let canRetry: Bool
        public let terminal: Bool
        public let endingScreen: String?
        public let refuseCode: String?
    }

    public static func validate(_ document: PlayWireValue) throws -> SaveReport {
        try validateDocument(document)
        let fields = document.object ?? [:]
        let ladder = fields["hintLadder"]?.array
        let quota = fields.keys.contains("hintFreeUsesPerRun") ? fields["hintFreeUsesPerRun"]?.integer : nil
        return SaveReport(mechanic: mechanic(document), present: present(document),
                          ladderSize: ladder.map(\.count), quota: quota)
    }

    public static func project(_ document: PlayWireValue) throws -> PlayWireValue {
        try validateDocument(document)
        var out: [String: PlayWireValue] = ["schemaVersion": .int(1), "present": .string(present(document))]
        if isEnabled(document["hangman"]), let hangman = document["hangman"].object {
            let safe = try hangmanSafe(hangman)
            out["hangman"] = .object([
                "enabled": .bool(true),
                "length": .int(safe.length),
                "blankCount": .int(safe.blankCount),
                "caseSensitive": .bool(safe.caseSensitive)
            ])
        }
        if isEnabled(document["accusation"]), let accusation = document["accusation"].object {
            out["accusation"] = publicAccusation(accusation)
        }
        if isEnabled(document["qa"]), var qa = document["qa"].object {
            qa.removeValue(forKey: "answerText")
            if let options = qa["options"]?.array {
                qa["options"] = .array(options.map(publicOption))
            }
            out["qa"] = .object(qa)
        }
        return .object(out)
    }

    public static func validateHangmanSection(_ section: PlayWireValue) throws {
        try validateHangman(section.object ?? [:])
    }

    public static func hangmanSafeConfig(_ section: PlayWireValue) throws -> HangmanSafeConfig {
        try validateHangman(section.object ?? [:])
        return try hangmanSafe(section.object ?? [:])
    }

    public static func hangmanBoard(_ section: PlayWireValue) throws -> HangmanBoard {
        try validateHangman(section.object ?? [:])
        let fields = section.object ?? [:]
        let answer = text(fields["answer"] ?? .null) ?? ""
        let board = boardPieces(answer: answer, format: fields["format"])
        return HangmanBoard(display: board.display, length: board.points.count, blankCount: board.blanks.count, solved: false)
    }

    public static func hangmanSubmit(_ section: PlayWireValue, payload: PlayWireValue) throws -> HangmanSubmission {
        try validateHangman(section.object ?? [:])
        let fields = section.object ?? [:]
        let answer = text(fields["answer"] ?? .null) ?? ""
        let caseSensitive = fields["caseSensitive"]?.bool == true
        let aliases = (fields["aliases"]?.array ?? []).compactMap { text($0) }
        let board = boardPieces(answer: answer, format: fields["format"])
        if payload.object?.keys.contains("slots") == true {
            let slots = payload["slots"].object ?? [:]
            for key in slots.keys {
                guard let index = Int(key), board.blanks.contains(index) else {
                    try reject("题面已给出的格子不能再提交")
                }
            }
        }
        guard let input = text(payload["input"]) else { try reject("提交不合法") }
        func same(_ left: String, _ right: String) -> Bool {
            caseSensitive ? left == right : canon(left) == canon(right)
        }
        func matches(_ candidate: String) -> Bool {
            same(candidate, answer) || aliases.contains { same(candidate, $0) }
        }
        if matches(input) {
            return HangmanSubmission(verdict: "CORRECT", answerText: answer, display: answer, solved: true, alreadySolved: false)
        }
        let typed = codePoints(input)
        if typed.count == board.blanks.count {
            var chars = codePoints(board.display)
            for (character, index) in zip(typed, board.blanks) {
                chars[index] = character
            }
            let filled = chars.joined()
            if matches(filled) {
                return HangmanSubmission(verdict: "CORRECT", answerText: answer, display: answer, solved: true, alreadySolved: false)
            }
            return HangmanSubmission(verdict: "WRONG", answerText: nil, display: filled, solved: false, alreadySolved: false)
        }
        return HangmanSubmission(verdict: "WRONG", answerText: nil, display: board.display, solved: false, alreadySolved: false)
    }

    public static func accusationCorrectID(_ document: PlayWireValue) -> String? {
        for option in document["qa"]["options"].array ?? [] {
            if option["correct"].bool == true { return text(option["id"]) }
        }
        return nil
    }

    public static func accusationEnabled(_ document: PlayWireValue) -> Bool {
        isEnabled(document["accusation"])
    }

    public static func accusationOutcome(_ document: PlayWireValue, submission: PlayWireValue) -> AccusationOutcome {
        let submitted = text(submission["submitted"]) ?? ""
        let gate = submission["clueGateSatisfied"].bool
        let early = submission["early"].object ?? [:]
        let remain = submission["remainingChances"].integer
        let suspects = Set((document["accusation"]["suspects"].array ?? []).compactMap { text($0["id"]) })
        if submitted.isEmpty || !suspects.contains(submitted) {
            return AccusationOutcome(verdict: "REFUSED", correct: false, early: false, recordCode: nil,
                                     canRetry: true, terminal: false, endingScreen: nil, refuseCode: "ACCUSATION_MISSING_SUSPECT")
        }
        if gate == false && early["allowed"]?.bool != true {
            return AccusationOutcome(verdict: "REFUSED", correct: false, early: false, recordCode: nil,
                                     canRetry: true, terminal: false, endingScreen: nil, refuseCode: "ACCUSATION_EARLY_NOT_ALLOWED")
        }
        if submitted == accusationCorrectID(document) {
            let closedEarly = gate == false && early["allowed"]?.bool == true
            return AccusationOutcome(verdict: "CORRECT", correct: true, early: closedEarly,
                                     recordCode: closedEarly ? text(early["recordAs"] ?? .null) : nil,
                                     canRetry: false, terminal: true, endingScreen: "winScreen", refuseCode: nil)
        }
        if remain == 0 {
            return AccusationOutcome(verdict: "FAILED", correct: false, early: false, recordCode: nil,
                                     canRetry: false, terminal: true, endingScreen: "loseScreen", refuseCode: nil)
        }
        return AccusationOutcome(verdict: "WRONG", correct: false, early: false, recordCode: nil,
                                 canRetry: true, terminal: false, endingScreen: nil, refuseCode: nil)
    }

    public static func hintPolicy(ladder: PlayWireValue, unlockedLevels: [Int], remainingFreeUses: Int) -> [HintLayer] {
        let unlocked = Set(unlockedLevels)
        return (ladder.array ?? []).map { entry in
            let level = entry["level"].integer ?? 0
            let author = entry["cost"]["points"].integer ?? 0
            let free = unlocked.contains(level) || remainingFreeUses > 0
            return HintLayer(level: level, type: text(entry["type"]) ?? "", usable: true,
                             unlocked: unlocked.contains(level), free: free, costPoints: free ? 0 : author,
                             freeQuota: 0, reason: nil)
        }
    }

    public static func skipFact(ladder: PlayWireValue) -> SkipFact {
        let configured = (ladder.array ?? []).contains { text($0["type"]) == "SKIP" }
        return SkipFact(configured: configured, usable: configured)
    }

    /// Fact key ignores the help payload. The fingerprint includes level, free, and points.
    public static func requestFactKey(memberID: Int, scope: PlayWireValue, requestID: String) -> String {
        let topic = scope["topicId"].integer.map(String.init) ?? ""
        let activity = scope["activityId"].integer.map(String.init) ?? ""
        let node = scope["nodeId"].integer.map(String.init) ?? ""
        let instance = text(scope["playInstance"]) ?? ""
        return [String(memberID), topic, activity, node, instance, requestID].joined(separator: "|")
    }

    public static func requestFingerprint(factKey: String, level: Int, free: Bool, chargedPoints: Int) -> String {
        "\(factKey)|\(level)|\(free)|\(chargedPoints)"
    }

    public static func runQuota(_ snapshot: PlayWireValue) throws -> UGQuotaFinding {
        UGRunQuota.read(data: try JSONEncoder().encode(snapshot))
    }
}

private extension ContentContractV1 {
    static func reject(_ message: String) throws -> Never {
        throw Rejection(message: message)
    }

    static func text(_ value: PlayWireValue) -> String? {
        if case .string(let raw) = value { return raw }
        return nil
    }

    static func isEnabled(_ value: PlayWireValue) -> Bool { value["enabled"].bool == true }

    static func codePoints(_ value: String) -> [String] {
        value.unicodeScalars.map { String($0) }
    }

    static func canon(_ value: String) -> String { value.uppercased().lowercased() }

    static func javaTrim(_ value: String) -> String {
        let scalars = Array(value.unicodeScalars)
        var start = 0
        var end = scalars.count
        while start < end && scalars[start].value <= 32 { start += 1 }
        while end > start && scalars[end - 1].value <= 32 { end -= 1 }
        return String(scalars[start..<end].map(Character.init))
    }

    static func trimmedCount(_ value: String) -> Int { codePoints(javaTrim(value)).count }

    static func hasAlnum(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    static func isMedia(_ value: String) -> Bool {
        if value.hasPrefix("https://") { return true }
        if value.hasPrefix("/"), !value.hasPrefix("//"), !value.contains("\\"), value.unicodeScalars.count >= 2 {
            guard let second = value.unicodeScalars.dropFirst().first else { return false }
            return second.value != 47 && second.value != 92
        }
        guard value.hasPrefix("media-asset:") else { return false }
        let rest = value.dropFirst("media-asset:".count)
        guard let first = rest.first, first != "0", first.isNumber, rest.allSatisfy(\.isNumber), (1...19).contains(rest.count) else {
            return false
        }
        return true
    }

    static func isClueKey(_ key: String) -> Bool {
        let prefix = "clue.h_"
        guard key.hasPrefix(prefix) else { return false }
        let rest = key.dropFirst(prefix.count)
        guard rest.count == 12 else { return false }
        return rest.allSatisfy { character in
            guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else { return false }
            return CharacterSet(charactersIn: "0123456789abcdef").contains(scalar)
        }
    }

    static func requireText(_ value: PlayWireValue?, minimum: Int, maximum: Int, _ message: String) throws -> String {
        guard let raw = value.flatMap(text), (minimum...maximum).contains(trimmedCount(raw)) else { try reject(message) }
        return raw
    }

    static func mechanic(_ document: PlayWireValue) -> Bool {
        playSections.contains { isEnabled(document[$0]) }
    }

    static func present(_ document: PlayWireValue) -> String {
        if let chosen = text(document["present"]), chosen == "inline" || chosen == "fullscreen" { return chosen }
        return mechanic(document) ? "inline" : "fullscreen"
    }

    static func validateDocument(_ document: PlayWireValue) throws {
        guard let fields = document.object else { try reject("配置须为对象") }
        guard fields["schemaVersion"]?.integer == 1 else { try reject("高级玩法配置版本不支持") }
        if fields.keys.contains("present"), !(["inline", "fullscreen"].contains(text(fields["present"] ?? .null) ?? "")) {
            try reject("呈现方式不支持")
        }
        if fields.keys.contains("mistakeTier"), !(["easy", "medium", "hard"].contains(text(fields["mistakeTier"] ?? .null) ?? "")) {
            try reject("难度档不支持")
        }
        if let ladder = fields["hintLadder"] { try validateLadder(ladder) }
        if let quota = fields["hintFreeUsesPerRun"] { try validateQuota(quota) }
        if let hangman = fields["hangman"]?.object { try validateHangman(hangman) }
        if let qa = fields["qa"]?.object { try validateQA(qa) }
        if fields.keys.contains("accusation") { try validateAccusation(fields) }
        if let clues = fields["clues"] { try validateClues(clues) }
        if let timer = fields["timer"] { try validateTimer(timer) }
        if let random = fields["random"] { try validateRandom(random) }
        if let sort = fields["sort"] { try validateSort(sort) }
        if let match = fields["match"] { try validateMatch(match) }
        if let classify = fields["classify"] { try validateClassify(classify) }
        if let compare = fields["compare"] { try validateCompare(compare) }
        if let music = fields["backgroundMusic"] { try validateBackground(music) }
        if let photo = fields["photoCheck"] { try validatePhoto(photo) }
        if let reading = fields["arrivalReading"] { try validateArrivalReading(reading) }
        if let policy = fields["arrivalPolicy"] { try validateArrivalPolicy(policy) }
        if let check = fields["check"] { try validateCheck(check) }
        if let transform = fields["clueTransform"] { try validateClueTransform(transform) }
    }

    static func validateQuota(_ value: PlayWireValue) throws {
        guard let number = value.integer, (0...1000).contains(number) else { try reject("整局免费次数须为 0 至 1000") }
    }

    static func validateLadder(_ value: PlayWireValue) throws {
        guard let rows = value.array else { try reject("提示阶梯须为数组") }
        var seen: Set<Int> = []
        for entry in rows {
            guard let fields = entry.object else { try reject("提示阶梯条目不合法") }
            let type = (text(fields["type"] ?? .null) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if type == "LOCATION" { try reject("位置类帮助会绕过既有到达与权限判定") }
            guard ["TEXT", "IMAGE", "LETTER", "DIGIT", "ANSWER", "SKIP"].contains(type) else { try reject("不支持的提示类型") }
            guard let level = fields["level"]?.integer, (1...6).contains(level), seen.insert(level).inserted else {
                try reject("提示层级须为 1 至 6 且不重复")
            }
            if fields.keys.contains("freeQuota"), fields["freeQuota"]?.integer != 0 {
                try reject("层内免费次数已取消，请使用根层 hintFreeUsesPerRun")
            }
            let payload = fields["payload"]
            switch type {
            case "TEXT":
                if text(payload ?? .null).map(javaTrim)?.isEmpty != false { try reject("文字提示不能为空") }
            case "IMAGE":
                if text(payload ?? .null).map(javaTrim)?.isEmpty != false { try reject("图片提示不能为空") }
            case "LETTER":
                if (payload?.integer ?? 0) < 1 { try reject("字母提示须为正整数") }
            case "ANSWER":
                if payload != nil, text(payload ?? .null) == nil { try reject("答案提示须为文字") }
            default:
                if let payload, payload != .null, text(payload) != "" { try reject("该层不能带提示正文") }
            }
            if let cost = fields["cost"] {
                guard let costs = cost.object else { try reject("提示代价不合法") }
                if costs.keys.contains("points"), (costs["points"]?.integer ?? -1) < 0 { try reject("积分代价不合法") }
                if costs.keys.contains("gems"), costs["gems"]?.integer != 0 { try reject("宝石或金币没有账本") }
                if costs.keys.contains("coins"), costs["coins"]?.integer != 0 { try reject("宝石或金币没有账本") }
            }
        }
    }

    static func validateHangman(_ fields: [String: PlayWireValue]) throws {
        guard isEnabled(.object(fields)) else { return }
        guard let answer = text(fields["answer"] ?? .null) else { try reject("逐字猜词答案不合法") }
        let points = codePoints(answer)
        guard (1...40).contains(points.count), hasAlnum(answer) else { try reject("逐字猜词答案不合法") }
        let caseSensitive = fields["caseSensitive"]?.bool == true
        if fields.keys.contains("caseSensitive"), fields["caseSensitive"]?.bool == nil { try reject("caseSensitive 不合法") }
        if let format = fields["format"] {
            guard let slots = format.array, slots.count == points.count else { try reject("槽数必须等于答案码点数") }
            for (index, slot) in slots.enumerated() {
                if slot == .null { continue }
                guard let raw = text(slot) else { try reject("预填字符与答案不符") }
                if raw.isEmpty || raw == "_" { continue }
                guard codePoints(raw).count == 1 else { try reject("预填字符与答案不符") }
                let matches = caseSensitive ? raw == points[index] : canon(raw) == canon(points[index])
                if !matches { try reject("预填字符与答案不符") }
            }
        }
        let aliases = fields["aliases"]?.array ?? []
        guard fields["aliases"] == nil || fields["aliases"]?.array != nil, aliases.count <= 10 else { try reject("别名不合法") }
        var seen: Set<String> = [caseSensitive ? answer : canon(answer)]
        for aliasValue in aliases {
            guard let alias = text(aliasValue), !javaTrim(alias).isEmpty, hasAlnum(alias) else { try reject("别名不合法") }
            let key = caseSensitive ? alias : canon(alias)
            guard seen.insert(key).inserted else { try reject("别名不合法") }
        }
    }

    static func hangmanSafe(_ fields: [String: PlayWireValue]) throws -> HangmanSafeConfig {
        let answer = text(fields["answer"] ?? .null) ?? ""
        let board = boardPieces(answer: answer, format: fields["format"])
        return HangmanSafeConfig(enabled: true, length: board.points.count, blankCount: board.blanks.count,
                                 caseSensitive: fields["caseSensitive"]?.bool == true)
    }

    struct BoardPieces {
        let display: String
        let points: [String]
        let blanks: [Int]
    }

    static func boardPieces(answer: String, format: PlayWireValue?) -> BoardPieces {
        let points = codePoints(answer)
        let slots = format?.array
        var display: [String] = []
        var blanks: [Int] = []
        if let slots {
            for (index, slot) in slots.enumerated() {
                let raw = text(slot) ?? ""
                if slot == .null || raw.isEmpty || raw == "_" {
                    display.append("_")
                    blanks.append(index)
                } else {
                    display.append(raw)
                }
            }
        } else {
            display = Array(repeating: "_", count: points.count)
            blanks = Array(points.indices)
        }
        return BoardPieces(display: display.joined(), points: points, blanks: blanks)
    }

    static func validateQA(_ fields: [String: PlayWireValue]) throws {
        guard isEnabled(.object(fields)) else { return }
        guard ["TYPE", "PICK", "SHOT"].contains(text(fields["mode"] ?? .null) ?? "") else { try reject("问答模式不合法") }
        _ = try requireText(fields["title"], minimum: 1, maximum: 120, "问答标题不合法")
        if text(fields["mode"] ?? .null) == "TYPE" {
            _ = try requireText(fields["answerText"], minimum: 1, maximum: 500, "打字答案不合法")
        }
        guard text(fields["mode"] ?? .null) == "PICK" else { return }
        let options = fields["options"]?.array ?? []
        guard (2...4).contains(options.count) else { try reject("选项数量不合法") }
        var ids: Set<String> = []
        var corrects = 0
        for option in options {
            guard let fields = option.object, let id = text(fields["id"] ?? .null), !javaTrim(id).isEmpty, ids.insert(id).inserted else {
                try reject("选项不合法")
            }
            _ = try requireText(fields["label"], minimum: 1, maximum: 200, "选项文案不合法")
            if fields["correct"]?.bool == true { corrects += 1 }
        }
        if fields["judge"]?.bool != false, corrects != 1 { try reject("选择题须有唯一正确答案") }
    }

    static func validateAccusation(_ fields: [String: PlayWireValue]) throws {
        guard let accusation = fields["accusation"]?.object else { try reject("指认配置不合法") }
        guard isEnabled(.object(accusation)) else { return }
        let allowed: Set<String> = ["enabled", "suspects", "introScreens", "winScreen", "loseScreen", "corkboardImage", "earlyAccuse"]
        if !Set(accusation.keys).subtracting(allowed).isEmpty { try reject("不支持的配置字段") }
        guard let qa = fields["qa"]?.object, isEnabled(.object(qa)), text(qa["mode"] ?? .null) == "PICK" else {
            try reject("指认必须对应已启用的选择题")
        }
        let optionIDs = (qa["options"]?.array ?? []).compactMap { text($0["id"]) }
        let suspects = accusation["suspects"]?.array ?? []
        guard (2...4).contains(suspects.count), suspects.count == optionIDs.count else { try reject("嫌疑人须与选项一一对应") }
        var suspectIDs: [String] = []
        for person in suspects {
            guard let card = person.object, let id = text(card["id"] ?? .null), let name = text(card["name"] ?? .null), !javaTrim(name).isEmpty else {
                try reject("嫌疑人不合法")
            }
            suspectIDs.append(id)
        }
        guard Set(suspectIDs) == Set(optionIDs), Set(suspectIDs).count == suspectIDs.count else { try reject("嫌疑人须与选项一一对应") }
        if let early = accusation["earlyAccuse"] {
            guard let earlyFields = early.object else { try reject("提前指认不合法") }
            if !Set(earlyFields.keys).subtracting(["allowed", "recordAs"]).isEmpty { try reject("不支持的配置字段") }
            guard earlyFields["allowed"]?.bool != nil else { try reject("提前指认不合法") }
            if earlyFields["allowed"]?.bool == true {
                let record = text(earlyFields["recordAs"] ?? .null).map(javaTrim) ?? ""
                if record.isEmpty { try reject("提前指认必须记录结案方式") }
            }
        }
        for key in ["winScreen", "loseScreen"] {
            guard let screen = accusation[key] else { continue }
            if screen != .null, text(screen) == nil, screen.object == nil { try reject("结局画面不合法") }
        }
    }

    static func publicAccusation(_ fields: [String: PlayWireValue]) -> PlayWireValue {
        var suspects: [PlayWireValue] = []
        for person in fields["suspects"]?.array ?? [] {
            var card: [String: PlayWireValue] = [:]
            if let id = person.object?["id"] { card["id"] = id }
            if let name = person.object?["name"] { card["name"] = name }
            if let identity = person.object?["identity"] { card["identity"] = identity }
            if let avatar = person.object?["avatar"] { card["avatar"] = avatar }
            suspects.append(.object(card))
        }
        var publicView: [String: PlayWireValue] = ["enabled": .bool(true), "suspects": .array(suspects)]
        if let screens = fields["introScreens"] { publicView["introScreens"] = screens }
        if let board = fields["corkboardImage"] { publicView["corkboardImage"] = board }
        let allowed = fields["earlyAccuse"]?["allowed"].bool == true
        publicView["earlyAccuse"] = .object(["allowed": .bool(allowed)])
        return .object(publicView)
    }

    static func publicOption(_ option: PlayWireValue) -> PlayWireValue {
        guard var fields = option.object else { return option }
        for key in ["correct", "fb", "fbImgs"] { fields.removeValue(forKey: key) }
        return .object(fields)
    }

    static func validateClues(_ value: PlayWireValue) throws {
        guard let rows = value.object, rows.count <= 60 else { try reject("线索名称表格式不正确") }
        for (key, name) in rows {
            guard isClueKey(key) else { try reject("线索标识不合法") }
            guard let raw = text(name) else { try reject("线索名称须为 1 至 20 字") }
            guard (1...20).contains(trimmedCount(raw)) else { try reject("线索名称须为 1 至 20 字") }
        }
    }

    static func validateTimer(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        guard let seconds = value["durationSeconds"].integer, (10...86400).contains(seconds) else {
            try reject("计时时长须为 10 秒至 24 小时")
        }
        guard ["FAILED", "EXPIRED"].contains(text(value["timeoutResult"]) ?? "") else { try reject("计时结果不合法") }
    }

    static func validateRandom(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        let items = value["items"].array ?? []
        guard !items.isEmpty, let draw = value["drawCount"].integer, (1...items.count).contains(draw) else {
            try reject("抽取数量不能超过物品数量")
        }
    }

    static func validateSort(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        let ids = (value["items"].array ?? []).compactMap { text($0["id"]) }
        let order = (value["answerOrder"].array ?? []).compactMap { text($0) }
        if order.sorted() != ids.sorted() || order.count != ids.count { try reject("排序答案必须覆盖全部待排项") }
    }

    static func validateMatch(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        let left = value["left"].array?.count ?? 0
        let right = value["right"].array?.count ?? 0
        if left != right { try reject("连线题右侧须为 \(left) 项") }
    }

    static func validateClassify(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        let bins = Set((value["bins"].array ?? []).compactMap { text($0["id"]) })
        let items = (value["items"].array ?? []).compactMap { text($0["id"]) }
        let answer = value["answer"].object ?? [:]
        for item in items where !bins.contains(text(answer[item] ?? .null) ?? "") {
            try reject("分类答案引用了不存在的分类")
        }
    }

    static func validateCompare(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        if value.object?.keys.contains("effects") == true { try reject("对照题不支持 effects") }
    }

    static func validateBackground(_ value: PlayWireValue) throws {
        guard let fields = value.object else { try reject("背景音乐不合法") }
        if fields.keys.contains("enabled") { try reject("背景音乐不使用 enabled") }
        guard let url = text(fields["audioUrl"] ?? .null), isMedia(url) else { try reject("背景音乐地址不合法") }
    }

    static func validatePhoto(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        guard let tries = value["maxTries"].integer, (1...10).contains(tries) else { try reject("拍照审核的可拍次数须为 1 至 10") }
        guard ["retake", "pass"].contains(text(value["fallback"]) ?? "") else { try reject("拍照审核兜底不合法") }
    }

    static func validateArrivalReading(_ value: PlayWireValue) throws {
        guard let fields = value.object else { try reject("到达读数包含未知字段") }
        if !Set(fields.keys).subtracting(["level", "log"]).isEmpty { try reject("到达读数包含未知字段") }
        if !fields.keys.contains("level") && !fields.keys.contains("log") { try reject("到达读数至少要有 level 或 log") }
        if fields.keys.contains("level"), !((0...3).contains(fields["level"]?.integer ?? -1)) { try reject("到达读数 level 不合法") }
    }

    static func validateArrivalPolicy(_ value: PlayWireValue) throws {
        guard let fields = value.object else { try reject("到达策略包含未知字段") }
        let known: Set<String> = ["version", "radiusMeters", "maxAccuracyMeters", "maxAgeSeconds", "fallbackMode"]
        if !Set(fields.keys).subtracting(known).isEmpty { try reject("到达策略包含未知字段") }
        if fields["version"]?.integer != 1 { try reject("到达策略版本不支持") }
    }

    static func validateCheck(_ value: PlayWireValue) throws {
        guard isEnabled(value) else { return }
        if !["easy", "medium", "hard"].contains(text(value["tier"]) ?? "") { try reject("tier 只允许 easy、medium、hard") }
    }

    static func validateClueTransform(_ value: PlayWireValue) throws {
        guard let fields = value.object, Set(fields.keys).subtracting(["mode"]).isEmpty else { try reject("谜面变换只接受 mode") }
        if !["STANDARD", "MIRROR", "REVERSE"].contains(text(fields["mode"] ?? .null) ?? "STANDARD") { try reject("谜面变换模式不支持") }
    }
}
