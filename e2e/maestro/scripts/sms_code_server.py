#!/usr/bin/env python3
"""Local HTTP bridge exposing TEST Redis SMS OTP codes to Maestro `runScript`.

Started and torn down by `e2e/maestro/run_all.sh`. Listens only on 127.0.0.1.
Endpoints:
  GET /health
  GET /sms-code?phone=13900000004
  GET /clear-limit?phone=13900000004
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
READ_SCRIPT = SCRIPT_DIR / "read_test_sms_code.sh"
HOST = "127.0.0.1"
PORT = int(os.environ.get("E2E_SMS_BRIDGE_PORT", "18120"))


def _is_valid_phone(phone: str) -> bool:
    return phone.isdigit() and 6 <= len(phone) <= 20


class SmsBridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        sys.stderr.write("[sms-bridge] " + (format % args) + "\n")

    def _send_json(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/health":
            self._send_json(200, {"ok": True})
            return

        phone = params.get("phone", ["13900000004"])[0]
        if not _is_valid_phone(phone):
            self._send_json(400, {"error": "invalid phone"})
            return

        if parsed.path == "/clear-limit":
            proc = subprocess.run(
                [str(READ_SCRIPT), "--clear-limit", phone],
                capture_output=True,
                text=True,
                check=False,
            )
            if proc.returncode != 0:
                self._send_json(502, {"error": proc.stderr.strip() or "clear-limit failed"})
                return
            self._send_json(200, {"cleared": True, "phone": phone})
            return

        if parsed.path == "/sms-code":
            timeout_s = float(params.get("timeout", ["15"])[0])
            deadline = time.monotonic() + min(max(timeout_s, 1.0), 30.0)
            last_err = "not found"
            while time.monotonic() < deadline:
                proc = subprocess.run(
                    [str(READ_SCRIPT), phone],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                code = proc.stdout.strip()
                if proc.returncode == 0 and code:
                    self._send_json(200, {"phone": phone, "code": code})
                    return
                last_err = proc.stderr.strip() or "empty"
                time.sleep(1.0)
            self._send_json(404, {"error": last_err, "phone": phone})
            return

        self._send_json(404, {"error": "unknown endpoint"})


def main() -> int:
    server = ThreadingHTTPServer((HOST, PORT), SmsBridgeHandler)
    sys.stderr.write(f"[sms-bridge] Listening on http://{HOST}:{PORT}\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
