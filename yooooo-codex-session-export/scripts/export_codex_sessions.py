#!/usr/bin/env python3
"""Export Codex sessions for one project as raw, readable, and offline HTML."""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, BinaryIO, Iterator


def codex_home() -> Path:
    configured = os.environ.get("CODEX_HOME")
    return Path(configured).expanduser() if configured else Path.home() / ".codex"


def open_session(path: Path) -> tuple[BinaryIO, Any | None]:
    """Return a binary JSONL stream and an optional owner to close afterwards."""
    if path.suffix != ".zst":
        stream = path.open("rb")
        return stream, stream
    zstd = shutil.which("zstd")
    if zstd:
        process = subprocess.Popen([zstd, "-dc", str(path)], stdout=subprocess.PIPE)
        assert process.stdout is not None
        return process.stdout, process
    try:
        import zstandard  # type: ignore[import-not-found]
    except ImportError as exc:
        raise RuntimeError(
            "Cannot read .jsonl.zst logs: install zstd or Python package zstandard."
        ) from exc
    source = path.open("rb")
    stream = zstandard.ZstdDecompressor().stream_reader(source)
    return stream, (stream, source)


def close_session(owner: Any | None) -> None:
    if owner is None:
        return
    if isinstance(owner, subprocess.Popen):
        if owner.stdout:
            owner.stdout.close()
        owner.terminate()
        owner.wait()
    elif isinstance(owner, tuple):
        for item in owner:
            item.close()
    else:
        owner.close()


def records(path: Path, raw_output: Path | None = None) -> Iterator[dict[str, Any]]:
    stream, owner = open_session(path)
    try:
        if raw_output:
            raw_output.parent.mkdir(parents=True, exist_ok=True)
            with raw_output.open("wb") as target:
                for line in stream:
                    target.write(line)
                    try:
                        value = json.loads(line)
                    except (UnicodeDecodeError, json.JSONDecodeError):
                        continue
                    if isinstance(value, dict):
                        yield value
        else:
            for line in stream:
                try:
                    value = json.loads(line)
                except (UnicodeDecodeError, json.JSONDecodeError):
                    continue
                if isinstance(value, dict):
                    yield value
        if isinstance(owner, subprocess.Popen) and owner.wait() != 0:
            raise RuntimeError(f"zstd failed while reading {path}")
    finally:
        close_session(owner)


def session_header(path: Path) -> dict[str, Any] | None:
    stream, owner = open_session(path)
    try:
        for _ in range(30):
            line = stream.readline()
            if not line:
                break
            try:
                row = json.loads(line)
            except (UnicodeDecodeError, json.JSONDecodeError):
                continue
            if row.get("type") == "session_meta":
                payload = row.get("payload", {})
                if isinstance(payload, dict):
                    return payload
    finally:
        close_session(owner)
    return None


def normalized_path(path: str | Path) -> str:
    return os.path.normcase(os.path.realpath(os.path.expanduser(str(path))))


def discover_sessions(folder: Path, project: Path) -> list[tuple[Path, dict[str, Any]]]:
    if not folder.is_dir():
        raise RuntimeError(f"Codex session folder not found: {folder}")
    by_id: dict[str, tuple[Path, dict[str, Any]]] = {}
    for path in list(folder.rglob("*.jsonl")) + list(folder.rglob("*.jsonl.zst")):
        try:
            header = session_header(path)
        except (OSError, RuntimeError) as exc:
            print(f"Skipping unreadable session {path}: {exc}", file=sys.stderr)
            continue
        if not header or not header.get("session_id"):
            continue
        if not header.get("cwd") or normalized_path(header["cwd"]) != normalized_path(project):
            continue
        session_id = str(header["session_id"])
        current = by_id.get(session_id)
        if current is None or path.stat().st_mtime > current[0].stat().st_mtime:
            by_id[session_id] = (path, header)
    return sorted(by_id.values(), key=lambda item: (str(item[1].get("timestamp", "")), item[1]["session_id"]))


def content_text(content: Any) -> str:
    if not isinstance(content, list):
        return ""
    parts = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if str(item.get("type", "")).lower() in ("input_text", "output_text", "text", "summary_text"):
            text = item.get("text")
            if isinstance(text, str):
                parts.append(text)
        elif item.get("type") in ("input_image", "image", "input_file", "file") and item.get("file_id"):
            parts.append("[附件保留在原始会话记录中]")
    return "\n\n".join(parts).strip()


def image_data(content: Any) -> Iterator[tuple[str, bytes]]:
    if not isinstance(content, list):
        return
    for item in content:
        if not isinstance(item, dict) or item.get("type") not in ("input_image", "image"):
            continue
        url = item.get("image_url")
        if not isinstance(url, str) or not url.startswith("data:image/") or "," not in url:
            continue
        mime = url[5:].split(";", 1)[0]
        try:
            yield mime, base64.b64decode(url.split(",", 1)[1])
        except (ValueError, base64.binascii.Error):
            continue


