#!/usr/bin/env python3
"""Write a schema-only copy for a later throwaway database.

This does not open a socket, start a database client, SSH, boot a jar, or
deploy. Rollback verification only compares a local file's SHA-256 prefix and
does not print the rest of the digest.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import io
import os
import re
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

ROLLBACK_SHA256_PREFIX = "655a377a"
ROLLBACK_COMMIT = "014fc0d8"
BACKEND_REPO = "liboyang42-cpu/chengyin"
FORBIDDEN_HOSTS = ("47.103.124.64", "chengyinhub.com", "chengyinhub.cn")
AMBIENT_KEYS = (
    "DATABASE_URL",
    "MYSQL_PWD",
    "MYSQL_HOST",
    "SPRING_DATASOURCE_URL",
    "SPRING_DATASOURCE_PASSWORD",
    "SPRING_DATASOURCE_USERNAME",
)
MAX_SCHEMA_BYTES = 32 * 1024 * 1024
DEPLOY_GATE = 'Deploy happens only after the owner writes "deploy now".'

_SECRET = re.compile(
    r"(?i)(identified\s+by|private\s+key|begin\s+(?:rsa|openssh|certificate)\b|"
    r"aws_secret_access_key|password\s*=|set\s+password\b|pwd\s*=|secret\s*=|mysql://|jdbc:|"
    r"://[^/\s:]+:[^/\s@]+@)"
)
_SSH = re.compile(r"(?i)\bssh\b|ssh://")
_DDL = re.compile(
    r"(?is)^(?:create\s+(?:unique\s+|fulltext\s+|spatial\s+)?index|"
    r"create\s+table|alter\s+table|drop\s+table|drop\s+index)\b"
)
_DATA = re.compile(
    r"(?is)\b(?:insert|truncate|select)\b|\breplace\s+into\b|"
    r"\bload\s+data\b|\binto\s+(?:outfile|dumpfile)\b|\bload_file\s*\("
)
_LOCK = re.compile(r"(?is)^lock\s+tables\s+.+\s+(?:write|read)\s*$")
_UNLOCK = re.compile(r"(?is)^unlock\s+tables\s*$")
_SET_PART = re.compile(
    r"(?is)^(?:names\s+\w+(?:\s+collate\s+\w+)?|character\s+set\s+\w+|charset\s+\w+|"
    r"(?:foreign_key_checks|unique_checks|sql_notes|autocommit)\s*=\s*[01]|"
    r"sql_mode\s*=\s*'(?:[A-Z0-9_]|'')*'|"
    r"time_zone\s*=\s*'(?:[+-0-9:]|'')*'|time_zone\s*=\s*@@\w+|"
    r"(?:character_set_client|character_set_results|collation_connection)\s*=\s*\w+|"
    r"@\w+\s*=\s*(?:@@\w+|'(?:[A-Za-z0-9_]|'')*'|[01]))$"
)


class Refusal(Exception):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def guard_text(text: str) -> None:
    lowered = text.lower()
    for host in FORBIDDEN_HOSTS:
        if host in lowered:
            raise Refusal("production-host")
    if _SSH.search(text):
        raise Refusal("remote-shell")
    if _SECRET.search(text):
        raise Refusal("secret-like-material")


def guard_ambient() -> None:
    for key in AMBIENT_KEYS:
        value = os.environ.get(key)
        if not value:
            continue
        guard_text(value)
        raise Refusal("ambient-database-env")


def mask_literals(statement: str) -> str:
    out: list[str] = []
    index = 0
    length = len(statement)
    while index < length:
        mark = statement[index]
        if mark not in "'\"`":
            out.append(mark)
            index += 1
            continue
        out.append(mark)
        index += 1
        while index < length:
            if statement[index] == "\\" and mark != "`":
                index += 2
                continue
            if statement[index] == mark:
                if mark != "`" and index + 1 < length and statement[index + 1] == mark:
                    index += 2
                    continue
                out.append(mark)
                index += 1
                break
            index += 1
    return "".join(out)


def split_statements(sql: str) -> list[str]:
    if sql.startswith("\ufeff"):
        sql = sql[1:]
    sql = sql.replace("\r\n", "\n").replace("\r", "\n")
    statements: list[str] = []
    buf: list[str] = []
    index = 0
    length = len(sql)
    quote: str | None = None
    while index < length:
        mark = sql[index]
        if quote is not None:
            buf.append(mark)
            if mark == "\\" and quote != "`":
                if index + 1 < length:
                    buf.append(sql[index + 1])
                    index += 2
                    continue
            if mark == quote:
                if quote != "`" and index + 1 < length and sql[index + 1] == quote:
                    buf.append(sql[index + 1])
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if mark in "'\"`":
            quote = mark
            buf.append(mark)
            index += 1
            continue
        if sql.startswith("--", index) or (mark == "#" and (index == 0 or sql[index - 1] == "\n")):
            end = sql.find("\n", index)
            index = length if end < 0 else end + 1
            continue
        if sql.startswith("/*", index):
            if sql.startswith("/*!", index):
                cursor = index + 3
                while cursor < length and sql[cursor].isdigit():
                    cursor += 1
                end = sql.find("*/", cursor)
                if end < 0:
                    raise Refusal("unterminated-comment")
                inner = sql[cursor:end].strip()
                if inner.endswith(";"):
                    inner = inner[:-1].strip()
                if inner:
                    statements.extend(split_statements(inner))
                index = end + 2
                continue
            end = sql.find("*/", index + 2)
            if end < 0:
                raise Refusal("unterminated-comment")
            index = end + 2
            continue
        if mark == ";":
            text = "".join(buf).strip()
            buf.clear()
            if text:
                statements.append(text)
            index += 1
            continue
        buf.append(mark)
        index += 1
    if quote is not None:
        raise Refusal("unterminated-literal")
    tail = "".join(buf).strip()
    if tail:
        statements.append(tail)
    return statements


def is_session_set(masked: str) -> bool:
    if not re.match(r"(?is)^set\s+", masked):
        return False
    body = re.sub(r"(?is)^set\s+", "", masked).strip().rstrip(";")
    parts = [part.strip() for part in body.split(",") if part.strip()]
    return bool(parts) and all(_SET_PART.match(part) for part in parts)


def classify(statement: str) -> str:
    masked = mask_literals(statement).strip()
    if _DATA.search(masked):
        raise Refusal("row-data")
    if _DDL.match(masked):
        return "ddl"
    if _LOCK.match(masked) or _UNLOCK.match(masked) or is_session_set(masked):
        return "noise"
    raise Refusal("unreviewed-statement")


def schema_copy(sql: str) -> tuple[list[str], int]:
    guard_text(sql)
    ddl: list[str] = []
    noise = 0
    for statement in split_statements(sql):
        kind = classify(statement)
        if kind == "ddl":
            ddl.append(statement.strip())
        else:
            noise += 1
    if not ddl:
        raise Refusal("schema-copy-empty")
    return ddl, noise


def read_schema(path: Path) -> str:
    if path.is_symlink():
        raise Refusal("refusing-symlink")
    try:
        info = path.stat()
    except OSError:
        raise Refusal("schema-file-unreadable") from None
    if not path.is_file():
        raise Refusal("schema-file-unreadable")
    if info.st_size > MAX_SCHEMA_BYTES:
        raise Refusal("schema-file-too-large")
    try:
        raw = path.read_bytes()
    except OSError:
        raise Refusal("schema-file-unreadable") from None
    if b"\0" in raw:
        raise Refusal("schema-file-not-text")
    try:
        return raw.decode("utf-8")
    except UnicodeError:
        raise Refusal("schema-file-not-text") from None


def prepare_out(path: Path) -> Path:
    guard_text(str(path))
    if path.is_symlink():
        raise Refusal("refusing-output-path")
    resolved = path.resolve()
    root = repo_root()
    try:
        resolved.relative_to(root)
    except ValueError:
        inside = False
    else:
        inside = True
    if inside:
        raise Refusal("refusing-output-inside-repo")
    if resolved.exists() or path.exists():
        raise Refusal("refusing-output-path")
    parent = path.parent
    if parent.is_symlink() or not parent.is_dir():
        raise Refusal("refusing-output-path")
    path.mkdir(mode=0o700)
    return path


def write_copy(schema_file: Path, out_dir: Path) -> None:
    guard_ambient()
    guard_text(str(schema_file))
    text = read_schema(schema_file)
    ddl, noise = schema_copy(text)
    destination = prepare_out(out_dir)
    body = ";\n\n".join(ddl) + ";\n"
    schema_path = destination / "schema-only.sql"
    report_path = destination / "rehearsal-report.txt"
    schema_path.write_text(body, encoding="utf-8")
    schema_path.chmod(0o600)
    report = (
        "schema_copy_only=true\n"
        f"ddl_statements={len(ddl)}\n"
        f"session_statements_dropped={noise}\n"
        "applied_to_database=false\n"
        "network=false\n"
        "production_host_contacted=false\n"
        "deploy=false\n"
    )
    report_path.write_text(report, encoding="utf-8")
    report_path.chmod(0o600)
    print(f"schema-copy-only statements={len(ddl)}")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def verify_rollback_jar(path: Path, prefix: str = ROLLBACK_SHA256_PREFIX) -> str:
    if re.fullmatch(r"[0-9a-f]{8}", prefix) is None:
        raise Refusal("rollback-prefix-unusable")
    guard_text(str(path))
    if path.is_symlink():
        raise Refusal("refusing-symlink")
    try:
        info = path.stat()
    except OSError:
        raise Refusal("rollback-jar-unreadable") from None
    if not path.is_file():
        raise Refusal("rollback-jar-unreadable")
    if info.st_size == 0:
        raise Refusal("rollback-jar-empty")
    digest = sha256_file(path)
    if digest.startswith(prefix):
        return f"rollback-jar-prefix-match commit={ROLLBACK_COMMIT} repo={BACKEND_REPO}"
    return "rollback-jar-prefix-mismatch"


def guard_invocation(argv: list[str]) -> None:
    for arg in argv:
        guard_text(arg)


def dispatch(argv: list[str]) -> int:
    guard_invocation(argv)
    if argv == ["--self-check"]:
        self_check()
        print("self-check-ok")
        return 0
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--schema-copy-only", action="store_true")
    parser.add_argument("--schema-file")
    parser.add_argument("--out")
    parser.add_argument("--verify-rollback-jar")
    try:
        args = parser.parse_args(argv)
    except SystemExit:
        raise Refusal("usage") from None
    modes = [args.schema_copy_only, args.verify_rollback_jar is not None]
    if sum(bool(mode) for mode in modes) != 1:
        raise Refusal("usage")
    if args.verify_rollback_jar is not None:
        guard_ambient()
        print(verify_rollback_jar(Path(args.verify_rollback_jar)))
        return 0
    if not args.schema_file or not args.out:
        raise Refusal("usage")
    write_copy(Path(args.schema_file), Path(args.out))
    return 0


def run_cli(argv: list[str], env: dict[str, str | None] | None = None) -> tuple[int, str, str]:
    saved = os.environ.copy()
    stdout, stderr = io.StringIO(), io.StringIO()
    try:
        for key in AMBIENT_KEYS:
            os.environ.pop(key, None)
        if env is not None:
            for key, value in env.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        with redirect_stdout(stdout), redirect_stderr(stderr):
            try:
                code = dispatch(argv)
            except Refusal as exc:
                print(f"refusing {exc.code}", file=sys.stderr)
                code = 2
    finally:
        os.environ.clear()
        os.environ.update(saved)
    return code, stdout.getvalue(), stderr.getvalue()


def assert_source_boundaries() -> None:
    source = Path(__file__).read_text(encoding="utf-8")
    tree = ast.parse(source)
    banned = {"socket", "subprocess", "urllib", "http", "ftplib", "telnetlib", "paramiko", "requests", "ssl"}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.split(".")[0] in banned:
                    raise AssertionError(alias.name)
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if module.split(".")[0] in banned:
                raise AssertionError(module)
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            owner = node.func.value
            if isinstance(owner, ast.Name) and owner.id == "os" and node.func.attr in {
                "system",
                "popen",
                "exec",
                "execl",
                "execv",
                "spawnl",
                "spawnv",
            }:
                raise AssertionError(node.func.attr)
    if re.search(r"655a377a[0-9a-f]{56}", source):
        raise AssertionError("full rollback digest recorded")
    plan = Path(__file__).with_name("backend-deploy-plan.md").read_text(encoding="utf-8")
    if DEPLOY_GATE not in plan:
        raise AssertionError("deploy gate missing")
    for token in (ROLLBACK_SHA256_PREFIX, ROLLBACK_COMMIT, BACKEND_REPO, "docs/release/staging-schema-rehearsal.py"):
        if token not in plan:
            raise AssertionError(token)
    if re.search(r"655a377a[0-9a-f]{56}", plan):
        raise AssertionError("plan records the rest of the digest")
    if re.search(r"014fc0d8[0-9a-f]{32}", plan) or re.search(r"623d18ca[0-9a-f]{32}", plan):
        raise AssertionError("plan invents a full commit id")


def self_check() -> None:
    assert_source_boundaries()
    secret = "fixture-secret-not-a-real-credential"
    good = """
