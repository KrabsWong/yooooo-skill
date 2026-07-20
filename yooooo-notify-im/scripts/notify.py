#!/usr/bin/env python3
"""Submit a signed notification request to yoooo-notifier."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import sys
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import error, request


DEFAULT_CONFIG_PATH = Path.home() / ".config" / "yooooo-notifier" / "client.json"


class ClientError(Exception):
    pass


@dataclass(frozen=True)
class ClientConfig:
    endpoint: str
    client_id: str
    hmac_key: str
    default_target: str = "default"


def load_config(path: Path) -> ClientConfig:
    file_values: dict[str, Any] = {}
    if path.exists():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ClientError(f"cannot read config: {path}") from exc
        if not isinstance(loaded, dict):
            raise ClientError(f"config must contain a JSON object: {path}")
        file_values = loaded

    endpoint = os.environ.get("YOOOOO_NOTIFY_URL") or file_values.get("endpoint")
    client_id = os.environ.get("YOOOOO_NOTIFY_CLIENT_ID") or file_values.get("client_id", "codex")
    hmac_key = os.environ.get("YOOOOO_NOTIFY_HMAC_KEY") or file_values.get("hmac_key")
    default_target = file_values.get("default_target", "default")

    if not isinstance(endpoint, str) or not endpoint.strip():
        raise ClientError("missing endpoint in config or YOOOOO_NOTIFY_URL")
    if not isinstance(client_id, str) or not client_id.strip():
        raise ClientError("missing client_id in config or YOOOOO_NOTIFY_CLIENT_ID")
    if not isinstance(hmac_key, str) or len(hmac_key) < 32:
        raise ClientError("hmac_key must contain at least 32 characters")
    if default_target != "default":
        raise ClientError("default_target must be 'default'")

    return ClientConfig(
        endpoint=endpoint.rstrip("/"),
        client_id=client_id.strip(),
        hmac_key=hmac_key,
        default_target=default_target,
    )


def signature(key: str, client: str, timestamp: int, nonce: str, body: bytes) -> str:
    body_digest = hashlib.sha256(body).hexdigest()
    canonical = f"v1\n{client}\n{timestamp}\n{nonce}\n{body_digest}".encode("utf-8")
    return hmac.new(key.encode("utf-8"), canonical, hashlib.sha256).hexdigest()


def check_health(config: ClientConfig, timeout: float) -> dict[str, Any]:
    health_request = request.Request(
        f"{config.endpoint}/health",
        headers={"User-Agent": "notify-im-client/1.0.0"},
        method="GET",
    )
    return _execute_json(health_request, timeout)


def send_notification(
    config: ClientConfig,
    payload: dict[str, Any],
    *,
    timeout: float,
    attempts: int = 3,
) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    last_error: ClientError | None = None

    for attempt in range(attempts):
        timestamp = int(time.time())
        nonce = uuid.uuid4().hex
        signed = signature(config.hmac_key, config.client_id, timestamp, nonce, body)
        notify_request = request.Request(
            config.endpoint,
            data=body,
            headers={
                "Content-Type": "application/json; charset=utf-8",
                "User-Agent": "notify-im-client/1.0.0",
                "X-Notify-Client": config.client_id,
                "X-Notify-Timestamp": str(timestamp),
                "X-Notify-Nonce": nonce,
                "X-Notify-Signature": f"v1={signed}",
            },
            method="POST",
        )
        try:
            return _execute_json(notify_request, timeout)
        except ServiceResponseError as exc:
            last_error = exc
            sent_chunks = exc.payload.get("sent_chunks")
            can_retry = exc.status == 503 and sent_chunks in (None, 0)
            if not can_retry or attempt == attempts - 1:
                raise
        except ClientError as exc:
            last_error = exc
            if attempt == attempts - 1:
                raise
        time.sleep(2**attempt)

    assert last_error is not None
    raise last_error


class ServiceResponseError(ClientError):
    def __init__(self, status: int, payload: dict[str, Any]) -> None:
        super().__init__(f"notification service returned HTTP {status}: {payload.get('error', 'unknown_error')}")
        self.status = status
        self.payload = payload


def _execute_json(http_request: request.Request, timeout: float) -> dict[str, Any]:
    try:
        with request.urlopen(http_request, timeout=timeout) as response:
            raw = response.read()
            status = response.status
    except error.HTTPError as exc:
        raw = exc.read()
        payload = _parse_response(raw)
        raise ServiceResponseError(exc.code, payload) from None
    except (error.URLError, TimeoutError) as exc:
        reason = getattr(exc, "reason", None)
        detail = type(reason).__name__ if reason is not None else type(exc).__name__
        raise ClientError(f"notification service is unavailable: {detail}") from None

    payload = _parse_response(raw)
    if status < 200 or status >= 300 or not payload.get("ok"):
        raise ServiceResponseError(status, payload)
    return payload


def _parse_response(raw: bytes) -> dict[str, Any]:
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ClientError("notification service returned invalid JSON") from exc
    if not isinstance(payload, dict):
        raise ClientError("notification service returned a non-object response")
    return payload


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send a signed notification to a configured IM channel")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(os.environ.get("YOOOOO_NOTIFY_CONFIG", DEFAULT_CONFIG_PATH)),
        help=f"client config path (default: {DEFAULT_CONFIG_PATH})",
    )
    parser.add_argument("--check", action="store_true", help="check endpoint and server configuration")
    parser.add_argument("--title", default="Codex 通知", help="notification title")
    parser.add_argument("--target", default=None, help="configured target alias")
    parser.add_argument("--source", default="codex", help="notification source label")
    parser.add_argument("--request-id", default=None, help="stable request id; defaults to a UUID")
    parser.add_argument("--timeout", type=float, default=50.0, help="HTTP timeout in seconds")
    return parser.parse_args()


def main() -> int:
    args = _arguments()
    try:
        config = load_config(args.config)
        if args.check:
            result = check_health(config, args.timeout)
        else:
            body = sys.stdin.read()
            if not body.strip():
                raise ClientError("notification body must be provided on stdin")
            payload = {
                "version": 1,
                "request_id": args.request_id or str(uuid.uuid4()),
                "target": args.target or config.default_target,
                "title": args.title,
                "body": body,
                "source": args.source,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
            result = send_notification(config, payload, timeout=args.timeout)
    except ClientError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
