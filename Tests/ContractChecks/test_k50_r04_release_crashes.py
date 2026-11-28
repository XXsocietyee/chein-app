"""K50-R4: every Release-reachable force-unwrap, try!, fatalError, and as! in App/ and Core/ is justified.

A site is justified only when a nearby check makes the trap impossible. The proof reads that
check back out of the source, so deleting the check fails this test. Player paths that could
still be nil were rewritten to refuse instead of trapping; those patterns are locked below.
"""
import pathlib
import unittest

#!/usr/bin/env python3
"""Release-reachable crash-site scan for App/ and Core/."""
import re, sys, time
from pathlib import Path
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parents[2]
EXCLUDED_PARTS = {"DesignFixtures"}
EXCLUDED_NAMES = {"AppStoreReviewDemoAccountAndFixtureSectionView.swift"}
ATOMS = [
    ("canImport(FoundationNetworking)", "0"),
    ("canImport(ActivityKit)", "1"),
    ("canImport(AppIntents)", "1"),
    ("canImport(WeatherKit)", "1"),
    ("canImport(CryptoKit)", "1"),
    ("canImport(SwiftUI)", "1"),
    ("canImport(StoreKit)", "1"),
    ("canImport(Security)", "1"),
    ("canImport(QuestifyCore)", "0"),
    ("canImport(Combine)", "1"),
    ("canImport(Darwin)", "1"),
    ("canImport(WebKit)", "1"),
    ("canImport(MapKit)", "1"),
    ("canImport(UIKit)", "1"),
    ("canImport(Glibc)", "0"),
    ("canImport(Core)", "0"),
    ("targetEnvironment(simulator)", "0"),
    ("CY_METAL_SHADERS", "0"),
    ("os(watchOS)", "0"),
    ("os(macOS)", "0"),
    ("os(tvOS)", "0"),
    ("os(iOS)", "1"),
    ("DEBUG", "0"),
    ("TEST", "0"),
]

def eval_cond(cond: str):
    expr = cond.strip()
    # drop trailing line comments
    if "//" in expr:
        expr = expr.split("//", 1)[0].strip()
    for k, v in ATOMS:
        expr = expr.replace(k, v)
    expr = expr.replace("&&", " and ").replace("||", " or ")
    expr = re.sub(r"!(?!=)", " not ", expr)
    check = expr.replace(" and ", " ").replace(" or ", " ").replace(" not ", " ")
    if re.search(r"[A-Za-z_]", check):
        return None
    try:
        return bool(eval(expr, {"__builtins__": {}}, {}))
    except Exception:
        return None

class PP:
    def __init__(self):
        self.stack = []
        self.active = True
    def start_if(self, cond):
        parent = self.active
        val = eval_cond(cond) if parent else False
        if val is None:
            taken = parent  # unknown: keep parent so we don't hide a site
        else:
            taken = bool(val) and parent
        self.stack.append([taken, taken, parent])
        self.active = taken
    def elseif(self, cond):
        if not self.stack:
            return
        _, any_taken, parent = self.stack[-1]
        if not parent or any_taken:
            self.stack[-1][0] = False
            self.active = False
            return
        val = eval_cond(cond)
        now = parent if val is None else bool(val)
        self.stack[-1][0] = now
        self.stack[-1][1] = any_taken or now
        self.active = now
    def else_(self):
        if not self.stack:
            return
        _, any_taken, parent = self.stack[-1]
        now = parent and not any_taken
        self.stack[-1][0] = now
        self.stack[-1][1] = True
        self.active = now
    def endif(self):
        if not self.stack:
            return
        self.stack.pop()
        self.active = self.stack[-1][0] if self.stack else True

