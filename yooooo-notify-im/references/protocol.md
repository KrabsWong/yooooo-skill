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

`notify.py` signs the exact UTF-8 JSON request body with HMAC-SHA256. The canonical value is:

```text
v1
<client_id>
<unix_timestamp>
<nonce>
<sha256_of_body>
```

The service returns `status=delivered` only after Telegram returns message IDs for every chunk. A non-zero client exit code means delivery was not confirmed. If an error contains `sent_chunks` greater than zero, treat it as partial delivery and do not automatically resend the whole notification.

The public `GET /health` endpoint checks that required SCF environment variables exist. It does not contact Telegram. Use a real signed notification to verify the bot token, channel permissions, and Telegram network connectivity.
