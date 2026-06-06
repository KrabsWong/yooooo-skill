---
name: yooooo-telegram-message-channel
description: "Send text reports, alerts, and automation outputs to a Telegram channel or chat through the Telegram Bot API. Use when the user asks to push, post, publish, notify, or deliver generated content to Telegram, especially from recurring tasks, monitors, market reports, status reports, or other agent workflows. Includes a Node.js helper script that reads bot credentials from namespaced environment variables and sends MarkdownV2, HTML, or plain text messages without hardcoded secrets."
---

# Yooooo Telegram Message Channel

## Overview

Use this skill as a reusable Telegram delivery channel for generated reports, alerts, and automation outputs.

The bundled Node.js script sends one message to a Telegram chat/channel using the Bot API. Keep credentials outside prompts and source files.

## Required Setup

- Create a Telegram bot with BotFather.
- Add the bot to the target channel or group.
- For channels, make the bot an administrator with permission to post messages.
- Configure credentials through environment variables or a caller-provided env file:
  - `YOOOOO_TELEGRAM_BOT_TOKEN`: bot token from BotFather.
  - `YOOOOO_TELEGRAM_CHAT_ID`: target chat id, channel id, or public channel username such as `@my_channel`.
  - `YOOOOO_TELEGRAM_PARSE_MODE`: optional parse mode, usually `HTML`, `MarkdownV2`, `Markdown`, or `none`.
  - `YOOOOO_TELEGRAM_API_BASE`: optional Bot API base URL when `https://api.telegram.org` is not reachable from the runtime.
  - `YOOOOO_TELEGRAM_TIMEOUT_MS`: optional request timeout in milliseconds.

Never ask the user to paste bot tokens into public output. Prefer environment variables, an agent-specific secret store, or a local env file outside committed files. Do not assume a Codex-specific, Claude-specific, or OpenCode-specific config directory.

Recommended portable secret locations:

- User-managed secret file: `~/.config/agent-secrets/telegram.env`
- Project-local ignored file: `.agent-secrets/telegram.env`
- CI or automation secret store exposed as environment variables
- Agent-specific secret store when the user explicitly chooses one

## Standard Workflow

1. Generate the report or alert content first.
2. Choose a parse mode:
   - `HTML` is the safest default for structured reports.
   - `MarkdownV2` is useful only when content is already escaped or simple.
   - `none` sends plain text.
3. Send with `scripts/send-telegram-message.mjs`.
4. If sending fails, report the Telegram API error and do not retry indefinitely.

## Script Usage

Send text from stdin:

```bash
YOOOOO_TELEGRAM_BOT_TOKEN="..." YOOOOO_TELEGRAM_CHAT_ID="@channel" \
node /path/to/yooooo-telegram-message-channel/scripts/send-telegram-message.mjs \
  --parse-mode HTML < report.html
```

Send from a file:

```bash
node /path/to/yooooo-telegram-message-channel/scripts/send-telegram-message.mjs \
  --chat-id "@channel" \
  --parse-mode none \
  --file report.txt
```

Send using a caller-provided env file:

```bash
node /path/to/yooooo-telegram-message-channel/scripts/send-telegram-message.mjs \
  --env-file ~/.config/agent-secrets/telegram.env \
  --parse-mode HTML \
  --file report.html
```

When Telegram is not directly reachable from the runtime, use a trusted Bot API gateway or reverse proxy:

```bash
node /path/to/yooooo-telegram-message-channel/scripts/send-telegram-message.mjs \
  --env-file ~/.config/agent-secrets/telegram.env \
  --api-base https://your-telegram-api-gateway.example.com \
  --text "Telegram channel test"
```

Validate configuration without sending:

```bash
node /path/to/yooooo-telegram-message-channel/scripts/send-telegram-message.mjs \
  --dry-run \
  --text "Telegram channel test"
```

## Options

- `--bot-token <token>`: override `YOOOOO_TELEGRAM_BOT_TOKEN`.
- `--chat-id <id>`: override `YOOOOO_TELEGRAM_CHAT_ID`.
- `--api-base <url>`: override `YOOOOO_TELEGRAM_API_BASE`. Default: `https://api.telegram.org`.
- `--env-file <path>`: load `KEY=VALUE` pairs before validation. CLI flags still take precedence.
- `--text <message>`: message text.
- `--file <path>`: read message text from a file.
- `--parse-mode <HTML|MarkdownV2|Markdown|none>`: parse mode. Default: `HTML`.
- `--timeout-ms <ms>`: override `YOOOOO_TELEGRAM_TIMEOUT_MS`. Default: `30000`.
- `--disable-web-page-preview`: suppress link previews.
- `--disable-notification`: send silently.
- `--dry-run`: validate inputs and print a redacted summary without calling Telegram.

If neither `--text` nor `--file` is passed, the script reads stdin.

## Formatting Guidance

- Telegram messages have a 4096 character limit. The script splits longer text into chunks.
- For generated reports, prefer concise summaries and tables converted to readable text.
- For HTML mode, use only Telegram-supported tags: `b`, `strong`, `i`, `em`, `u`, `s`, `code`, `pre`, `a`, `blockquote`.
- If using MarkdownV2, escape Telegram MarkdownV2 special characters before sending.

## Reporting

After sending, report the destination chat id in redacted form, parse mode, number of message chunks, and whether Telegram returned success. Do not print the full bot token.

## Network Troubleshooting

- `fetch failed` usually means the runtime cannot reach Telegram Bot API, not that the token or chat id is invalid.
- If Telegram is blocked or requires a proxy in the current network, configure `YOOOOO_TELEGRAM_API_BASE` to a trusted Bot API gateway/reverse proxy, or run the agent/automation in a network that can reach `https://api.telegram.org`.
- Invalid token, missing bot permissions, or wrong chat id usually return a Telegram API error such as `401`, `403`, or `400`, not a raw network `fetch failed`.