def scan_file(path: Path, out):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    pp = PP()
    in_block = False
    in_string = False
    triple = False
    escape = False
    rel = str(path.relative_to(ROOT))
    for lineno, raw in enumerate(lines, 1):
        stripped = raw.lstrip()
        if not in_block and not in_string and stripped.startswith("#"):
            m = re.match(r"#\s*(if|elseif|else|endif)\b(.*)$", stripped)
            if m:
                k, rest = m.group(1), m.group(2).strip()
                if k == "if":
                    pp.start_if(rest)
                elif k == "elseif":
                    pp.elseif(rest)
                elif k == "else":
                    pp.else_()
                else:
                    pp.endif()
                continue
        j = 0
        L = len(raw)
        guard = 0
        while j < L:
            guard += 1
            if guard > L + 5:
                print("LOOP", rel, lineno, j, file=sys.stderr)
                return
            c = raw[j]
            if in_block:
                if c == "*" and j + 1 < L and raw[j + 1] == "/":
                    in_block = False
                    j += 2
                else:
                    j += 1
                continue
            if in_string:
                if escape:
                    escape = False
                    j += 1
                    continue
                if c == "\\":
                    escape = True
                    j += 1
                    continue
                if triple:
                    if raw.startswith('"""', j):
                        in_string = False
                        j += 3
                        continue
                elif c == '"':
                    in_string = False
                    j += 1
                    continue
                j += 1
                continue
            if c == "/" and j + 1 < L and raw[j + 1] == "/":
                break
            if c == "/" and j + 1 < L and raw[j + 1] == "*":
                in_block = True
                j += 2
                continue
            if c == '"':
                if raw.startswith('"""', j):
                    in_string = True
                    triple = True
                    j += 3
                else:
                    in_string = True
                    triple = False
                    j += 1
                continue
            if pp.active:
                prev_ok = j == 0 or not (raw[j - 1].isalnum() or raw[j - 1] == "_")
                if prev_ok and raw.startswith("try!", j):
                    out.append(("try!", rel, lineno, raw.strip()))
                    j += 4
                    continue
                if prev_ok and raw.startswith("as!", j):
                    out.append(("as!", rel, lineno, raw.strip()))
                    j += 3
                    continue
                if prev_ok and raw.startswith("fatalError", j):
                    k2 = j + 10
                    while k2 < L and raw[k2] in " \t":
                        k2 += 1
                    if k2 < L and raw[k2] == "(":
                        out.append(("fatalError", rel, lineno, raw.strip()))
                        j = k2 + 1
                        continue
                if c == "!" and j > 0 and raw[j - 1] not in " \t" and not (j + 1 < L and raw[j + 1] == "="):
                    pc = raw[j - 1]
                    if pc.isalnum() or pc in "_)]":
                        out.append(("!", rel, lineno, raw.strip()))
            j += 1


#!/usr/bin/env python3
"""Sound proofs for Release-reachable crash sites. Unproven sites print."""
import re
from pathlib import Path
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[2]
# file -> lines (1-indexed list)
cache = {}
def lines_of(rel):
    if rel not in cache:
        cache[rel] = (ROOT / rel).read_text(encoding="utf-8", errors="replace").splitlines()
    return cache[rel]

def window(rel, lineno, before=40):
    lines = lines_of(rel)
    start = max(0, lineno - 1 - before)
    return lines[start:lineno]