def slug(value: str) -> str:
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]+', "-", value)
    value = re.sub(r"\s+", "-", value).strip(" .-_")
    return (value or "conversation")[:56]


def local_date(timestamp: str) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    return parsed.astimezone()


def choose_title(session_id: str, user_messages: list[dict[str, Any]], title_map: dict[str, str]) -> str:
    if title_map.get(session_id):
        return title_map[session_id].strip()
    for message in user_messages:
        text = message.get("text", "")
        for line in text.splitlines():
            line = line.strip(" #\t")
            if line and not line.startswith(("<environment_context>", "<INSTRUCTIONS>", "# AGENTS.md")):
                return line[:52].rstrip(" ,;，；。.") + ("…" if len(line) > 52 else "")
    return "Codex 对话"


def extract_session(path: Path, header: dict[str, Any], output: Path, title: str, number: int) -> dict[str, Any]:
    session_id = str(header["session_id"])
    created_at = str(header.get("timestamp") or dt.datetime.fromtimestamp(path.stat().st_mtime).astimezone().isoformat())
    created = local_date(created_at)
    folder_name = f"{number:02d}_{created:%Y-%m-%d}_{slug(title)}"
    folder = output / folder_name
    raw_dir, assets_dir = folder / "raw", folder / "assets"
    raw_dir.mkdir(parents=True)
    assets_dir.mkdir()
    if path.suffix == ".zst":
        shutil.copy2(path, raw_dir / path.name)
        raw_path = raw_dir / "rollout.jsonl"
    else:
        raw_path = raw_dir / "rollout.jsonl"
    messages: list[dict[str, Any]] = []
    pending_users: list[dict[str, Any]] = []
    image_index: dict[str, str] = {}
    image_meta: list[dict[str, Any]] = []
    record_count = 0
    last_timestamp = created_at

    def save_images(content: Any, record: dict[str, Any]) -> list[str]:
        filenames = []
        for mime, data in image_data(content):
            digest = hashlib.sha256(data).hexdigest()
            if digest not in image_index:
                ext = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif", "image/avif": "avif"}.get(mime, "bin")
                filename = f"{len(image_meta):03d}.{ext}"
                (assets_dir / filename).write_bytes(data)
                image_index[digest] = filename
                image_meta.append({"file": filename, "sha256": digest, "source_record": record.get("ordinal", record_count), "mime": mime})
            filenames.append(image_index[digest])
        return list(dict.fromkeys(filenames))

    for record in records(path, raw_path if path.suffix == ".zst" else None):
        record_count += 1
        last_timestamp = str(record.get("timestamp") or last_timestamp)
        kind, payload = record.get("type"), record.get("payload", {})
        if not isinstance(payload, dict):
            continue
        if kind == "response_item" and payload.get("type") == "message":
            role = payload.get("role")
            content = payload.get("content", [])
            text = content_text(content)
            images = save_images(content, record)
            if role == "user" and (text or images):
                pending_users.append({"text": text, "images": images, "record": record_count})
            elif role == "assistant" and (text or images):
                messages.append({"role": "assistant", "text": text, "images": images, "phase": payload.get("phase", "")})
        elif kind == "event_msg":
            item = payload.get("item", {})
            if not isinstance(item, dict) or item.get("type") != "UserMessage":
                continue
            content = item.get("content", [])
            text = content_text(content)
            images = save_images(content, record)
            normalized = re.sub(r"\s+", " ", text).strip()
            matched = None
            for candidate in pending_users:
                raw = re.sub(r"\s+", " ", candidate["text"]).strip()
                if normalized and (normalized in raw or raw in normalized):
                    matched = candidate
                    break
            if matched is None and pending_users:
                matched = pending_users[-1]
            if matched:
                pending_users.remove(matched)
                images = list(dict.fromkeys(matched["images"] + images))
            if text or images:
                messages.append({"role": "user", "text": text, "images": images, "phase": "user"})

    if not any(message["role"] == "user" for message in messages):
        for candidate in pending_users:
            if re.search(r"<environment_context>|<INSTRUCTIONS>|# AGENTS\.md instructions", candidate["text"]):
                continue
            messages.insert(0, {"role": "user", **candidate, "phase": "user"})

    # Attach unmatched input images to the nearest visible user message, while preserving them all.
    used = {name for message in messages for name in message["images"]}
    loose = [image["file"] for image in image_meta if image["file"] not in used]
    if loose and messages:
        messages[0]["images"] = list(dict.fromkeys(messages[0]["images"] + loose))

    transcript = [f"# {title}\n\n- Session ID: `{session_id}`\n- Created: {created_at}\n- Project: `{header.get('cwd', '')}`\n\n"]
    user_index = 0
    final_count = 0
    for message in messages:
        role = message["role"]
        if role == "user":
            user_index += 1
            transcript.append(f"## 用户（第 {user_index} 条）\n\n{message['text']}\n\n")
        elif message["phase"] == "final_answer" and message["text"]:
            final_count += 1
            transcript.append(f"## Codex\n\n{message['text']}\n\n")
        for filename in message["images"]:
            transcript.append(f"![对话附件](assets/{filename})\n\n")
    (folder / "transcript.md").write_text("".join(transcript), encoding="utf-8")
    compressed = path.suffix == ".zst"
    metadata = {
        "thread_id": session_id,
        "title": title,
        "created_at_utc": created_at,
        "updated_at_utc": last_timestamp,
        "archived": None,
        "originator": header.get("originator"),
        "cli_version": header.get("cli_version"),
        "model_provider": header.get("model_provider"),
        "thread_source": header.get("thread_source"),
        "source_rollout_path": str(path),
        "source_compressed": compressed,
        "record_count": record_count,
        "project_path": header.get("cwd"),
        "extracted_inline_images": image_meta,
        "user_message_count": user_index,
        "assistant_final_count": final_count,
    }
    (folder / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"thread_id": session_id, "title": title, "created_at_utc": created_at, "folder": folder_name, "record_count": record_count, "user_message_count": user_index, "assistant_final_count": final_count, "image_count": len(image_meta)}


