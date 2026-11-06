import Foundation

/// Source-bound author diagnostics only. Original server compilation and publication remain authoritative.
public enum NativeConditionAuthorValidation {
    public static let comparisons = ["EQ", "NE", "GT", "GTE", "LT", "LTE"]
    public static let conditionOperations = comparisons + ["ALL_OF", "ANY_OF", "NOT", "EQ_STR", "IN", "ITEM_HELD", "ITEM_ACQUIRED", "CONSUME_ITEM", "NODE_COMPLETED", "HAS_TAG", "VISIT_COUNT", "EDGE_VISITS", "ROLE_IN", "TIME_BETWEEN"]
    public static let effectOperations = ["SET", "INC", "FLOOR", "ADD_TAG", "SET_STR", "ADD_ITEM", "REMOVE_ITEM", "GRANT_BADGE", "UNLOCK_NODE", "RANDOM_CHOICE", "EMIT_EVENT"]
    public static let componentEffectOperations = effectOperations + ["ADD", "MIN", "MAX", "RESET", "CLAMP"]
    public static let registeredOperations = ["CHECK_RESULT", "HAS_CONDITION", "ITEM_EQUIPPED"]
    public static let roles = ["NAVIGATOR", "OBSERVER", "RECORDER", "NEGOTIATOR", "DECODER"]
    public static let dependencies: [String: String] = [
        "AT_NODE": "原非 generic BRANCH_GRAPH 缺到达事实适配，不能用 currentNodeId 或设备位置替代。",
        "TIME_LEFT": "原 route/chapter 缺权威截止时间；TIME egg 不是 deadline。",
        "TEAM_SIZE": "缺绑定本 route session 的唯一队伍事实源。",
        "TEAM_HAS_TAG": "缺绑定本 route session 的团队标签合同。",
        "WEATHER_IN": "缺包含来源、时效、位置归属的天气事实接口。"
    ]

    public static func issues(_ document: NativeConditionAuthorDocument, catalog: NativeConditionAuthorCatalog,
                              attributes: NativeConditionAuthorAttributeProjection?) -> [NativeConditionAuthorIssue] {
        var validator = Validator(document: document, catalog: catalog, projection: attributes)
        validator.run(); return validator.issues
    }

