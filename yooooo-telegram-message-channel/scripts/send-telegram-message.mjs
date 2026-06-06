#!/usr/bin/env node

import fs from "node:fs/promises";
import process from "node:process";

const DEFAULT_TELEGRAM_API_BASE = "https://api.telegram.org";
const MAX_MESSAGE_LENGTH = 4096;
const DEFAULT_TIMEOUT_MS = 30000;

function usage() {
  return `Usage: send-telegram-message.mjs [options]

Send a text message to a Telegram chat or channel using the Telegram Bot API.

Options:
  --bot-token <token>             Bot token. Defaults to YOOOOO_TELEGRAM_BOT_TOKEN
  --chat-id <id>                  Chat/channel id. Defaults to YOOOOO_TELEGRAM_CHAT_ID
  --api-base <url>                Telegram Bot API base URL. Defaults to YOOOOO_TELEGRAM_API_BASE or https://api.telegram.org
  --env-file <path>               Load KEY=VALUE secrets from an env file
  --text <message>                Message text
  --file <path>                   Read message text from file
  --parse-mode <mode>             HTML, MarkdownV2, Markdown, or none. Default: HTML
  --timeout-ms <ms>               Request timeout. Defaults to YOOOOO_TELEGRAM_TIMEOUT_MS or 30000
  --disable-web-page-preview      Disable URL previews
  --disable-notification          Send silently
  --dry-run                       Validate and print redacted summary without sending
  -h, --help                      Show help

If --text and --file are omitted, message text is read from stdin.`;
}

