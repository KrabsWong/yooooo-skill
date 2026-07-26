from __future__ import annotations

import base64
import hashlib
import hmac
import importlib.util
import json
import os
import sys
import time
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).parents[1] / "scf" / "index.py"
SPEC = importlib.util.spec_from_file_location("notify_scf_server", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
server = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = server
SPEC.loader.exec_module(server)

TEST_KEY = "test-key-that-is-at-least-32-characters"
TEST_ENV = {
    "NOTIFY_HMAC_KEY": TEST_KEY,
    "TELEGRAM_BOT_TOKEN": "test-bot-token",
    "TELEGRAM_CHAT_ID": "@test_channel",
}


def response_body(response):
    return json.loads(response["body"])


def signed_event(payload, *, nonce="0123456789abcdef0123456789abcdef"):
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    timestamp = int(time.time())
    digest = hashlib.sha256(body).hexdigest()
    canonical = f"v1\ncodex\n{timestamp}\n{nonce}\n{digest}".encode("utf-8")
    signature = hmac.new(TEST_KEY.encode("utf-8"), canonical, hashlib.sha256).hexdigest()
    return {
        "httpMethod": "POST",
        "path": "/",
        "headers": {
            "X-Notify-Client": "codex",
            "X-Notify-Timestamp": str(timestamp),
            "X-Notify-Nonce": nonce,
            "X-Notify-Signature": f"v1={signature}",
        },
        "body": body.decode("utf-8"),
    }


class ScfRelayTests(unittest.TestCase):
    def setUp(self):
        server._SEEN_NONCES.clear()

    def test_health_reports_photo_capability(self):
        event = {"httpMethod": "GET", "path": "/health", "headers": {}, "body": ""}
        with mock.patch.dict(os.environ, TEST_ENV, clear=True):
            response = server.main_handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(
            response_body(response),
            {
                "ok": True,
                "service": "yooooo-notifier",
                "version": "2.0.1",
                "configured": True,
                "capabilities": ["text", "photo"],
            },
        )

    def test_delivers_signed_text_request(self):
        payload = {
            "version": 1,
            "request_id": "text-request",
            "target": "default",
            "title": "Title",
            "body": "Body",
        }
        event = signed_event(payload)
        with (
            mock.patch.dict(os.environ, TEST_ENV, clear=True),
            mock.patch.object(server, "_send_message", return_value=41) as send_message,
        ):
            response = server.main_handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(response_body(response)["status"], "delivered")
        send_message.assert_called_once()
        self.assertEqual(send_message.call_args.args[2], "Title\n\nBody")

    def test_delivers_signed_png_request(self):
        image = b"\x89PNG\r\n\x1a\npayload"
        payload = {
            "version": 2,
            "request_id": "photo-request",
            "target": "default",
            "title": "Photo",
            "body": "Caption",
            "media": {
                "kind": "photo",
                "filename": "../result.png",
                "content_type": "image/png",
                "data_base64": base64.b64encode(image).decode("ascii"),
            },
        }
        event = signed_event(payload)
        with (
            mock.patch.dict(os.environ, TEST_ENV, clear=True),
            mock.patch.object(server, "_send_photo", return_value=42) as send_photo,
        ):
            response = server.main_handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(response_body(response)["message_ids"], [42])
        self.assertEqual(send_photo.call_args.args[2], image)
        self.assertEqual(send_photo.call_args.args[4], "result.png")
        self.assertEqual(send_photo.call_args.args[5], "Photo\n\nCaption")

    def test_send_photo_builds_multipart_upload(self):
        config = server.ServerConfig(
            hmac_key=TEST_KEY,
            bot_token="test-bot-token",
            chat_id="@test_channel",
        )
        captured = {}

        def telegram_result(_config, method, data, content_type):
            captured.update(method=method, data=data, content_type=content_type)
            return {"message_id": 44}

        with mock.patch.object(server, "_telegram_result", side_effect=telegram_result):
            message_id = server._send_photo(
                config,
                "@test_channel",
                b"\x89PNG\r\n\x1a\npayload",
                "image/png",
                "result.png",
                "Caption",
            )

        self.assertEqual(message_id, 44)
        self.assertEqual(captured["method"], "sendPhoto")
        self.assertTrue(captured["content_type"].startswith("multipart/form-data; boundary="))
        self.assertIn(b'name="chat_id"', captured["data"])
        self.assertIn(b"@test_channel", captured["data"])
        self.assertIn(b'name="photo"; filename="result.png"', captured["data"])
        self.assertIn(b"Content-Type: image/png", captured["data"])
        self.assertIn(b"\x89PNG\r\n\x1a\npayload", captured["data"])

    def test_rejects_invalid_signature_before_delivery(self):
        payload = {
            "version": 1,
            "request_id": "bad-signature",
            "target": "default",
            "title": "Title",
            "body": "Body",
        }
        event = signed_event(payload)
        event["headers"]["X-Notify-Signature"] = "v1=invalid"
        with (
            mock.patch.dict(os.environ, TEST_ENV, clear=True),
            mock.patch.object(server, "_send_message") as send_message,
        ):
            response = server.main_handler(event, None)

        self.assertEqual(response["statusCode"], 401)
        self.assertEqual(response_body(response)["error"], "invalid_signature")
        send_message.assert_not_called()

    def test_rejects_replayed_nonce(self):
        payload = {
            "version": 1,
            "request_id": "replay",
            "target": "default",
            "title": "Title",
            "body": "Body",
        }
        event = signed_event(payload)
        with (
            mock.patch.dict(os.environ, TEST_ENV, clear=True),
            mock.patch.object(server, "_send_message", return_value=43),
        ):
            first = server.main_handler(event, None)
            second = server.main_handler(event, None)

        self.assertEqual(first["statusCode"], 200)
        self.assertEqual(second["statusCode"], 409)
        self.assertEqual(response_body(second)["error"], "replayed_nonce")


if __name__ == "__main__":
    unittest.main()