    private struct Validator {
        let document: NativeConditionAuthorDocument
        let catalog: NativeConditionAuthorCatalog
        let projection: NativeConditionAuthorAttributeProjection?
        var issues: [NativeConditionAuthorIssue] = []
        var numbers = Set<String>(), strings = Set<String>(), readonly = Set<String>()
        var nodes = Set<Int64>(), edges = Set<String>()
        var expressionTotal = 0
        mutating func fail(_ path: String, _ code: String, _ detail: String = "") {
            if issues.count < 256 { issues.append(.init(path: path, code: code, detail: detail)) }
        }
        mutating func run() {
            if !document.canRoundTrip { fail("$", "lossless"); return }
            if let rpg = catalog.rpg, rpg.scope != document.scope || rpg.definitionVersion.isEmpty { fail("$", "registryScope"); return }
            for fact in catalog.numericFacts { numbers.insert(fact.id); readonly.insert(fact.id) }
            if let projection {
                if projection.scope != document.scope || projection.definitionVersion.isEmpty { fail("$", "attributeScope"); return }
                var keys = Set<String>()
                for reference in projection.references {
                    guard keys.insert(reference.key).inserted else { fail("$", "attributeDuplicate", reference.key); continue }
                    if reference.type == .number { numbers.insert(reference.key) } else { strings.insert(reference.key) }
                    if !reference.writable { readonly.insert(reference.key) }
                }
            }
            if [.componentCondition, .componentEffects, .componentCheck].contains(document.surface) {
                guard let binding = catalog.component, !binding.definitionVersion.isEmpty, projection != nil,
                      catalog.nodes.contains(where: { $0.id == String(binding.nodeID) }) else { fail("$", "registryScope"); return }
                nodes = Set(catalog.nodes.compactMap { Int64($0.id) }); edges = Set(catalog.edges.map(\.id))
                switch document.surface {
                case .componentCondition: componentCondition(document.value, "$")
                case .componentEffects: var count = 0; effectList(document.value, "$", 1, &count)
                case .componentCheck: componentCheck(binding)
                default: break
                }
                return
            }
            if document.surface == .attributeCondition {
                // Original RouteAttributeConditionAdapter validates rules.when through the
                // same recursive compiler, but requires canonical registered keys and a
                // read-only boolean result. Template grammar remains a separate contract.
                guard let projection else { fail("$", "attributeScope"); return }
                numbers = Set(projection.references.filter { $0.type == .number && !$0.key.hasPrefix("tag.") }.map(\.key))
                strings = []
                nodes = Set(catalog.nodes.compactMap { Int64($0.id) }.filter { $0 > 0 })
                edges = Set(catalog.edges.map(\.id))
                var count = 0
                let result = conditionNode(document.value, "$", 0, false, &count)
                if result.consumes { fail("$", "readonly", "CONSUME_ITEM") }
                return
            }
            if document.surface != .routeGraph {
                // TemplateAdvancedConfig's current author grammar is a separate consumer.
                // No evidence permits installing RouteConditions recursively into variants/check effects.
                fail("$", "templateContract", "TemplateRootAuthoring.swift:TemplateAuthorCondition / TemplateEffectList.swift；缺原模板验证器的递归语法及权威回读合同。")
                return
            }
            guard document.isExplicitV2, let root = document.value.nativeConditionObject else {
                fail("$.routeExpressionVersion", "version", "只编辑 schemaVersion=1、routeExpressionVersion=2；缺版本为旧语法，不自动升级。")
                return
            }
            fields(root, ["schemaVersion", "routeExpressionVersion", "startNodeId", "terminalNodeIds", "variables", "stringVariables", "edges", "fallbacks", "nodeRequirements", "themeConfig", "journeyRules"], "$")
            declarations(root["variables"], string: false, path: "$.variables")
            declarations(root["stringVariables"], string: true, path: "$.stringVariables")
            if !numbers.isDisjoint(with: strings) { fail("$.variables", "typeConflict") }
            let sourceNodes = Set(catalog.nodes.compactMap { Int64($0.id) })
            func id(_ raw: ProjectEditJSON?) -> Int64? { guard let n = raw?.nativeConditionInteger, n > 0 else { return nil }; return n }
            if let start = id(root["startNodeId"]) { nodes.insert(start) } else { fail("$.startNodeId", "node") }
            if let terminal = root["terminalNodeIds"]?.nativeConditionArray, !terminal.isEmpty, terminal.count <= 1024 {
                for (i, raw) in terminal.enumerated() { if let n = id(raw) { nodes.insert(n) } else { fail("$.terminalNodeIds[\(i)]", "node") } }
            } else { fail("$.terminalNodeIds", "terminals") }
            for name in ["edges", "fallbacks"] {
                if name == "fallbacks" && root[name] == nil { continue }
                guard let rows = root[name]?.nativeConditionArray, rows.count <= 1024 else { fail("$." + name, "array"); continue }
                for (i, raw) in rows.enumerated() {
                    let path = "$.\(name)[\(i)]"
                    guard let row = raw.nativeConditionObject else { fail(path, "object"); continue }
                    for field in ["fromNodeId", "toNodeId"] {
                        if let n = id(row[field]) { nodes.insert(n) } else { fail(path + "." + field, "node") }
                    }
                    if name == "edges", let key = row["id"]?.nativeConditionText {
                        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || key.utf16.count > 64 || !edges.insert(key).inserted { fail(path + ".id", "edge") }
                    } else if name == "edges" { fail(path + ".id", "edge") }
                }
            }
            for node in nodes where !sourceNodes.contains(node) { fail("$", "nodeScope", String(node)) }
            for node in nodes { numbers.insert("sys.passed.\(node)"); readonly.insert("sys.passed.\(node)") }
            var fallbackSources = Set<Int64>()
            for name in ["edges", "fallbacks"] {
                for (i, raw) in (root[name]?.nativeConditionArray ?? []).enumerated() {
                    guard let row = raw.nativeConditionObject else { continue }
                    let path = "$.\(name)[\(i)]", fallback = name == "fallbacks"
                    fields(row, ["id", "fromNodeId", "toNodeId", "trigger", "conditions", "effects", "once", "allowLoop", "weight", "priority", "maxVisits"], path)
                    for key in ["once", "allowLoop"] { if let v = row[key], case .bool = v {} else if row[key] != nil { fail(path + "." + key, "boolean") } }
                    for key in ["weight", "priority", "maxVisits"] {
                        if let v = row[key] {
                            let minimum: Int64 = key == "weight" ? 1 : key == "priority" ? -1000 : 0
                            let maximum: Int64 = key == "priority" ? 1000 : 10000
                            guard let n = v.nativeConditionInteger, n >= minimum, n <= maximum else { fail(path + "." + key, "integer"); continue }
                        }
                    }
                    if fallback {
                        if row["conditions"] != nil { fail(path + ".conditions", "fallbackCondition") }
                        if let from = row["fromNodeId"]?.nativeConditionInteger, !fallbackSources.insert(from).inserted { fail(path, "duplicateFallback") }
                    } else {
                        if let trigger = row["trigger"]?.nativeConditionObject,
                           let type = trigger["type"]?.nativeConditionText, let outcome = trigger["outcomeCode"]?.nativeConditionText {
                            fields(trigger, ["type", "outcomeCode"], path + ".trigger")
                            if !catalog.triggers.contains(where: { $0.id == type }) { fail(path + ".trigger.type", "triggerScope", type) }
                            let sourceID = row["fromNodeId"]?.nativeConditionInteger.map(String.init) ?? ""
                            if !(catalog.sourceOutcomes[sourceID] ?? []).contains(where: { $0.triggerType == type && $0.code == outcome }) { fail(path + ".trigger.outcomeCode", "outcomeScope", sourceID + ":" + type + ":" + outcome) }
                        } else { fail(path + ".trigger", "trigger") }
                        if let condition = row["conditions"] { var count = 0; _ = conditionNode(condition, path + ".conditions", 0, false, &count) }
                    }
                    if let effect = row["effects"] { var count = 0; effectList(effect, path + ".effects", 1, &count) }
                }
            }
            if let requirements = root["nodeRequirements"] { nodeRequirements(requirements, sourceNodes: sourceNodes) }
            for issue in NativeConditionAuthorGraphValidation.issues(document.value, catalog: catalog) { fail(issue.path, issue.code, issue.detail) }
            if expressionTotal > 4096 { fail("$", "totalLimit") }
        }
        mutating func componentCondition(_ value: ProjectEditJSON, _ path: String) {
            var count = 0
            if conditionNode(value, path, 0, false, &count).consumes { fail(path, "readonly", "CONSUME_ITEM") }
        }
        mutating func componentCheck(_ binding: NativeComponentAuthorBinding) {
            guard let encoded = try? NativeAttributeAuthorWire.encode(document.value), encoded.count <= 24 * 1024 else { fail("$", "totalLimit", "原 RPG check 24 KiB 合同"); return }
            guard let row = document.value.object, let original = document.originalValue.object,
                  row["enabled"] == .bool(true), binding.checkEnabled else { fail("$", "registryScope"); return }
            // The original check identity and specialized owner fields cannot be changed by this form.
            for key in Set(row.keys).union(original.keys) where !NativeComponentAuthorDraft.checkFields.contains(key) {
                if !NativeConditionAuthorTree.exact(row[key], original[key]) { fail("$." + key, "readonly") }
            }
            guard let id = row["checkId"]?.text, catalog.rpg?.checks.contains(where: { $0.id == id }) == true else { fail("$.checkId", "registryReference"); return }
            let skill = row["skill"]?.text ?? ""
            if !binding.counters.contains(skill) && binding.skills[skill] == nil { fail("$.skill", "undeclared", skill) }
            if let category = row["category"]?.text {
                if !["PHY", "OBS", "SOC", "WIL"].contains(category) { fail("$.category", "unknownField") }
            } else if row["category"] != nil || binding.skills[skill] == nil { fail("$.category", "required") }
            if !["easy", "medium", "hard"].contains(row["tier"]?.text ?? "") { fail("$.tier", "required") }
            if let kind = row["kind"], !binding.whiteRed || !["WHITE", "RED"].contains(kind.text ?? "") { fail("$.kind", "registryReference") }
            if row["retryIf"] != nil && (!binding.whiteRed || row["kind"] != .string("WHITE")) { fail("$.retryIf", "registryReference") }
            for key in ["successText", "failText"] where row[key] != nil { _ = text(row, key, "$", max: 2000, strict: false) }
            if let tag = row["failCostTag"], !binding.tags.contains(tag.text ?? "") { fail("$.failCostTag", "undeclared") }
            if let value = row["mods"] {
                guard let mods = value.array, mods.count <= 128 else { fail("$.mods", "array"); return }
                for (i, raw) in mods.enumerated() {
                    let path = "$.mods[\(i)]"
                    guard let mod = raw.object else { fail(path, "object"); continue }
                    fields(mod, ["label", "value", "var", "when"], path)
                    _ = text(mod, "label", path, max: 80, strict: false)
                    if (mod["value"] != nil) == (mod["var"] != nil) { fail(path, "required") }
                    if mod["value"] != nil { _ = integer(mod, "value", path, min: -1_000_000, max: 1_000_000) }
                    if let variable = mod["var"]?.text {
                        if !binding.counters.contains(variable) && !binding.skills.keys.contains(where: { "skill." + $0 == variable }) { fail(path + ".var", "undeclared", variable) }
                    } else if mod["var"] != nil { fail(path + ".var", "string") }
                    if let condition = mod["when"] { componentCondition(condition, path + ".when") }
                }
            }
            for key in ["advantageIf", "disadvantageIf", "retryIf"] {
                if let value = row[key] {
                    if key != "retryIf", value.array == nil || (value.array?.count ?? 0) > 128 { fail("$." + key, "array") }
                    componentCondition(value, "$." + key)
                }
            }
            for key in ["successEffects", "failEffects", "critEffects", "fumbleEffects"] {
                guard let value = row[key] else { continue }
                if value.array == nil || (value.array?.count ?? 0) > 128 { fail("$." + key, "array") }
                // Existing specialized effect contracts remain with their owner. Untouched source
                // survives, but this form cannot edit an unsupported effect into a false-ready state.
                if !NativeConditionAuthorTree.exact(value, original[key]) { var count = 0; effectList(value, "$." + key, 1, &count) }
            }
        }

