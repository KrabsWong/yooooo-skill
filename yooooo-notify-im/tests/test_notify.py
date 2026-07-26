from __future__ import annotations

import base64
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "notify.py"
SPEC = importlib.util.spec_from_file_location("notify_im_client", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
notify = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = notify
SPEC.loader.exec_module(notify)


class EncodePhotoTests(unittest.TestCase):
    def test_encodes_png_from_file_contents(self) -> None:
        data = b"\x89PNG\r\n\x1a\npayload"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.bin"
            path.write_bytes(data)

            result = notify.encode_photo(path)

        self.assertEqual(result["kind"], "photo")
        self.assertEqual(result["filename"], "test.bin")
        self.assertEqual(result["content_type"], "image/png")
        self.assertEqual(base64.b64decode(result["data_base64"]), data)

    def test_rejects_unknown_file_contents(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "not-an-image.png"
            path.write_text("not an image", encoding="utf-8")

            with self.assertRaisesRegex(notify.ClientError, "unsupported image type"):
                notify.encode_photo(path)


class MainPayloadTests(unittest.TestCase):
    def test_image_uses_protocol_v2_and_allows_empty_caption(self) -> None:
        data = b"\x89PNG\r\n\x1a\npayload"
        with tempfile.TemporaryDirectory() as directory:
            image_path = Path(directory) / "test.png"
            image_path.write_bytes(data)
            sent_payloads: list[dict[str, object]] = []

            def capture_send(config, payload, *, timeout):
                sent_payloads.append(payload)
                return {"ok": True, "status": "delivered", "request_id": payload["request_id"]}

            argv = ["notify.py", "--image", str(image_path), "--title", "Photo test"]
            with (
                mock.patch.object(notify, "load_config", return_value=mock.Mock(default_target="default")),
                mock.patch.object(notify, "send_notification", side_effect=capture_send),
                mock.patch("sys.argv", argv),
                mock.patch("sys.stdin", io.StringIO("")),
                mock.patch("sys.stdout", new_callable=io.StringIO) as stdout,
            ):
                exit_code = notify.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(len(sent_payloads), 1)
        self.assertEqual(sent_payloads[0]["version"], 2)
        self.assertEqual(sent_payloads[0]["body"], "")
        self.assertEqual(sent_payloads[0]["media"]["content_type"], "image/png")
        self.assertEqual(json.loads(stdout.getvalue())["status"], "delivered")


if __name__ == "__main__":
    unittest.main()