-- local schema copy
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
LOCK TABLES `place` WRITE;
DROP TABLE IF EXISTS `place`;
CREATE TABLE `place` (
  `id` bigint NOT NULL,
  `note` varchar(32) NOT NULL DEFAULT 'a;b',
  `label` varchar(32) NOT NULL DEFAULT 'it''s',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_place` FOREIGN KEY (`id`) REFERENCES `other` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE UNIQUE INDEX `idx_place_note` ON `place` (`note`);
/*!40000 ALTER TABLE `place` ENABLE KEYS */;
UNLOCK TABLES;
"""
    ddl, noise = schema_copy(good)
    if len(ddl) != 4 or noise < 5:
        raise AssertionError((len(ddl), noise))
    if any("LOCK" in statement or statement.upper().startswith("SET") for statement in ddl):
        raise AssertionError("session noise was copied")
    if "a;b" not in ddl[1] or "ON DELETE CASCADE" not in ddl[1]:
        raise AssertionError("ddl was split or dropped")
    for bad, code in (
        ("INSERT INTO place VALUES (1);", "row-data"),
        ("CREATE TABLE place AS SELECT 1 AS id;", "row-data"),
        ("CREATE USER app IDENTIFIED BY hidden;", "secret-like-material"),
        ("-- host 47.103.124.64\nCREATE TABLE t (id int);", "production-host"),
        (f"-- password={secret}\nCREATE TABLE t (id int);", "secret-like-material"),
        ("ssh staging\nCREATE TABLE t (id int);", "remote-shell"),
        ("SET PASSWORD FOR app = 'hidden';", "secret-like-material"),
        ("CREATE VIEW v AS SELECT 1;", "row-data"),
        ("LOCK TABLES `place` WRITE;", "schema-copy-empty"),
    ):
        try:
            schema_copy(bad)
        except Refusal as exc:
            if exc.code != code:
                raise AssertionError((code, exc.code)) from None
        else:
            raise AssertionError(code)
    with tempfile.TemporaryDirectory(prefix="schema-rehearsal-") as temporary:
        root = Path(temporary)
        schema = root / "schema.sql"
        schema.write_text(good, encoding="utf-8")
        out = root / "copy"
        code, stdout, stderr = run_cli(["--schema-copy-only", "--schema-file", str(schema), "--out", str(out)])
        if code != 0 or "schema-copy-only statements=4" not in stdout or stderr:
            raise AssertionError((code, stdout, stderr))
        written = (out / "schema-only.sql").read_text(encoding="utf-8")
        report = (out / "rehearsal-report.txt").read_text(encoding="utf-8")
        if "INSERT" in written or "LOCK TABLES" in written or "CREATE TABLE" not in written:
            raise AssertionError("written copy is not schema-only")
        for line in (
            "schema_copy_only=true",
            "applied_to_database=false",
            "network=false",
            "production_host_contacted=false",
            "deploy=false",
        ):
            if line not in report:
                raise AssertionError(line)
        try:
            out.resolve().relative_to(repo_root())
        except ValueError:
            pass
        else:
            raise AssertionError("copy was written inside the repo")
        mixed = root / "mixed.sql"
        mixed.write_text(good + "\nINSERT INTO place VALUES (1);\n", encoding="utf-8")
        mixed_out = root / "mixed-out"
        code, stdout, stderr = run_cli(
            ["--schema-copy-only", "--schema-file", str(mixed), "--out", str(mixed_out)]
        )
        if code != 2 or mixed_out.exists() or secret in stdout or secret in stderr:
            raise AssertionError((code, stdout, stderr, mixed_out.exists()))
        if "refusing row-data" not in stderr:
            raise AssertionError(stderr)
        link = root / "linked.sql"
        link.symlink_to(schema)
        code, _stdout, stderr = run_cli(
            ["--schema-copy-only", "--schema-file", str(link), "--out", str(root / "link-out")]
        )
        if code != 2 or "refusing refusing-symlink" not in stderr:
            raise AssertionError(stderr)
        inside = repo_root() / "docs" / "release" / ".schema-rehearsal-out"
        code, _stdout, stderr = run_cli(["--schema-copy-only", "--schema-file", str(schema), "--out", str(inside)])
        if code != 2 or inside.exists() or "refusing refusing-output-inside-repo" not in stderr:
            raise AssertionError(stderr)
        code, stdout, stderr = run_cli(
            ["--schema-copy-only", "--schema-file", f"/tmp/{FORBIDDEN_HOSTS[0]}.sql", "--out", str(root / "host-out")],
            env={AMBIENT_KEYS[0]: None},
        )
        if code != 2 or FORBIDDEN_HOSTS[0] in stdout or "refusing production-host" not in stderr:
            raise AssertionError((stdout, stderr))
        code, stdout, stderr = run_cli(
            ["--schema-copy-only", "--schema-file", str(schema), "--out", str(root / "ambient-out")],
            env={AMBIENT_KEYS[0]: f"mysql://app:{secret}@{FORBIDDEN_HOSTS[0]}/app"},
        )
        if code != 2 or (root / "ambient-out").exists() or secret in stdout + stderr or FORBIDDEN_HOSTS[0] in stdout + stderr:
            raise AssertionError((stdout, stderr))
        if "refusing production-host" not in stderr and "refusing secret-like-material" not in stderr:
            raise AssertionError(stderr)
        jar = root / "local.bin"
        payload = b"rehearsal-fixture-not-a-production-jar"
        jar.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()
        if digest.startswith(ROLLBACK_SHA256_PREFIX):
            raise AssertionError("fixture collided with the rollback prefix")
        code, stdout, stderr = run_cli(["--verify-rollback-jar", str(jar)])
        if code != 0 or stdout.strip() != "rollback-jar-prefix-mismatch" or digest in stdout + stderr:
            raise AssertionError((code, stdout, stderr))
        matched = verify_rollback_jar(jar, prefix=digest[:8])
        if not matched.startswith("rollback-jar-prefix-match ") or digest in matched or digest[8:] in matched:
            raise AssertionError(matched)
        if ROLLBACK_COMMIT not in matched or BACKEND_REPO not in matched:
            raise AssertionError(matched)
        empty = root / "empty.bin"
        empty.write_bytes(b"")
        code, _stdout, stderr = run_cli(["--verify-rollback-jar", str(empty)])
        if code != 2 or "refusing rollback-jar-empty" not in stderr:
            raise AssertionError(stderr)
        jar_link = root / "jar-link"
        jar_link.symlink_to(jar)
        code, _stdout, stderr = run_cli(["--verify-rollback-jar", str(jar_link)])
        if code != 2 or "refusing refusing-symlink" not in stderr:
            raise AssertionError(stderr)


def main(argv: list[str] | None = None) -> int:
    try:
        return dispatch(sys.argv[1:] if argv is None else argv)
    except Refusal as exc:
        print(f"refusing {exc.code}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