        mutating func nodeRequirements(_ value: ProjectEditJSON, sourceNodes: Set<Int64>) {
            guard let rows = value.nativeConditionArray else { fail("$.nodeRequirements", "array"); return }
            var seen = Set<Int64>()
            for (i, raw) in rows.enumerated() {
                let path = "$.nodeRequirements[\(i)]"
                guard let row = raw.nativeConditionObject else { fail(path, "object"); continue }
                fields(row, ["nodeId", "allowedTicketIds", "allowedPurchaseKinds", "requiredRoleCodes", "requireOpen", "requireReachable", "maxDistanceMeters"], path)
                if let node = integer(row, "nodeId", path, min: 1), !sourceNodes.contains(node) || !seen.insert(node).inserted { fail(path + ".nodeId", "nodeScope") }
                for field in ["allowedTicketIds", "allowedPurchaseKinds"] where row[field] != nil {
                    guard let values = row[field]?.nativeConditionArray, !values.isEmpty else { fail(path + "." + field, "nonempty"); continue }
                    var unique = Set<Int64>()
                    for value in values {
                        guard let n = value.nativeConditionInteger, n > 0, field != "allowedPurchaseKinds" || n <= 3, unique.insert(n).inserted else { fail(path + "." + field, "integer"); continue }
                    }
                }
                if row["requiredRoleCodes"] != nil {
                    let values = stringList(row, "requiredRoleCodes", path).map(javaTrim)
                    if !Set(values).isSubset(of: Set(roles)) || Set(values).count != values.count { fail(path + ".requiredRoleCodes", "role") }
                }
                for field in ["requireOpen", "requireReachable"] {
                    if let value = row[field], case .bool = value {} else if row[field] != nil { fail(path + "." + field, "boolean") }
                }
                if let distance = row["maxDistanceMeters"] {
                    if !finite(distance) || (distance.nativeConditionNumber ?? 0) <= 0 || (distance.nativeConditionNumber ?? 0) > 1_000_000 { fail(path + ".maxDistanceMeters", "number") }
                }
            }
        }

