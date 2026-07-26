# Client protocol

The client reads `~/.config/yooooo-notifier/client.json` by default:

```json
{
  "endpoint": "https://example.ap-hongkong.tencentscf.com",
  "client_id": "codex",
  "hmac_key": "at-least-32-characters-and-identical-to-scf",
  "default_target": "default"
}
```

Environment variables override the endpoint and credentials:

- `YOOOOO_NOTIFY_URL`
- `YOOOOO_NOTIFY_CLIENT_ID`
- `YOOOOO_NOTIFY_HMAC_KEY`
- `YOOOOO_NOTIFY_CONFIG`

`notify.py` signs the exact UTF-8 JSON request body with HMAC-SHA256. Text requests use protocol version 1. Photo requests use version 2 and add:

```json
{
  "media": {
    "kind": "photo",
    "filename": "result.png",
    "content_type": "image/png",
    "data_base64": "<base64 data>"
  }
}
```

The client accepts JPEG, PNG, and WebP photos up to 4,000,000 bytes. This conservative limit leaves room for Base64 and JSON overhead under SCF's 6 MB synchronous request-event limit. The relay must reject unsupported protocol versions instead of ignoring `media`, and must decode the content only after request authentication and size validation. It sends the first 1024 characters of `title` plus `body` as the Telegram photo caption and sends any remainder as ordinary text chunks.

The canonical signature value is:

```text
v1
<client_id>
<unix_timestamp>
<nonce>
<sha256_of_body>
```

The service returns `status=delivered` only after Telegram returns message IDs for every text chunk or the photo. A non-zero client exit code means delivery was not confirmed. If an error contains `sent_chunks` greater than zero, treat it as partial delivery and do not automatically resend the whole notification.

The public `GET /health` endpoint checks that required SCF environment variables exist. It does not contact Telegram. Version 2 relays should include `capabilities: ["text", "photo"]` in the health response. Use a real signed notification to verify the bot token, channel permissions, and Telegram network connectivity.

Read [scf-deployment.md](scf-deployment.md) when building, deploying, or replacing the Tencent SCF relay.