function parseArgs(argv) {
  const options = {
    botToken: process.env.YOOOOO_TELEGRAM_BOT_TOKEN || "",
    chatId: process.env.YOOOOO_TELEGRAM_CHAT_ID || "",
    apiBase: process.env.YOOOOO_TELEGRAM_API_BASE || DEFAULT_TELEGRAM_API_BASE,
    envFile: null,
    botTokenFromCli: false,
    chatIdFromCli: false,
    apiBaseFromCli: false,
    text: null,
    file: null,
    parseMode: process.env.YOOOOO_TELEGRAM_PARSE_MODE || "HTML",
    timeoutMs: Number(process.env.YOOOOO_TELEGRAM_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    disableWebPagePreview: false,
    disableNotification: false,
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case "--bot-token":
        options.botToken = requireValue(argv, i, arg);
        options.botTokenFromCli = true;
        i += 1;
        break;
      case "--chat-id":
        options.chatId = requireValue(argv, i, arg);
        options.chatIdFromCli = true;
        i += 1;
        break;
      case "--api-base":
        options.apiBase = requireValue(argv, i, arg);
        options.apiBaseFromCli = true;
        i += 1;
        break;
      case "--env-file":
        options.envFile = requireValue(argv, i, arg);
        i += 1;
        break;
      case "--text":
        options.text = requireValue(argv, i, arg);
        i += 1;
        break;
      case "--file":
        options.file = requireValue(argv, i, arg);
        i += 1;
        break;
      case "--parse-mode":
        options.parseMode = requireValue(argv, i, arg);
        i += 1;
        break;
      case "--timeout-ms":
        options.timeoutMs = Number(requireValue(argv, i, arg));
        i += 1;
        break;
      case "--disable-web-page-preview":
        options.disableWebPagePreview = true;
        break;
      case "--disable-notification":
        options.disableNotification = true;
        break;
      case "--dry-run":
        options.dryRun = true;
        break;
      case "-h":
      case "--help":
        console.log(usage());
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

function requireValue(argv, index, optionName) {
  const value = argv[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${optionName}`);
  }
  return value;
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function readMessage(options) {
  if (options.text !== null && options.file !== null) {
    throw new Error("Pass only one of --text or --file.");
  }
  if (options.text !== null) {
    return options.text;
  }
  if (options.file !== null) {
    return fs.readFile(options.file, "utf8");
  }
  return readStdin();
}

async function loadEnvFile(path) {
  const content = await fs.readFile(path, "utf8");
  const env = {};

  for (const [index, rawLine] of content.split(/\r?\n/).entries()) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const equalsIndex = line.indexOf("=");
    if (equalsIndex <= 0) {
      throw new Error(`Invalid env file line ${index + 1}: expected KEY=VALUE.`);
    }

    const key = line.slice(0, equalsIndex).trim();
    let value = line.slice(equalsIndex + 1).trim();
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) {
      throw new Error(`Invalid env file key on line ${index + 1}: ${key}`);
    }
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }

  return env;
}

function normalizeParseMode(mode) {
  const value = String(mode || "none").trim();
  if (/^none$/i.test(value)) {
    return null;
  }
  const allowed = new Set(["HTML", "MarkdownV2", "Markdown"]);
  if (!allowed.has(value)) {
    throw new Error("--parse-mode must be HTML, MarkdownV2, Markdown, or none.");
  }
  return value;
}

function normalizeApiBase(apiBase) {
  const value = String(apiBase || DEFAULT_TELEGRAM_API_BASE).trim().replace(/\/+$/, "");
  const parsed = new URL(value);
  if (!["http:", "https:"].includes(parsed.protocol)) {
    throw new Error("--api-base must start with http:// or https://.");
  }
  return value;
}

function normalizeTimeoutMs(timeoutMs) {
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new Error("--timeout-ms must be a positive number.");
  }
  return Math.trunc(timeoutMs);
}

function splitMessage(text) {
  const normalized = String(text).replace(/\r\n/g, "\n").trim();
  if (!normalized) {
    throw new Error("Message text is empty.");
  }

  const chunks = [];
  let remaining = normalized;
  while (remaining.length > MAX_MESSAGE_LENGTH) {
    let splitAt = remaining.lastIndexOf("\n", MAX_MESSAGE_LENGTH);
    if (splitAt < MAX_MESSAGE_LENGTH * 0.5) {
      splitAt = remaining.lastIndexOf(" ", MAX_MESSAGE_LENGTH);
    }
    if (splitAt < MAX_MESSAGE_LENGTH * 0.5) {
      splitAt = MAX_MESSAGE_LENGTH;
    }
    chunks.push(remaining.slice(0, splitAt).trim());
    remaining = remaining.slice(splitAt).trim();
  }
  if (remaining) {
    chunks.push(remaining);
  }
  return chunks;
}

function redactToken(token) {
  if (!token) {
    return "(missing)";
  }
  if (token.length <= 10) {
    return "***";
  }
  return `${token.slice(0, 5)}...${token.slice(-4)}`;
}

function redactChatId(chatId) {
  const value = String(chatId || "");
  if (value.startsWith("@")) {
    return value;
  }
  if (value.length <= 6) {
    return "***";
  }
  return `${value.slice(0, 3)}...${value.slice(-3)}`;
}

function describeFetchError(error, apiBase) {
  const cause = error?.cause;
  const parts = [
    `Network request to Telegram Bot API failed: ${error.message}`,
    `apiBase=${apiBase}`,
  ];
  if (cause?.code) {
    parts.push(`cause=${cause.code}`);
  }
  if (cause?.message) {
    parts.push(`detail=${cause.message}`);
  }
  parts.push(
    "Check whether this runtime can reach Telegram, whether a proxy/VPN is required, or set YOOOOO_TELEGRAM_API_BASE/--api-base to a reachable Bot API gateway."
  );
  return parts.join(" ");
}

async function sendChunk({ botToken, chatId, parseMode, chunk, options }) {
  const body = {
    chat_id: chatId,
    text: chunk,
    disable_web_page_preview: options.disableWebPagePreview,
    disable_notification: options.disableNotification,
  };
  if (parseMode) {
    body.parse_mode = parseMode;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeoutMs);
  let response;
  try {
    response = await fetch(`${options.apiBase}/bot${botToken}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (error) {
    throw new Error(describeFetchError(error, options.apiBase));
  } finally {
    clearTimeout(timeout);
  }

  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.ok) {
    const description = payload?.description || response.statusText || "Unknown Telegram API error";
    throw new Error(`Telegram sendMessage failed (${response.status}): ${description}`);
  }
  return payload.result?.message_id;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.envFile) {
    const env = await loadEnvFile(options.envFile);
    if (!options.botTokenFromCli && env.YOOOOO_TELEGRAM_BOT_TOKEN) {
      options.botToken = env.YOOOOO_TELEGRAM_BOT_TOKEN;
    }
    if (!options.chatIdFromCli && env.YOOOOO_TELEGRAM_CHAT_ID) {
      options.chatId = env.YOOOOO_TELEGRAM_CHAT_ID;
    }
    if (options.parseMode === "HTML" && env.YOOOOO_TELEGRAM_PARSE_MODE) {
      options.parseMode = env.YOOOOO_TELEGRAM_PARSE_MODE;
    }
    if (!options.apiBaseFromCli && env.YOOOOO_TELEGRAM_API_BASE) {
      options.apiBase = env.YOOOOO_TELEGRAM_API_BASE;
    }
    if (env.YOOOOO_TELEGRAM_TIMEOUT_MS) {
      options.timeoutMs = Number(env.YOOOOO_TELEGRAM_TIMEOUT_MS);
    }
  }
  const parseMode = normalizeParseMode(options.parseMode);
  options.apiBase = normalizeApiBase(options.apiBase);
  options.timeoutMs = normalizeTimeoutMs(options.timeoutMs);
  const message = await readMessage(options);
  const chunks = splitMessage(message);

  if (!options.botToken) {
    throw new Error("Missing bot token. Set YOOOOO_TELEGRAM_BOT_TOKEN or pass --bot-token.");
  }
  if (!options.chatId) {
    throw new Error("Missing chat id. Set YOOOOO_TELEGRAM_CHAT_ID or pass --chat-id.");
  }

  const summary = {
    chatId: redactChatId(options.chatId),
    botToken: redactToken(options.botToken),
    apiBase: options.apiBase,
    parseMode: parseMode || "none",
    chunks: chunks.length,
    characters: message.length,
    timeoutMs: options.timeoutMs,
    disableWebPagePreview: options.disableWebPagePreview,
    disableNotification: options.disableNotification,
  };

  if (options.dryRun) {
    console.log(JSON.stringify({ ok: true, dryRun: true, ...summary }, null, 2));
    return;
  }

  const messageIds = [];
  for (const chunk of chunks) {
    const messageId = await sendChunk({
      botToken: options.botToken,
      chatId: options.chatId,
      parseMode,
      chunk,
      options,
    });
    messageIds.push(messageId);
  }

  console.log(JSON.stringify({ ok: true, ...summary, messageIds }, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
