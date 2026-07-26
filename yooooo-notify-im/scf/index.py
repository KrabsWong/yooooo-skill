"""Tencent SCF event-function relay for signed Telegram notifications."""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import json
import os
import re
import threading
import time
import uuid
from dataclasses import dataclass
from typing import Any
from urllib import error, request


SERVICE_VERSION = "2.0.1"
MAX_EVENT_BODY_BYTES = 5_900_000
MAX_PHOTO_BYTES = 4_000_000
MAX_ENCODED_PHOTO_CHARS = 5_400_000
MAX_MESSAGE_CHARS = 4096
MAX_CAPTION_CHARS = 1024
SUPPORTED_PHOTO_TYPES = {"image/jpeg", "image/png", "image/webp"}
TELEGRAM_API_BASE = "https://api.telegram.org"
TELEGRAM_TIMEOUT_SECONDS = 20
MAX_CLOCK_SKEW_SECONDS = 300

_SEEN_NONCES: dict[str, float] = {}
_NONCE_LOCK = threading.Lock()


class RequestError(Exception):
    def __init__(self, status: int, code: str, **details: Any) -> None:
        super().__init__(code)
        self.status = status
        self.code = code
        self.details = details


class TelegramError(Exception):
    def __init__(self, code: str, *, retryable: bool, description: str = "") -> None:
        super().__init__(code)
        self.code = code
        self.retryable = retryable
        self.description = description[:500]


@dataclass(frozen=True)
class ServerConfig:
    hmac_key: str
    bot_token: str
    chat_id: str

    @property
    def configured(self) -> bool:
        return bool(len(self.hmac_key) >= 32 and self.bot_token and self.chat_id)


def load_config() -> ServerConfig:
    return ServerConfig(
        hmac_key=os.environ.get("NOTIFY_HMAC_KEY", ""),
        bot_token=os.environ.get("TELEGRAM_BOT_TOKEN", "").strip(),
        chat_id=os.environ.get("TELEGRAM_CHAT_ID", "").strip(),
    )


def _response(status: int, payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "isBase64Encoded": False,
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
    }


def _headers(event: dict[str, Any]) -> dict[str, str]:
    raw = event.get("headers")
    if not isinstance(raw, dict):
        return {}
    return {str(key).lower(): str(value) for key, value in raw.items()}


def _request_body(event: dict[str, Any]) -> bytes:
    body = event.get("body", "")
    if isinstance(body, bytes):
        raw = body
    elif isinstance(body, str):
        if event.get("isBase64Encoded"):
            try:
                raw = base64.b64decode(body, validate=True)
            except (binascii.Error, ValueError) as exc:
                raise RequestError(400, "invalid_request_encoding") from exc
        else:
            raw = body.encode("utf-8")
    else:
        raise RequestError(400, "invalid_request_body")
    if len(raw) > MAX_EVENT_BODY_BYTES:
        raise RequestError(413, "request_too_large")
    return raw


def _signature(key: str, client: str, timestamp: int, nonce: str, body: bytes) -> str:
    body_digest = hashlib.sha256(body).hexdigest()
    canonical = f"v1\n{client}\n{timestamp}\n{nonce}\n{body_digest}".encode("utf-8")
    return hmac.new(key.encode("utf-8"), canonical, hashlib.sha256).hexdigest()


def _consume_nonce(nonce: str, timestamp: int) -> None:
    expires_at = timestamp + MAX_CLOCK_SKEW_SECONDS
    now = time.time()
    with _NONCE_LOCK:
        expired = [item for item, expiry in _SEEN_NONCES.items() if expiry < now]
        for item in expired:
            del _SEEN_NONCES[item]
        if nonce in _SEEN_NONCES:
            raise RequestError(409, "replayed_nonce")
        _SEEN_NONCES[nonce] = expires_at


def _authenticate(
    headers: dict[str, str],
    body: bytes,
    config: ServerConfig,
) -> str:
    client = headers.get("x-notify-client", "").strip()
    timestamp_text = headers.get("x-notify-timestamp", "").strip()
    nonce = headers.get("x-notify-nonce", "").strip()
    supplied = headers.get("x-notify-signature", "").strip()
    if not client or not timestamp_text or not nonce or not supplied.startswith("v1="):
        raise RequestError(401, "missing_authentication")
    if not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", nonce):
        raise RequestError(401, "invalid_nonce")
    try:
        timestamp = int(timestamp_text)
    except ValueError as exc:
        raise RequestError(401, "invalid_timestamp") from exc
    if abs(int(time.time()) - timestamp) > MAX_CLOCK_SKEW_SECONDS:
        raise RequestError(401, "expired_request")

    expected = _signature(config.hmac_key, client, timestamp, nonce, body)
    if not hmac.compare_digest(supplied[3:], expected):
        raise RequestError(401, "invalid_signature")
    _consume_nonce(nonce, timestamp)
    return client


