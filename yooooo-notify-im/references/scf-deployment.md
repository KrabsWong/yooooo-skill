# Tencent SCF deployment

Production uses two functions:

- `yooooo-message-hub`: receives timer tasks and local Skill requests.
- `yooooo-notifier`: owns channel adapters and performs final delivery.

Deploy both as dependency-free Python event functions.

## Function settings

- Function type: Event function
- Runtime: Python 3.9 or newer
- Handler: `index.main_handler`
- Timeout: at least 60 seconds
- Memory: at least 128 MB
- Function URL: retain the existing public URL, or create a public function URL when deploying a new function

Upload the generated ZIP with `index.py` at its archive root. Do not select Web function; that mode requires a `scf_bootstrap` HTTP server.

## Required environment variables

Hub environment:

```text
YOOOOO_HUB_TOKEN=<manual API bearer token>
YOOOOO_HUB_INGRESS_HMAC_KEY=<local Skill HMAC key>
YOOOOO_NOTIFY_URL=<notifier Function URL>
YOOOOO_NOTIFY_CLIENT_ID=message-hub
YOOOOO_NOTIFY_HMAC_KEY=<hub-to-notifier HMAC key>
```

Notifier environment:

```text
YOOOOO_NOTIFY_HMAC_KEY=<same key as hub YOOOOO_NOTIFY_HMAC_KEY>
YOOOOO_TELEGRAM_BOT_TOKEN=<Telegram bot token>
YOOOOO_DESTINATIONS_CONFIG=<fixed-field destination JSON>
YOOOOO_NOTIFY_ALLOWED_CLIENTS=message-hub
```

Each timer trigger stores one JSON task in its `Message` field. There is no shared
tasks array. Keep provider credentials and channel credentials in SCF environment
variables, not in trigger messages or the ZIP.

## Verification

After deployment, check:

```bash
python3 /absolute/path/to/yooooo-notify-im/scripts/notify.py --check
```

Expect the hub health response to list providers and the notifier health response to
list configured destinations. Then send a small image through the normal Skill
workflow.

SCF synchronous request events are limited to 6 MB. The client therefore rejects photos larger than 4,000,000 bytes before Base64 encoding.