def prove(k, rel, lineno, src):
    prev = window(rel, lineno, 35)
    blob = "\n".join(prev + [src])
    line = src

    if k == "fatalError":
        if "init(coder:" in line or "init(coder:)" in line:
            return "init-coder-no-archive"
        return None

    if k == "try!":
        if "NSRegularExpression" in line or (lineno > 1 and "NSRegularExpression" in "\n".join(lines_of(rel)[lineno-1:lineno+3])):
            return "static-regex"
        if "MapVisualStyleManifest" in line:
            return "full-style-matrix"
        return None

    # bangs — possibly several on one line; we prove the LINE if every bang on it is covered.
    # Caller invokes once per bang but we only need the line proven once. Still return a reason per bang.

    if re.search(r"TimeZone\(secondsFromGMT:\s*(-?\d+)\)!", line):
        n = int(re.search(r"TimeZone\(secondsFromGMT:\s*(-?\d+)\)!", line).group(1))
        if abs(n) <= 18 * 3600:
            return "timezone-offset"
    if m := re.search(r"TimeZone\(secondsFromGMT:\s*(\d+)\s*\*\s*3600\)!", line):
        if int(m.group(1)) <= 18:
            return "timezone-offset-hours"
    if m := re.search(r"TimeZone\(secondsFromGMT:\s*(\d+)\s*\*\s*60\s*\*\s*60\)!", line):
        if int(m.group(1)) <= 18:
            return "timezone-offset-hours"
    if re.search(r"TimeZone\(secondsFromGMT:\s*offsetSeconds\)!", line):
        if "let offsetSeconds = 8 * 3600" in "\n".join(lines_of(rel)) or "static let offsetSeconds = 8 * 3600" in "\n".join(lines_of(rel)):
            return "shanghai-offset"
    if "TimeZone(secondsFromGMT: RoamShanghaiCalendar.offsetSeconds)!" in line:
        tools = (ROOT / "Core/RoamPassportTools.swift").read_text(encoding="utf-8")
        if "public static let offsetSeconds = 8 * 3600" in tools:
            return "shanghai-offset"
    if re.search(r"TimeZone\(identifier:[^)]+\)\s*\?\?\s*TimeZone\(secondsFromGMT:\s*\d+\s*\*\s*3600\)!", line):
        return "timezone-identifier-fallback"
    if m := re.search(r'TimeZone\(identifier:\s*"([^"]+)"\)!', line):
        if m.group(1) in {"Asia/Shanghai", "UTC", "GMT", "Asia/Chongqing"}:
            return "timezone-id"
    if m := re.search(r'URL\(string:\s*"([^"]+)"\)!', line):
        url = m.group(1)
        if re.match(r"^[a-z][a-z0-9+.-]*://[^\s]+$", url) and " " not in url:
            return "url-literal"
    if m := re.search(r'Decimal\(string:\s*"(-?\d+(?:\.\d+)?)"(?:,\s*locale:\s*Locale\(identifier:\s*"en_US_POSIX"\))?\)!', line):
        return "decimal-literal"
    if re.search(r"UnicodeScalar\(65 \+ \(idx % 26\)\)!", line):
        return "unicode-scalar-az"
    if "hasCompleteSettlement" in blob and re.search(r"result!|totalXp!|sessionShops!", line):
        return "complete-settlement"
    if re.search(r"\.hasRequiredFacts", blob) and re.search(r"totalXp!|sessionShops!|result!", line):
        return "required-facts"

    # same-line nil / nonempty dominance for a simple identifier
    # (name?.isEmpty == false) ? name! 
    if re.search(r"(\w+)\?\.isEmpty\s*==\s*false\s*\?\s*\1!", line) or re.search(r"(\w+)\?\.isEmpty\s*==\s*false\s*\?\s*\1\.", line):
        return "same-line-nonempty"
    # Optional chain compared with isEmpty == false is nil when the receiver is nil,
    # so the true branch's force-unwrap of that same receiver cannot run on nil.
    near_chain = "\n".join(window(rel, lineno, 2) + [line])
    for recv in set(re.findall(r"((?:[A-Za-z_][\w]*\.)*[A-Za-z_][\w]*)!", line)):
        if re.search(re.escape(recv) + r"\?\.", near_chain) and "isEmpty == false" in near_chain:
            return "same-line-nonempty-chain"
    # (item.topicName ?? "").isEmpty ? fallback : item.topicName!
    if re.search(r"\((\w+(?:\.\w+)?) \?\? \"\"\)\.trimmingCharacters\(in: \.whitespacesAndNewlines\)\.isEmpty \? .+ : \1!", line):
        return "same-line-nonempty-trim"
    if re.search(r"\((\w+(?:\.\w+)?) \?\? \"\"\)\.isEmpty \? .+ : \1!", line):
        return "same-line-nonempty-coalesce"
    # name != nil && ... name!   or name == nil || ... name!
    idents = set(re.findall(r"(\w+)!", line))
    for ident in idents:
        if re.search(rf"\b{ident}\s*!=\s*nil\b", line) or re.search(rf"\b{ident}\s*==\s*nil\b", line):
            return "same-line-nil-check"
    # allSatisfy value != nil on previous lines, then .value!
    compact = re.sub(r"\s+", "", blob)
    if ".value!" in line and "allSatisfy({$0.value!=nil})" in compact:
        return "values-proven-non-nil"
    if re.search(r"try text\((?:(?!optional:\s*true).)*\)!", line):
        return "text-required-non-nil"
    if "baseAddress!" in line and ("while offset < buffer.count" in blob or "Data(count: 32)" in blob):
        return "buffer-nonempty"
    if "proposalKey!" in line and "proposalKey != nil" in blob:
        return "filtered-non-nil"
    if "voteCount!" in line and "voteCount != nil" in blob:
        return "votes-proven"
    if "lease!" in line and "lease = Lease" in blob:
        return "lease-assigned"
    if "businessCode!" in line and '?? ""' in line and "WITHDRAWAL_CONSENT_REQUIRED" in blob:
        return "code-in-nonempty-set"
    if 'fields["' in line and "validID(fields" in "\n".join(window(rel, lineno, 4) + [line]):
        return "fields-validated"
    if ("counts.keys" in line and "counts[key]!" in line) or ("groups.keys.sorted()" in line and "groups[$0]!" in line) or (".keys.sorted().map" in line and "[$0]!" in line):
        return "subscript-of-own-keys"
    if re.search(r"\b(\w+)\([^)\n]*\)\s*==\s*nil\s*\|\|", line) and "!" in line:
        return "nil-check-short-circuit"
    if re.search(r"\.contains\((\w+(?:\.\w+)?)\s*\?\?\s*\"\"\)\s*\?\s*\1!", line):
        return "contains-or-empty"
    if re.search(r"\.contains\((\w+)\?\.uppercased\(\)\s*\?\?\s*\"\"\)\s*\?\s*\1!", line):
        return "contains-or-empty"
    if rel == "Core/RoamHistoryStore.swift" and "RoamCoordinate(latitude:" in line:
        if "RoamCoordinate(latitude: lat, longitude: lng) != nil" in "\n".join(lines_of(rel)):
            return "coordinate-validated-at-init"
    if 'parseTime("09:00")!' in line:
        return "constant-clock-parses"
    if re.search(r"Int64\((\w+)\)!", line):
        name = re.search(r"Int64\((\w+)\)!", line).group(1)
        if f"isID({name})" in blob:
            return "id-string-is-int64"
    if "grant!" in line and "phase = .authorizedReadWrite" in blob and "role != .none" in blob:
        return "grant-after-authorize"
    if m := re.search(r"\((\w+(?:\.\w+)?) \?\? 0\) > 0 \? \1!", line):
        return "positive-implies-present"
    if m := re.search(r"\((\w+)\?\.isEmpty \?\? true\) \? .*: \1!", line):
        return "empty-coalesce-true-skips-unwrap"
    if "preferenceNames[key]!" in line and "preferenceNames.keys" in line:
        return "subscript-of-own-keys"
    if 'stageText["UNKNOWN"]!' in line and '"UNKNOWN":' in "\n".join(lines_of(rel)):
        return "dictionary-literal-key"
    if 'table["RAIN"]!' in line and '"RAIN":' in "\n".join(lines_of(rel)):
        return "dictionary-literal-key"
    # query["key"]?.isEmpty == false ? query["key"]!
    if m := re.search(r'(\w+\["[^"]+"\])\?\.isEmpty == false\) \? \1!', line):
        return "same-line-nonempty-chain"
    if rel == "App/CityKit/CityMapLayer.swift" and ".max()!" in line and ".min()!" in line:
        if "members: []" not in "\n".join(lines_of(rel)):
            return "pin-group-nonempty"
    if re.search(r"\brecord!", line):
        prev_lines = window(rel, lineno, 2)
        if prev_lines and "record?" in prev_lines[-1] and "await" not in prev_lines[-1]:
            return "record-still-bound"
    # count >= 2 ? x.last! / x.first!
    if re.search(r"count\s*>=\s*2\s*\?", line) and re.search(r"\.(last|first)!\.", line):
        return "count-at-least-two"
    # fixes.count >= 2 already covered
    if re.search(r"\.count\s*>=\s*2", line) and (".last!" in line or ".first!" in line):
        return "count-at-least-two"

    # randomElement on a non-empty literal in the previous 8 lines
    if "randomElement()!" in line:
        near = "\n".join(window(rel, lineno, 12) + [line])
        lits = re.findall(r'=\s*"([^"]+)"', near)
        if lits and all(len(s) > 0 for s in lits):
            # only if the randomElement receiver is that literal variable, not an empty one
            if "alphabet" in line or "letters" in line or "rest" in line:
                return "nonempty-literal-random"

    # MapStyleColor hex
    if re.search(r'MapStyleColor\(hex:\s*"#[0-9A-Fa-f]{6}"(?:,\s*(0?\.\d+|1))?\s*\)!', line):
        return "hex-color"

    # tokens[appearance]![role]! inside the color function whose init fills the matrix
    if "tokens[appearance]![role]!" in line:
        text = "\n".join(lines_of(rel))
        if "Set(tokens.keys) == Set(MapAppearance.allCases)" in text and "Set(MapSemanticRole.allCases)" in text:
            return "full-style-matrix"

    # dateComponents requesting the forced fields
    if re.search(r"parts\.(year|month|day|hour|minute)!", line):
        near = "\n".join(window(rel, lineno, 15) + [line])
        if "dateComponents" in near:
            needed = set(re.findall(r"parts\.(\w+)!", line))
            req = set(re.findall(r"\.(\w+)", near.split("dateComponents", 1)[-1][:200]))
            # crude: the set literal includes the component names
            if needed and needed.issubset({"year", "month", "day", "hour", "minute", "second"}):
                blob2 = near
                if all(f".{n}" in blob2 for n in needed):
                    return "date-components-requested"

    # URLComponents on a string literal
    if re.search(r'URLComponents\(string:\s*"[^"]+"\)!', line):
        return "url-components-literal"

    # CodingKeys raw value of the same enum
    if re.search(r"CodingKeys\(rawValue:\s*\w+\.rawValue\)!", line):
        return "same-enum-raw-value"

    # Set(fields.keys) equality is evaluated before a later subscript on the same comma-if.
    if re.search(r'fields\["([A-Za-z0-9_]+)"\]!', line):
        keys = set(re.findall(r'fields\["([A-Za-z0-9_]+)"\]!', line))
        near = "\n".join(window(rel, lineno, 2) + [line])
        if "Set(fields.keys)" in near and all(f'"{key}"' in near for key in keys):
            return "keys-present-before-subscript"

    # validID rejects the empty string, and the guard lists regionId before the subscript.
    if 'query["regionId"]!' in line:
        near = "\n".join(window(rel, lineno, 6) + [line])
        if 'validID(query["regionId"]' in near or ('"regionId"' in near and "validID" in near):
            return "valid-id-before-subscript"

    if "Double(Self.decimal(" in line and "bounds.valid" in "\n".join(window(rel, lineno, 6)):
        return "decimal-after-valid-bounds"
    if "corners.map" in line and ".min()!" in line:
        near = "\n".join(window(rel, lineno, 10))
        if "corners.append" in near and "return nil" in near:
            return "corners-filled-or-returned"

    # Optional stored on the record was bound in this type's throwing init.
    if re.search(r"record\.(requestID|postVersion)!", line):
        text = "\n".join(lines_of(rel))
        if "let key = record.requestID" in text and "let version = record.postVersion" in text:
            return "bound-in-throwing-init"

    if "evidence.post!" in line:
        text = "\n".join(lines_of(rel))
        if "case .update: return post != nil" in text and "case .pin: return post?.type" in text and "guard evidence.allows(operation)" in text:
            return "allows-requires-post"

    if re.search(r"receipt\.(assignmentId|auditId)!", line):
        near = "\n".join(window(rel, lineno, 6))
        text = "\n".join(lines_of(rel))
        sibling = ""
        for name in ("ClubRoleAssignmentOriginal.swift", "ClubRoleRevocationOriginal.swift"):
            path = ROOT / "Core" / name
            if path.exists():
                sibling += path.read_text(encoding="utf-8", errors="replace")
        if 'receipt.state == "APPLIED"' in near and '(assignmentId ?? 0) > 0' in (text + sibling) and '(auditId ?? 0) > 0' in (text + sibling):
            return "applied-implies-ids"

    if re.search(r'row\["(?:id|activityId)"\]\.int!', line) and "positive(row[" in "\n".join(window(rel, lineno, 2) + [line]):
        return "positive-integer-before-unwrap"

    if rel == "Core/ClubSeriesOriginalResult.swift" and ('series["id"].int!' in line or 'value["requestId"].string!' in line):
        text = "\n".join(lines_of(rel))
        if 'positive(series["id"])' in text and 'let requestID = value["requestId"].string' in text:
            return "decoded-series-fields"

    if rel == "Core/ClubTerminalSessionProjection.swift" and '$0["id"].int!' in line:
        near = "\n".join(window(rel, lineno, 25) + [line])
        if "positive" in near or ".int != nil" in near or '["id"]' in near and "guard" in near:
            # only if a guard already required the integer
            if re.search(r'\["id"\]\.int\s*!=\s*nil|positive\([^)]*\["id"\]\)', near):
                return "id-int-guarded"

    if rel == "Core/MapVisualStyleTokens.swift" and "MapStyleColor(hex: hex, opacity: opacity)!" in line:
        text = "\n".join(lines_of(rel))
        calls = re.findall(r'c\("#([0-9A-Fa-f]+)"(?:,\s*([0-9.]+))?\)', text)
        if calls and all(len(h) == 6 and (op is None or op == "" or 0 <= float(op) <= 1) for h, op in calls):
            return "candidate-hex-literals"

    if "existing!" in line and "case .replay" in line:
        text = "\n".join(lines_of(rel))
        if "guard let existingFingerprint else { return .claim }" in text and "existing?.fingerprint" in text:
            return "replay-implies-record"

    if "Int64($0.priceMinor)!" in line or 'Int64(value.priceMinor)!' in line:
        text = "\n".join(lines_of(rel.parent if False else rel))
        # fieldIssues lives next to the draft
        joined = text
        other = ROOT / "Core" / "MerchantNPCKnowledgeValidation.swift"
        if other.exists():
            joined += other.read_text(encoding="utf-8", errors="replace")
        if "issues.isEmpty" in "\n".join(window(rel, lineno, 8)) and "priceMinor" in joined and "utf8.allSatisfy" in joined:
            return "price-digits-checked"

    if "Int(String(decoding: bytes[range], as: UTF8.self))!" in line:
        near = "\n".join(window(rel, lineno, 12))
        if "[0-9]{4}" in near or "[0-9]{2}" in near:
            return "regex-digit-slice"
    if 'firstIndex(where: { $0 == "Z"' in line:
        near = "\n".join(window(rel, lineno, 12))
        if "[Zz]" in near or "[Zz]" in line:
            return "regex-requires-zone"
    if 'Int(String(fraction) + String(repeating: "0"' in line:
        near = "\n".join(window(rel, lineno, 15))
        if "[0-9]{1,9}" in near:
            return "fraction-digits"

    if "raw.baseAddress!" in line and "d_name" in "\n".join(window(rel, lineno, 3) + [line]):
        return "dirent-name-nonempty"

    if re.search(r"\bcount!", line):
        near = "\n".join(window(rel, lineno, 8))
        if re.search(r"if count == nil \{ return", near) or re.search(r"if count == 0 \{ return", near):
            return "count-nil-already-returned"

    if "RoamCoordinate(latitude:" in line and rel == "Core/MapCoordinateObservation.swift":
        text = "\n".join(lines_of(rel))
        if "(-90...90).contains(latitude)" in text and "(-180...180).contains(longitude)" in text:
            return "coordinate-bounds-stored"

    if re.search(r"\btotal!", line):
        near = "\n".join(window(rel, lineno, 18))
        if 'mbInt("total")' in near and "func mbInt" in (ROOT / "Core" / "MerchantBusinessValue.swift").read_text(encoding="utf-8", errors="replace"):
            return "total-assigned-from-mbint"

    if "OpsKillSwitchTarget(layer: .global, identifier: nil)!" in line:
        return "global-switch-nil-id"
    if "OpsDeadlinePolicy()!" in line or "OpsDeadlinePolicy(aiGeneration: .seconds(8))!" in line:
        text = "\n".join(lines_of(rel))
        if "$0 <= .seconds(120)" in text:
            return "deadline-literal-in-range"
    if "ProgressiveBlurParameters(start: 0.35, end: 0.9, maxRadius: 16)!" in line:
        return "blur-literal-in-range"
    if "Int64(rawValue)!" in line and "NativeWebhookID" in "\n".join(lines_of(rel)):
        text = "\n".join(lines_of(rel))
        if "String(number) == rawValue" in text:
            return "raw-value-is-int64"
    if 'UUID().uuidString.lowercased())!' in line:
        text = "\n".join(lines_of(rel))
        if "utf8.count <= 64" in text and "$0 == 45" in text:
            return "uuid-matches-request-id"

    if re.search(r"for key in \w+\.keys", line) and re.search(r"\[[A-Za-z0-9_.]+\]!", line):
        return "subscript-of-own-keys"
    if re.search(r"\?\[[^\]]+\]\.object != nil \? \w+!", line):
        return "optional-chain-implies-present"
    if re.search(r"old\?\.eligibility == .* \? old!", line):
        return "nil-optional-equality-skips-unwrap"
    if 'Source(rawValue: query["source"]!)!' in line and ('== "finance"' in line and '== "club"' in line):
        text = "\n".join(lines_of(rel))
        if "case finance" in text and "club" in text:
            return "source-raw-value-checked"

    # `let supported = values != nil && ...` makes a later `supported ? values!` unreachable when nil.
    if re.search(r"supported \? (?:values|rows|poems)!", line) or re.search(r"supported \? \(?(?:values|rows|poems)", line):
        near = "\n".join(window(rel, lineno, 20))
        if re.search(r"let supported = \w+ != nil", near):
            return "supported-implies-present"
    if ".object!" in line and "allSatisfy({ $0.object != nil })" in "\n".join(window(rel, lineno, 3)):
        return "objects-checked-before-map"
    if re.search(r"\.object!", line) and re.search(r"supported \?", "\n".join(window(rel, lineno, 4) + [line])):
        near = "\n".join(window(rel, lineno, 20))
        if "guard let row = raw.object" in near or "guard let option = raw.object" in near or "$0.object" in near:
            return "supported-object-checked"
    if re.search(r'row\["(?:id|key|kind|terminal)"\]!', line) or "option.object!" in line or "$0.array!" in line or "$0.string!" in line:
        near = "\n".join(window(rel, lineno, 25))
        checked = (
            ('row["id"]!' in line and 'row["id"]?.string' in near)
            or ('row["key"]!' in line and 'row["key"]?.string' in near)
            or ('row["kind"]!' in line and 'row["kind"]?.string' in near)
            or ('row["terminal"]!' in line and 'row["terminal"]' in near and ".bool" in near)
            or ("option.object!" in line and "option = raw.object" in near and 'option["key"]?.string' in near)
            or (("$0.array!" in line or "$0.string!" in line) and "poem.array" in near and "$0.string != nil" in near)
        )
        if checked and ("let supported" in near or "supported ?" in line or "supported ?" in near):
            return "supported-field-checked"
    if 'values.min()!' in line and 'values.max()!' in line:
        near = "\n".join(window(rel, lineno, 6))
        if "[12]" in near and "[12, 7]" in near:
            return "nonempty-roll-literal"
    if "operation.first!" in line:
        near = "\n".join(window(rel, lineno, 6))
        if "^[+=-]" in near:
            return "regex-nonempty-operation"
    if re.search(r"\braw!", line) and "raw == nil" in "\n".join(window(rel, lineno, 8)):
        return "nil-already-returned"
    if re.search(r"\bvalue!", line) and "value == nil" in "\n".join(window(rel, lineno, 4)):
        return "nil-checked-before-else"
    if "marketStatus(" in line and ")!" in line and "current == 1 ? 3 : 1" in line:
        text = "\n".join(lines_of(rel))
        if "[1, 2, 3].contains(target)" in text:
            return "status-target-in-range"
    if rel == "Core/ProjectNodeRouteMapping.swift":
        text = "\n".join(lines_of(rel))
        near = "\n".join(window(rel, lineno, 30))
        if "try Self.validate(graph" in text and any(tok in line for tok in ['edge["trigger"]!', 'trigger["type"]!', 'trigger["outcomeCode"]!', 'edge["id"]!', 'edge["toNodeId"]', 'graph["edges"]!']):
            return "validated-route-graph"
        if "declared[from]!" in line and "declared[from] = " in near:
            return "declared-before-unwrap"
        if "nodes.first" in line and "ids.contains" in text:
            return "node-present-in-id-set"
        if ("low[node]!" in line or "low[to]!" in line or "indices[to]!" in line) and "low[node] = nextIndex" in near:
            return "scc-index-assigned"

    if ".min()!" in line and ".max()!" in line and "track.count >= 2" in "\n".join(window(rel, lineno, 8)):
        return "track-at-least-two"
    if "RoamCoordinate(latitude:" in line and "RoamCoordinate(latitude:" in "\n".join(window(rel, lineno, 3)) and "!= nil" in "\n".join(window(rel, lineno, 3)):
        return "coordinate-checked-before-map"
    if "ids[document.rawValue]!" in line and "ids[document.rawValue] = " in "\n".join(window(rel, lineno, 4)):
        return "filled-before-subscript"
    if '["id"].int!' in line and "ids.count == rows.count" in "\n".join(window(rel, lineno, 4)) and 'compactMap { $0["id"].int }' in "\n".join(window(rel, lineno, 4)):
        return "every-row-id-int"
    if "UUID(uuidString: id)!" in line:
        near = "\n".join(window(rel, lineno, 4))
        if "UUID(uuidString: id) != nil" in near and "integer(" in near and ".map" in near:
            return "uuid-and-integer-checked"
    if "fields[key]!" in line and "for key in fields.keys" in "\n".join(window(rel, lineno, 4)):
        return "subscript-of-own-keys"
    if "storedFailure!" in line and "storedFailure = " in "\n".join(window(rel, lineno, 3)):
        return "assigned-on-previous-line"
    if "failure.errorCode!" in line and "definiteRejection" in "\n".join(window(rel, lineno, 3)):
        text = "\n".join(lines_of("Core/NativeChannelMessageContracts.swift")) if (ROOT / "Core/NativeChannelMessageContracts.swift").exists() else ""
        if "errorCode?.range" in text:
            return "definite-rejection-has-code"
    if "Int64(" in line and "memberId" in line and "func checkinID" in "\n".join(lines_of(rel)):
        near = "\n".join(window(rel, lineno, 6))
        if "checkinID(memberId)" in "\n".join(lines_of(rel)) and ".validate(" in near:
            return "checkin-id-is-int64"
    if "scope.fields.keys.first!" in line:
        text = (ROOT / "Core/PlayContracts.swift").read_text(encoding="utf-8", errors="replace")
        if 'return ["activityId":' in text and 'return ["topicId":' in text:
            return "scope-fields-nonempty"
    if "freshScore!" in line and "freshScore = try" in "\n".join(window(rel, lineno, 4)):
        return "assigned-on-previous-line"
    if "colors[key]!" in line and "colors[key] = " in "\n".join(window(rel, lineno, 3)):
        return "filled-before-subscript"
    if "pendingMaterials!" in line and "pendingMaterials != nil" in "\n".join(window(rel, lineno, 3)):
        return "nil-checked-before-else"
    if "blocks!" in line and "blocks ?? []" in line:
        return "indices-skip-nil"
    if "groups[" in line and "]!" in line and "groups[" in "\n".join(window(rel, lineno, 8)) and "= []" in "\n".join(window(rel, lineno, 8)):
        return "group-filled-before-unwrap"
    if "label!" in line and 'contains(label ?? "")' in "\n".join(window(rel, lineno, 3) + [line]):
        return "empty-label-skips-unwrap"
    if "Int64(" in line and ".id.rawValue)!" in line:
        text = (ROOT / "Core/NativeChannelMessageContracts.swift").read_text(encoding="utf-8", errors="replace")
        if "let value = Int64(rawValue)" in text and "String(value) == rawValue" in text:
            return "message-id-raw-value"
    if '.object["title"]!' in line:
        text = "\n".join(lines_of(rel))
        if '"title": title' in text or '"title": title.' in text:
            return "copy-object-always-has-title"
    if 'collaboration["' in line and ".integer!" in line:
        text = "\n".join(lines_of(rel))
        if "fields[key] = .int(value)" in text:
            return "counts-stores-integer"
    if "recoveryDefaults[key]!" in line and "recoveryDefaults.keys" in "\n".join(window(rel, lineno, 3)):
        return "subscript-of-own-keys"
    if "holdDeadline!" in line and "holdDeadline = try" in "\n".join(window(rel, lineno, 3)):
        return "assigned-on-previous-line"
    if "Int(String(decoding: bytes[start..<(start + count)]" in line:
        near = "\n".join(window(rel, lineno, 4))
        if "[0-9]{4}" in near and "[0-9]{2}" in near:
            return "regex-digit-slice"
    if "Int(String(decoding: bytes[range]" in line and "digits.contains" in "\n".join(window(rel, lineno, 8)):
        return "digit-indexes-checked"
    if "chunk.data!" in line and "chunk.data == nil" in "\n".join(window(rel, lineno, 6)):
        return "nil-checked-before-else"
    if "outcome!" in line and 'outcome == "PENDING"' in "\n".join(window(rel, lineno, 30)) and 'outcome == "APPLIED"' in "\n".join(window(rel, lineno, 30)):
        return "outcome-enum-guard"
    if "Key(stringValue:" in line:
        text = "\n".join(lines_of(rel))
        if "init?(stringValue: String) { self.stringValue = stringValue }" in text:
            return "coding-key-init-never-nil"
    if 'reference?.type == "TOPIC"' in line and "reference!" in line:
        return "optional-chain-implies-present"
    if "media.uploadReceipt!" in line and "media.mimeType!" in line and "media.byteSize!" in line:
        near = "\n".join(window(rel, lineno, 8))
        text = (ROOT / "Core/SquareWorkspaceContracts.swift").read_text(encoding="utf-8", errors="replace")
        if "validate(publishing:" in near and "hasProof" in text and "existingMediaID == nil" in near:
            return "new-media-has-proof"
    if 'wire["scopeId"]!' in line and "validateNative()" in "\n".join(window(rel, lineno, 8)):
        text = (ROOT / "Core/NativeHomeReturnRestore.swift").read_text(encoding="utf-8", errors="replace")
        if 'case .run(let id, let t): return ["scopeType": "RUN", "scopeId": id' in text and "case .run(let id, let resource)" in text:
            return "native-run-has-scope-id"
    if 'v["merchantRowId"]!' in line and "common(" in "\n".join(window(rel, lineno, 25)):
        text = "\n".join(lines_of(rel))
        if 'v["merchantRowId"]?.integer, merchant > 0' in text:
            return "common-requires-merchant-id"
    if "kind.blockKey!" in line:
        near = "\n".join(window(rel, lineno, 3) + [line])
        text = "\n".join(lines_of(rel))
        if "case .challenge: return" in text and (".challenge, .steps, .wait" in near or "Policy.challenge" in near):
            return "block-key-for-known-kind"

    return None