def _required_text(payload: dict[str, Any], name: str, *, allow_empty: bool = False) -> str:
    value = payload.get(name)
    if not isinstance(value, str):
        raise RequestError(400, f"invalid_{name}")
    if not allow_empty and not value.strip():
        raise RequestError(400, f"invalid_{name}")
    return value


def _detect_photo_type(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def _safe_filename(value: Any, content_type: str) -> str:
    extensions = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
    raw = value if isinstance(value, str) else "photo"
    raw = raw.replace("\\", "/").rsplit("/", 1)[-1]
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", raw).strip("._")[:100] or "photo"
    if "." not in safe:
        safe += extensions[content_type]
    return safe


def _decode_photo(media: Any) -> tuple[bytes, str, str]:
    if not isinstance(media, dict) or media.get("kind") != "photo":
        raise RequestError(400, "invalid_media")
    content_type = media.get("content_type")
    encoded = media.get("data_base64")
    if content_type not in SUPPORTED_PHOTO_TYPES or not isinstance(encoded, str):
        raise RequestError(400, "invalid_media")
    if len(encoded) > MAX_ENCODED_PHOTO_CHARS:
        raise RequestError(413, "photo_too_large")
    try:
        data = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise RequestError(400, "invalid_photo_encoding") from exc
    if not data or len(data) > MAX_PHOTO_BYTES:
        raise RequestError(413, "photo_too_large")
    detected = _detect_photo_type(data)
    if detected != content_type:
        raise RequestError(400, "photo_type_mismatch")
    return data, content_type, _safe_filename(media.get("filename"), content_type)


def _message_text(title: str, body: str) -> str:
    parts = [part.strip() for part in (title, body) if part.strip()]
    return "\n\n".join(parts)


def _split_text(text: str, limit: int) -> list[str]:
    normalized = text.replace("\r\n", "\n").strip()
    if not normalized:
        return []
    chunks: list[str] = []
    remaining = normalized
    while len(remaining) > limit:
        split_at = remaining.rfind("\n", 0, limit + 1)
        if split_at < limit // 2:
            split_at = remaining.rfind(" ", 0, limit + 1)
        if split_at < limit // 2:
            split_at = limit
        chunks.append(remaining[:split_at].strip())
        remaining = remaining[split_at:].strip()
    if remaining:
        chunks.append(remaining)
    return chunks


def _telegram_result(
    config: ServerConfig,
    method: str,
    data: bytes,
    content_type: str,
) -> dict[str, Any]:
    telegram_request = request.Request(
        f"{TELEGRAM_API_BASE}/bot{config.bot_token}/{method}",
        data=data,
        headers={"Content-Type": content_type, "User-Agent": "yooooo-notifier/2.0.1"},
        method="POST",
    )
    try:
        with request.urlopen(telegram_request, timeout=TELEGRAM_TIMEOUT_SECONDS) as response:
            raw = response.read()
            status = response.status
    except error.HTTPError as exc:
        raw = exc.read()
        status = exc.code
    except (error.URLError, TimeoutError) as exc:
        raise TelegramError("telegram_unavailable", retryable=True) from exc

    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TelegramError(
            "invalid_telegram_response", retryable=status >= 500
        ) from exc
    if not isinstance(payload, dict) or not payload.get("ok"):
        description = payload.get("description", "") if isinstance(payload, dict) else ""
        raise TelegramError(
            "telegram_rejected",
            retryable=status == 429 or status >= 500,
            description=str(description),
        )
    result = payload.get("result")
    if not isinstance(result, dict):
        raise TelegramError("invalid_telegram_response", retryable=False)
    return result


def _send_message(config: ServerConfig, chat_id: str, text: str) -> int:
    data = json.dumps(
        {
            "chat_id": chat_id,
            "text": text,
            "link_preview_options": {"is_disabled": True},
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    result = _telegram_result(config, "sendMessage", data, "application/json; charset=utf-8")
    message_id = result.get("message_id")
    if not isinstance(message_id, int):
        raise TelegramError("invalid_telegram_response", retryable=False)
    return message_id


def _multipart(
    fields: dict[str, str],
    *,
    filename: str,
    content_type: str,
    content: bytes,
) -> tuple[bytes, str]:
    boundary = f"----yooooo-{uuid.uuid4().hex}"
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode("ascii"),
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("ascii"),
                value.encode("utf-8"),
                b"\r\n",
            ]
        )
    chunks.extend(
        [
            f"--{boundary}\r\n".encode("ascii"),
            (
                f'Content-Disposition: form-data; name="photo"; filename="{filename}"\r\n'
            ).encode("ascii"),
            f"Content-Type: {content_type}\r\n\r\n".encode("ascii"),
            content,
            b"\r\n",
            f"--{boundary}--\r\n".encode("ascii"),
        ]
    )
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"


def _send_photo(
    config: ServerConfig,
    chat_id: str,
    photo: bytes,
    content_type: str,
    filename: str,
    caption: str,
) -> int:
    fields = {"chat_id": chat_id}
    if caption:
        fields["caption"] = caption
    data, multipart_type = _multipart(
        fields,
        filename=filename,
        content_type=content_type,
        content=photo,
    )
    result = _telegram_result(config, "sendPhoto", data, multipart_type)
    message_id = result.get("message_id")
    if not isinstance(message_id, int):
        raise TelegramError("invalid_telegram_response", retryable=False)
    return message_id


def _deliver(payload: dict[str, Any], config: ServerConfig) -> dict[str, Any]:
    version = payload.get("version")
    if version not in (1, 2):
        raise RequestError(400, "unsupported_version")
    request_id = _required_text(payload, "request_id")
    if len(request_id) > 128:
        raise RequestError(400, "invalid_request_id")
    target = _required_text(payload, "target")
    if target != "default":
        raise RequestError(400, "unknown_target")
    chat_id = config.chat_id
    title = _required_text(payload, "title", allow_empty=True)
    body = _required_text(payload, "body", allow_empty=True)
    text = _message_text(title, body)

    message_ids: list[int] = []
    try:
        if version == 1:
            if "media" in payload or not text:
                raise RequestError(400, "invalid_payload")
            for chunk in _split_text(text, MAX_MESSAGE_CHARS):
                message_ids.append(_send_message(config, chat_id, chunk))
        else:
            photo, content_type, filename = _decode_photo(payload.get("media"))
            caption_chunks = _split_text(text, MAX_CAPTION_CHARS)
            caption = caption_chunks[0] if caption_chunks else ""
            message_ids.append(
                _send_photo(config, chat_id, photo, content_type, filename, caption)
            )
            overflow = "\n".join(caption_chunks[1:])
            for chunk in _split_text(overflow, MAX_MESSAGE_CHARS):
                message_ids.append(_send_message(config, chat_id, chunk))
    except TelegramError as exc:
        status = 503 if exc.retryable else 502
        raise RequestError(
            status,
            exc.code,
            description=exc.description,
            sent_chunks=len(message_ids),
        ) from exc

    return {
        "ok": True,
        "status": "delivered",
        "request_id": request_id,
        "sent_chunks": len(message_ids),
        "message_ids": message_ids,
    }


def _handle(event: dict[str, Any]) -> dict[str, Any]:
    config = load_config()
    method = str(event.get("httpMethod", "")).upper()
    path = str(event.get("path", "/")).rstrip("/") or "/"

    if method == "GET" and path == "/health":
        return _response(
            200,
            {
                "ok": True,
                "service": "yooooo-notifier",
                "version": SERVICE_VERSION,
                "configured": config.configured,
                "capabilities": ["text", "photo"],
            },
        )
    if path != "/":
        raise RequestError(404, "not_found")
    if method != "POST":
        raise RequestError(405, "method_not_allowed")
    if not config.configured:
        raise RequestError(503, "service_not_configured")

    body = _request_body(event)
    headers = _headers(event)
    _authenticate(headers, body, config)
    try:
        payload = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RequestError(400, "invalid_json") from exc
    if not isinstance(payload, dict):
        raise RequestError(400, "invalid_payload")
    return _response(200, _deliver(payload, config))


def main_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    try:
        return _handle(event)
    except RequestError as exc:
        return _response(exc.status, {"ok": False, "error": exc.code, **exc.details})
    except Exception as exc:  # Keep unexpected errors and secrets out of the HTTP response.
        request_id = getattr(context, "request_id", "unknown")
        print(f"unhandled notifier error request_id={request_id} type={type(exc).__name__}")
        return _response(500, {"ok": False, "error": "internal_error"})