        mutating func declarations(_ value: ProjectEditJSON?, string: Bool, path: String) {
            guard let value else { return }
            guard let object = value.nativeConditionObject, object.count <= 256 else { fail(path, "declarations"); return }
            for (key, value) in object {
                if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || key.utf16.count > 128 { fail(path + "." + key, "variable") }
                if passed(key) || key.hasPrefix("sys.quest.") || OriginalRpgGrowthFacts.reserved(key) || NativeRpgEnvironmentTemplateDraft.conditionKeys.contains(key) || OriginalRpgProgressConditions.reserved(key) { fail(path + "." + key, "readonly"); continue }
                if string {
                    guard let text = value.nativeConditionText, text.utf16.count <= 4096 else { fail(path + "." + key, "string"); continue }; strings.insert(key)
                } else {
                    guard finite(value) else { fail(path + "." + key, "number"); continue }; numbers.insert(key)
                }
            }
        }
        func passed(_ key: String) -> Bool { key.hasPrefix("sys.passed.") }
        func finite(_ value: ProjectEditJSON?) -> Bool {
            guard let value = value?.nativeConditionNumber else { return false }; return NSDecimalNumber(decimal: value).doubleValue.isFinite
        }
        mutating func fields(_ object: [String: ProjectEditJSON], _ allowed: Set<String>, _ path: String) {
            for key in object.keys.sorted() where !allowed.contains(key) { fail(path + "." + key, "unknownField") }
        }
        func javaTrim(_ value: String) -> String {
            let scalars = Array(value.unicodeScalars); var start = 0, end = scalars.count
            while start < end && scalars[start].value <= 32 { start += 1 }
            while end > start && scalars[end - 1].value <= 32 { end -= 1 }
            return String(String.UnicodeScalarView(scalars[start..<end]))
        }
        mutating func text(_ object: [String: ProjectEditJSON], _ key: String, _ path: String, max: Int = 128, empty: Bool = false, strict: Bool = true) -> String? {
            guard let text = object[key]?.nativeConditionText, text.utf16.count <= max,
                  empty || (!javaTrim(text).isEmpty && (!strict || text == javaTrim(text))) else { fail(path + "." + key, "string"); return nil }
            return text
        }
        mutating func number(_ object: [String: ProjectEditJSON], _ key: String, _ path: String) {
            if !finite(object[key]) { fail(path + "." + key, "number") }
        }
        mutating func integer(_ object: [String: ProjectEditJSON], _ key: String, _ path: String, min: Int64 = 0, max: Int64 = Int64.max) -> Int64? {
            guard let n = object[key]?.nativeConditionInteger, n >= min, n <= max else { fail(path + "." + key, "integer"); return nil }; return n
        }
        mutating func variable(_ object: [String: ProjectEditJSON], _ path: String, string: Bool, write: Bool) {
            guard let key = text(object, "var", path, strict: !write) else { return }
            if !(string ? strings : numbers).contains(key) { fail(path + ".var", "undeclared", key) }
            if write && (readonly.contains(key) || passed(key) || key.hasPrefix("sys.quest.") || OriginalRpgGrowthFacts.reserved(key) || NativeRpgEnvironmentTemplateDraft.conditionKeys.contains(key) || OriginalRpgProgressConditions.reserved(key)) { fail(path + ".var", "readonly", key) }
            if passed(key) {
                let suffix = String(key.dropFirst("sys.passed.".count))
                if let id = Int64(suffix), id > 0, suffix == String(id), nodes.contains(id), !string {} else { fail(path + ".var", "nodeScope", key) }
            }
        }
        mutating func node(_ object: [String: ProjectEditJSON], _ path: String) {
            if let id = integer(object, "nodeId", path, min: 1), !nodes.contains(id) { fail(path + ".nodeId", "nodeScope", String(id)) }
        }
        mutating func stringList(_ object: [String: ProjectEditJSON], _ key: String, _ path: String) -> [String] {
            guard let array = object[key]?.nativeConditionArray, !array.isEmpty, array.count <= 200 else { fail(path + "." + key, "strings"); return [] }
            var strings: [String] = []
            for (i, value) in array.enumerated() {
                guard let text = value.nativeConditionText, text.utf16.count <= 4096 else { fail(path + ".\(key)[\(i)]", "string"); continue }
                // Swift String equality normalizes Unicode; backend Java compares exact code units.
                if strings.contains(where: { $0.utf8.elementsEqual(text.utf8) }) { fail(path + ".\(key)[\(i)]", "duplicate") }
                strings.append(text)
            }
            return strings
        }
        /// Returns consumption-plan bounds; does not evaluate a condition or choose a branch.
        mutating func conditionNode(_ value: ProjectEditJSON, _ path: String, _ depth: Int, _ negated: Bool, _ count: inout Int) -> (plans: Int, consumes: Bool) {
            count += 1; expressionTotal += value.nativeConditionObject?["op"] == nil ? 0 : 1
            guard depth <= 16, count <= 512 else { fail(path, "conditionLimit"); return (1, false) }
            if let array = value.nativeConditionArray { return conditionChildren(array, path, depth, negated, &count, any: false) }
            guard let row = value.nativeConditionObject, let op = text(row, "op", path, max: 32) else { fail(path, "object"); return (1, false) }
            if let dependency = dependencies[op] { fail(path, "backendDependency", op + ": " + dependency); return (1, false) }
            if comparisons.contains(op) {
                fields(row, ["op", "var", "value"], path); variable(row, path, string: false, write: false); number(row, "value", path)
                return (1, false)
            }
            switch op {
            case "ALL_OF", "ANY_OF":
                fields(row, ["op", "children"], path)
                guard let children = row["children"]?.nativeConditionArray, !children.isEmpty else { fail(path + ".children", "nonempty"); return (1, false) }
                return conditionChildren(children, path + ".children", depth, negated, &count, any: op == "ANY_OF")
            case "NOT":
                fields(row, ["op", "child"], path)
                if let child = row["child"] { _ = conditionNode(child, path + ".child", depth + 1, true, &count) } else { fail(path + ".child", "required") }
            case "EQ_STR", "IN":
                fields(row, op == "IN" ? ["op", "var", "values"] : ["op", "var", "value"], path)
                variable(row, path, string: true, write: false)
                if op == "IN" { _ = stringList(row, "values", path) } else { _ = text(row, "value", path, max: 4096, empty: true) }
            case "ITEM_HELD", "ITEM_ACQUIRED", "CONSUME_ITEM":
                fields(row, ["op", "itemId", "quantity"], path)
                if let item = text(row, "itemId", path, max: 64) {
                    let allowed = op == "CONSUME_ITEM" ? catalog.items : catalog.items + catalog.medals
                    if !allowed.contains(where: { $0.id == item }) { fail(path + ".itemId", "itemScope", item) }
                }
                _ = integer(row, "quantity", path, min: 1, max: op == "CONSUME_ITEM" ? 999 : Int64(Int32.max))
                if op == "CONSUME_ITEM" { if negated { fail(path, "consumeUnderNot") }; return (1, true) }
            case "NODE_COMPLETED": fields(row, ["op", "nodeId"], path); node(row, path)
            case "HAS_TAG":
                fields(row, ["op", "value"], path)
                if let key = text(row, "value", path), document.surface == .attributeCondition,
                   projection?.references.contains(where: { $0.key.utf8.elementsEqual(key.utf8) }) != true {
                    fail(path + ".value", "undeclared", key)
                }
            case "VISIT_COUNT", "EDGE_VISITS":
                fields(row, op == "VISIT_COUNT" ? ["op", "nodeId", "comparator", "value"] : ["op", "edgeId", "comparator", "value"], path)
                if op == "VISIT_COUNT" { node(row, path) }
                else if let edge = text(row, "edgeId", path, max: 64), !edges.contains(edge) { fail(path + ".edgeId", "edgeScope", edge) }
                if let comparator = row["comparator"], !comparisons.contains(comparator.nativeConditionText ?? "") { fail(path + ".comparator", "comparator") }
                _ = integer(row, "value", path)
            case "ROLE_IN":
                fields(row, ["op", "values"], path)
                if !Set(stringList(row, "values", path)).isSubset(of: Set(roles)) { fail(path + ".values", "role") }
            case "TIME_BETWEEN":
                fields(row, ["op", "start", "end"], path)
                let start = integer(row, "start", path), end = integer(row, "end", path)
                if let start, let end, end <= start { fail(path, "timeWindow") }
            case "CHECK_RESULT", "HAS_CONDITION", "ITEM_EQUIPPED":
                guard let rpg = catalog.rpg, rpg.supportedOperations.contains(op) else { fail(path, "registryDependency", op); return (1, false) }
                if op == "CHECK_RESULT" {
                    fields(row, ["op", "checkId", "in"], path)
                    if let check = row["checkId"]?.nativeConditionText, rpg.checks.contains(where: { $0.id == check }) {} else { fail(path + ".checkId", "registryReference") }
                    let results = stringList(row, "in", path)
                    if results.count > 64 || !Set(results).isSubset(of: Set(rpg.checkResults.map(\.id))) { fail(path + ".in", "registryReference") }
                } else {
                    fields(row, ["op", "value"], path)
                    let options = op == "HAS_CONDITION" ? rpg.conditions : rpg.equipment
                    if let value = row["value"]?.nativeConditionText, options.contains(where: { $0.id == value }) {} else { fail(path + ".value", "registryReference") }
                }
            default: fail(path + ".op", "unknownOperation", op + "；未提供对应原 registry 编译合同。")
            }
            return (1, false)
        }
        mutating func conditionChildren(_ children: [ProjectEditJSON], _ path: String, _ depth: Int, _ negated: Bool, _ count: inout Int, any: Bool) -> (plans: Int, consumes: Bool) {
            let parsed = children.enumerated().map { i, value in conditionNode(value, path + "[\(i)]", depth + 1, negated, &count) }
            let consumes = parsed.contains { $0.consumes }
            var bound = any && consumes ? 0 : 1
            for child in parsed {
                if any && consumes { bound = min(4097, bound + child.plans) }
                else if !any { bound = min(4097, bound * child.plans) }
            }
            if bound > 4096 { fail(path, "planLimit") }
            return (bound, consumes)
        }
        mutating func effectList(_ value: ProjectEditJSON, _ path: String, _ depth: Int, _ count: inout Int) {
            guard let rows = value.nativeConditionArray else { fail(path, "array"); return }
            guard depth <= 16, rows.count <= 256 else { fail(path, "effectLimit"); return }
            for (i, value) in rows.enumerated() {
                let path = path + "[\(i)]"; count += 1; expressionTotal += 1
                if count > 256 { fail(path, "effectLimit"); return }
                guard let row = value.nativeConditionObject, let op = text(row, "op", path, strict: false) else { fail(path, "object"); continue }
                if let dependency = dependencies[op] { fail(path, "backendDependency", dependency); continue }
                let allowed: Set<String>
                switch op {
                case "SET", "INC", "FLOOR", "SET_STR":
                    allowed = ["op", "var", "value"]; variable(row, path, string: op == "SET_STR", write: true)
                    if op == "SET_STR" { _ = text(row, "value", path, max: 4096, empty: true) } else { number(row, "value", path) }
                    if op == "FLOOR", !(row["var"]?.nativeConditionText ?? "").hasPrefix("counter.") { fail(path + ".var", "floorCounter") }
                    if catalog.component?.dynamicCounters.contains(row["var"]?.text ?? "") == true {
                        _ = integer(row, "value", path, min: -2_147_483_648, max: 2_147_483_647)
                    }
                case "ADD", "MIN", "MAX", "RESET", "CLAMP":
                    allowed = ["RESET", "CLAMP"].contains(op) ? ["op", "var"] : ["op", "var", "value"]
                    guard let binding = catalog.component else { fail(path, "unknownOperation", op); continue }
                    variable(row, path, string: false, write: true)
                    if !binding.dynamicCounters.contains(row["var"]?.text ?? "") { fail(path + ".var", "undeclared") }
                    if !["RESET", "CLAMP"].contains(op) { _ = integer(row, "value", path, min: -2_147_483_648, max: 2_147_483_647) }
                case "ADD_TAG": allowed = ["op", "value"]; _ = text(row, "value", path, strict: false)
                case "ADD_ITEM", "REMOVE_ITEM":
                    allowed = ["op", "itemId", "quantity"]
                    if let item = text(row, "itemId", path, strict: false), !catalog.items.contains(where: { $0.id == item }) { fail(path + ".itemId", "itemScope", item) }
                    _ = integer(row, "quantity", path, min: 1, max: 999)
                case "GRANT_BADGE":
                    allowed = ["op", "scope", "badgeId"]
                    if row["scope"] != .string("TOPIC_MEDAL") { fail(path + ".scope", "topicMedal") }
                    if let badge = text(row, "badgeId", path, strict: false), !catalog.medals.contains(where: { $0.id == badge }) { fail(path + ".badgeId", "medalScope", badge) }
                case "UNLOCK_NODE": allowed = ["op", "nodeId"]; node(row, path)
                case "EMIT_EVENT":
                    allowed = ["op", "type", "payload"]
                    if row["type"] != .string("CUSTOM") || row["payload"]?.nativeConditionObject?.isEmpty != true {
                        fail(path, "backendDependency", "仅支持原个人节点/结果的 CUSTOM 属性事件；其他事件类型和非空载荷未接通。")
                    }
                case "RANDOM_CHOICE":
                    allowed = ["op", "choices"]
                    guard let choices = row["choices"]?.nativeConditionArray, !choices.isEmpty, choices.count <= 32 else { fail(path + ".choices", "choices"); continue }
                    for (c, value) in choices.enumerated() {
                        count += 1; let branch = path + ".choices[\(c)]"
                        if count > 256 { fail(branch, "effectLimit"); return }
                        guard let choice = value.nativeConditionObject else { fail(branch, "object"); continue }
                        fields(choice, ["weight", "effects"], branch)
                        _ = integer(choice, "weight", branch, min: 1, max: 10000)
                        if let effects = choice["effects"] { effectList(effects, branch + ".effects", depth + 1, &count) } else { fail(branch + ".effects", "required") }
                    }
                default: fail(path + ".op", "unknownOperation", op); continue
                }
                fields(row, allowed, path)
                for key in allowed where row[key] == nil { fail(path + "." + key, "required") }
            }
        }
    }
}