def render_html(output: Path, project_name: str, sessions: list[dict[str, Any]]) -> Path:
    """Build an offline archive view from exported raw session records."""
    # Importing this renderer lazily keeps archive discovery useful even on minimal Python installs.
    from html_renderer import render
    return render(output, project_name, sessions)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, type=Path, help="Project directory recorded as the Codex session cwd")
    parser.add_argument("--output", type=Path, help="Export folder (default: ./exports/<project>-conversations-YYYY-MM-DD)")
    parser.add_argument("--codex-home", type=Path, help="Codex home directory (defaults to CODEX_HOME or ~/.codex)")
    parser.add_argument("--exclude-session-id", action="append", default=[], help="Session ID to omit; may be repeated")
    parser.add_argument("--titles-json", type=Path, help="Optional JSON object mapping session IDs to Codex titles")
    args = parser.parse_args()

    project = args.project.expanduser().resolve()
    if not project.is_dir():
        parser.error(f"project directory does not exist: {project}")
    home = (args.codex_home or codex_home()).expanduser().resolve()
    sessions_dir = home / "sessions"
    today = dt.datetime.now().astimezone().strftime("%Y-%m-%d")
    output = args.output.expanduser().resolve() if args.output else Path.cwd() / "exports" / f"{slug(project.name)}-conversations-{today}"
    if output.exists():
        parser.error(f"output already exists; choose another path to avoid overwriting: {output}")
    title_map: dict[str, str] = {}
    if args.titles_json:
        data = json.loads(args.titles_json.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or any(not isinstance(k, str) or not isinstance(v, str) for k, v in data.items()):
            parser.error("titles JSON must be an object mapping session IDs to title strings")
        title_map = data
    try:
        found = discover_sessions(sessions_dir, project)
    except RuntimeError as exc:
        parser.error(str(exc))
    excluded = set(args.exclude_session_id)
    found = [(path, header) for path, header in found if str(header["session_id"]) not in excluded]
    if not found:
        parser.error(f"no matching Codex sessions found for {project} under {sessions_dir}")

    output.mkdir(parents=True)
    exported: list[dict[str, Any]] = []
    for index, (path, header) in enumerate(found):
        session_id = str(header["session_id"])
        title = title_map.get(session_id, "").strip()
        if not title:
            # Read only the small visible user-event records to derive a useful fallback title.
            visible = []
            for row in records(path):
                item = row.get("payload", {}).get("item", {}) if row.get("type") == "event_msg" else {}
                if isinstance(item, dict) and item.get("type") == "UserMessage":
                    visible.append({"text": content_text(item.get("content", []))})
                    if len(visible) == 2:
                        break
            title = choose_title(session_id, visible, title_map)
        entry = extract_session(path, header, output, title, index)
        exported.append(entry)

    manifest = {"project_path": str(project), "project_name": project.name, "exported_at": dt.datetime.now().astimezone().isoformat(), "exported": exported}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total_images = sum(item["image_count"] for item in exported)
    readme = [
        f"# {project.name} Codex 会话档案", "", f"- 项目路径：`{project}`", f"- 导出时间：{manifest['exported_at']}",
        f"- 会话数：{len(exported)}（按创建时间从旧到新编号）", f"- 内嵌图片：{total_images} 张（每段会话内去重）",
        "- 每段会话含完整 JSONL、可读 Markdown、元数据；有压缩源记录时保留 `.jsonl.zst`。", "",
        "> 原始会话未脱敏。分享前请检查密钥、个人信息、本机路径和附件。", "", "## 会话列表", "",
    ]
    readme += [f"- {item['folder'][:2]} — {item['title']}（{item['user_message_count']} 条用户消息，{item['image_count']} 张图片）" for item in exported]
    (output / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")
    html_path = render_html(output, project.name, exported)
    print(json.dumps({"output": str(output), "html": str(html_path), "sessions": len(exported), "images": total_images}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
