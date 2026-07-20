---
name: yooooo-notify-im
description: Send user-requested conclusions, summaries, task results, completion alerts, or conversation excerpts to a configured IM destination through yoooo-notifier. Use only when the user explicitly asks Codex to notify, push, send, forward, or alert them through Telegram or another configured IM channel, including requests to notify them after work completes.
---

# Notify IM

Send notifications through the bundled deterministic client. Never call Telegram directly or request the Telegram bot token.

## Workflow

1. Complete the requested work before sending a completion notification.
2. Identify the exact content the user requested. Default to a concise conclusion and actionable next steps; do not send the full conversation unless explicitly requested.
3. Remove passwords, API tokens, cookies, private keys, authentication headers, and unrelated personal data. Ask before sending if redaction would materially change the requested content.
4. Use the configured `default` target unless the user names another server-configured target. Do not accept or invent arbitrary chat IDs.
5. Resolve `scripts/notify.py` relative to this skill directory and pass the message on standard input. Use an absolute script path when invoking it.
6. Report success only when the client returns JSON with `"status":"delivered"`. Include the returned `request_id` in the result. If the client fails, report the failure without claiming delivery.

Use this invocation shape:

```bash
python3 /absolute/path/to/yooooo-notify-im/scripts/notify.py --title "<short title>" <<'NOTIFY_EOF'
<message body>
NOTIFY_EOF
```

Use `python3 /absolute/path/to/yooooo-notify-im/scripts/notify.py --check` when diagnosing configuration or endpoint reachability. Read [references/protocol.md](references/protocol.md) only when configuration, response handling, or protocol details are needed.

## Safety

- Send only after an explicit user request. Do not infer consent from a request to summarize or analyze.
- Do not include tool logs, hidden reasoning, workspace secrets, or credentials.
- Do not silently retry a partial multi-message delivery. The client stops when the server reports that one or more chunks were already sent.
- Do not modify the local client configuration unless the user asks for setup help.