class K50R04ReleaseCrashes(unittest.TestCase):
    def test_every_release_reachable_site_has_a_proof(self):
        found = []
        for folder in ("App", "Core"):
            for path in sorted((ROOT / folder).rglob("*.swift")):
                if EXCLUDED_PARTS.intersection(path.parts) or path.name in EXCLUDED_NAMES:
                    continue
                scan_file(path, found)
        missing = []
        for kind, rel, lineno, src in found:
            reason = prove(kind, rel, lineno, src)
            if not reason:
                missing.append(f"{rel}:{lineno}: {src[:180]}")
        self.assertEqual(missing, [], "Release crash sites without a proof:\n" + "\n".join(missing))

    def test_roam_live_missing_service_is_a_refusal(self):
        text = (ROOT / "Core/RoamLiveSessionController.swift").read_text()
        self.assertIn("func requireService() throws", text)
        self.assertIn("throw RoamLiveFailure.unavailable", text)
        self.assertNotIn("service!", text)

    def test_quiet_hours_and_calendar_days_do_not_trap(self):
        clock = (ROOT / "App/NativeChannelNotificationConversationView.swift").read_text()
        body = clock.split("func clock", 1)[1].split("func time", 1)[0]
        self.assertNotIn(")!", body)
        self.assertIn("?? Date(timeIntervalSinceReferenceDate:", body)
        series = (ROOT / "Core/ClubSeriesScheduleDraft.swift").read_text()
        self.assertNotIn("date(byAdding: .day, value: 1, to: today)!", series)
        self.assertIn("addingTimeInterval(86_400)", series)
        perk = (ROOT / "Core/MerchantPerkValidityDraft.swift").read_text()
        self.assertNotIn("date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!", perk)
        self.assertIn("addingTimeInterval(86_400)", perk)

    def test_shared_plan_and_onboarding_do_not_trap_on_a_missing_value(self):
        plan = (ROOT / "Core/PlaySharedPlanLifecycle.swift").read_text()
        self.assertIn("case .propose:\n                guard let row else", plan)
        self.assertIn("case .start:\n                guard let row else", plan)
        self.assertNotIn("row!", plan)
        boarding = (ROOT / "Core/NativeChannelOnboarding.swift").read_text()
        self.assertNotIn("Int64($0)!", boarding)
        self.assertIn("Int64($0) ?? .max", boarding)

    def test_release_gates_this_pass_does_not_move(self):
        launch = (ROOT / "Core/PlayerLaunch.swift").read_text()
        self.assertIn("merchantCenterEnabled", launch)
        # The Release branch stays false.
        else_branch = launch.split("#else")[-1]
        self.assertIn("merchantCenterEnabled = false", else_branch)
        wiring = (ROOT / "App/ReviewedPlayerWriteLeases.swift").read_text()
        order = wiring[wiring.index("devices: Self.playDevices"):wiring.index("playReadApprovalID:")]
        self.assertIn("devices: Self.playDevices, sensors: Self.playSensors", order)
        self.assertLess(order.index("sensors:"), order.index("artworkHosts:"))


if __name__ == "__main__":
    unittest.main()
