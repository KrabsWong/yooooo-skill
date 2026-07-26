# Tencent SCF deployment

Deploy `scf/index.py` as a dependency-free Tencent SCF event function.

## Function settings

- Function type: Event function
- Runtime: Python 3.9 or newer
- Handler: `index.main_handler`
- Timeout: at least 60 seconds
- Memory: at least 128 MB
- Function URL: retain the existing public URL, or create a public function URL when deploying a new function

Upload the generated ZIP with `index.py` at its archive root. Do not select Web function; that mode requires a `scf_bootstrap` HTTP server.

## Required environment variables

Use the existing SCF environment variables without renaming or adding aliases:

```text
NOTIFY_HMAC_KEY=<same HMAC key as the local client config>
TELEGRAM_BOT_TOKEN=<Telegram bot token>
TELEGRAM_CHAT_ID=<channel id or @channel_username>
```

Keep the HMAC key and bot token in SCF environment variables. Never add them to the ZIP.
The relay reads only these three names. It does not read aliases, fallback variables, target maps, or multi-client configuration.

## Verification

After deployment, check:

```bash
python3 /absolute/path/to/yooooo-notify-im/scripts/notify.py --check
```

Expect `version` to be `2.0.1`, `configured` to be `true`, and `capabilities` to include `photo`. Then send a small image through the normal skill workflow.

SCF synchronous request events are limited to 6 MB. The client therefore rejects photos larger than 4,000,000 bytes before Base64 encoding.
