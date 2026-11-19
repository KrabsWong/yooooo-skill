"""Private renderer used by export_codex_sessions.py."""

import datetime as dt
import hashlib
import html
import json
import re
from pathlib import Path
from typing import Any


def text_from(content: Any) -> str:
    if not isinstance(content, list):
        return ""
    parts = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if str(item.get("type", "")).lower() in ("input_text", "output_text", "text", "summary_text") and isinstance(item.get("text"), str):
            parts.append(item["text"])
        elif item.get("type") in ("input_image", "image", "input_file", "file") and item.get("file_id"):
            parts.append("[附件保留在原始会话记录中]")
    return "\n\n".join(parts).strip()


def attached_images(content: Any, by_hash: dict[str, str]) -> list[str]:
    result = []
    if not isinstance(content, list):
        return result
    for item in content:
        if not isinstance(item, dict) or item.get("type") not in ("input_image", "image"):
            continue
        value = item.get("image_url")
        if not isinstance(value, str) or not value.startswith("data:image/") or "," not in value:
            continue
        import base64
        try:
            digest = hashlib.sha256(base64.b64decode(value.split(",", 1)[1])).hexdigest()
        except (ValueError, base64.binascii.Error):
            continue
        if digest in by_hash:
            result.append(by_hash[digest])
    return list(dict.fromkeys(result))


def markdown_inline(value: str) -> str:
    value = html.escape(value, quote=False)
    value = re.sub(r"`([^`]+)`", r"<code>\1</code>", value)
    value = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", value)
    value = re.sub(r"\[([^\]]+)\]\((https?://[^ )]+)\)", r'<a href="\2" target="_blank" rel="noopener noreferrer">\1</a>', value)
    value = re.sub(r"(?<![\"=])\b(https?://[^\s<]+)", r'<a href="\1" target="_blank" rel="noopener noreferrer">\1</a>', value)
    return value


def markdown(value: str) -> str:
    lines = value.replace("\r\n", "\n").split("\n")
    output, i = [], 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith("```"):
            lang, code = line[3:].strip(), []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code.append(lines[i]); i += 1
            i += i < len(lines)
            attr = f' data-language="{html.escape(lang, quote=True)}"' if lang else ""
            output.append(f"<pre{attr}><code>{html.escape(chr(10).join(code))}</code></pre>")
            continue
        heading = re.match(r"^(#{1,4})\s+(.*)", line)
        if heading:
            tag = len(heading.group(1)) + 1
            output.append(f"<h{tag}>{markdown_inline(heading.group(2))}</h{tag}>")
            i += 1
            continue
        if line.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].startswith(">"):
                quote.append(lines[i][1:].lstrip()); i += 1
            output.append("<blockquote>" + "".join(f"<p>{markdown_inline(x)}</p>" for x in quote) + "</blockquote>")
            continue
        if re.match(r"^\s*[-*+]\s+", line):
            items = []
            while i < len(lines) and re.match(r"^\s*[-*+]\s+", lines[i]):
                items.append(re.sub(r"^\s*[-*+]\s+", "", lines[i])); i += 1
            output.append("<ul>" + "".join(f"<li>{markdown_inline(x)}</li>" for x in items) + "</ul>")
            continue
        if re.match(r"^\s*\d+[.)]\s+", line):
            items = []
            while i < len(lines) and re.match(r"^\s*\d+[.)]\s+", lines[i]):
                items.append(re.sub(r"^\s*\d+[.)]\s+", "", lines[i])); i += 1
            output.append("<ol>" + "".join(f"<li>{markdown_inline(x)}</li>" for x in items) + "</ol>")
            continue
        paragraph = [line.strip()]; i += 1
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#{1,4})\s|^```|^>|^\s*[-*+]\s+|^\s*\d+[.)]\s+", lines[i]):
            paragraph.append(lines[i].strip()); i += 1
        output.append("<p>" + "<br>".join(markdown_inline(x) for x in paragraph) + "</p>")
    return "".join(output)


def session_messages(folder: Path, metadata: dict[str, Any]) -> list[dict[str, Any]]:
    images = metadata.get("extracted_inline_images", [])
    by_hash = {item["sha256"]: item["file"] for item in images if item.get("sha256") and item.get("file")}
    raw_users = []
    messages = []
    for line in (folder / "raw" / "rollout.jsonl").open(encoding="utf-8", errors="replace"):
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        payload = record.get("payload", {})
        if record.get("type") == "response_item" and payload.get("type") == "message":
            role, content = payload.get("role"), payload.get("content", [])
            text, pics = text_from(content), attached_images(content, by_hash)
            if role == "user" and (text or pics):
                raw_users.append({"text": text, "images": pics})
            elif role == "assistant" and (text or pics):
                messages.append({"role": "assistant", "text": text, "images": pics, "phase": payload.get("phase", "")})
        elif record.get("type") == "event_msg":
            item = payload.get("item", {})
            if not isinstance(item, dict) or item.get("type") != "UserMessage":
                continue
            content = item.get("content", [])
            text, pics = text_from(content), attached_images(content, by_hash)
            normalized = re.sub(r"\s+", " ", text).strip()
            match = next((candidate for candidate in raw_users if normalized and (normalized in re.sub(r"\s+", " ", candidate["text"]).strip() or re.sub(r"\s+", " ", candidate["text"]).strip() in normalized)), None)
            if match is None and raw_users:
                match = raw_users[-1]
            if match:
                raw_users.remove(match)
                pics = list(dict.fromkeys(match["images"] + pics))
            if text or pics:
                messages.append({"role": "user", "text": text, "images": pics, "phase": "user"})
    if not any(x["role"] == "user" for x in messages):
        for item in raw_users:
            if re.search(r"<environment_context>|<INSTRUCTIONS>|# AGENTS\.md instructions", item["text"]):
                continue
            messages.insert(0, {"role": "user", **item, "phase": "user"})
    return messages


def render(export_dir: Path, project_name: str, sessions: list[dict[str, Any]]) -> Path:
    export_dir = Path(export_dir)
    html_dir = export_dir / "html"
    html_dir.mkdir(parents=True, exist_ok=True)
    articles, used = [], set()
    for index, item in enumerate(sessions):
        folder = export_dir / item["folder"]
        metadata = json.loads((folder / "metadata.json").read_text(encoding="utf-8"))
        messages = session_messages(folder, metadata)
        try:
            date = dt.datetime.fromisoformat(item["created_at_utc"].replace("Z", "+00:00")).astimezone().strftime("%Y.%m.%d")
        except (ValueError, TypeError):
            date = ""
        first_user = next((x["text"] for x in messages if x["role"] == "user" and x["text"]), "")
        preview = re.sub(r"\s+", " ", first_user).strip()
        if len(preview) > 118:
            preview = preview[:116] + "…"
        turns, progress, user_index = [], [], 0

        def body_for(message: dict[str, Any]) -> str:
            body = markdown(message["text"]) if message["text"] else '<p class="attachment-only">此消息包含附件，请查看下方图片。</p>'
            for name in message["images"]:
                used.add((item["folder"], name))
                url = "../" + html.escape(item["folder"], quote=True) + "/assets/" + html.escape(name, quote=True)
                body += f'<figure class="message-image"><a href="{url}" target="_blank"><img loading="lazy" src="{url}" alt="对话附件"></a></figure>'
            return body

        def flush_progress() -> None:
            if progress:
                entries = "".join(f'<div class="progress-item"><span>·</span><div class="message-body">{x}</div></div>' for x in progress)
                turns.append(f'<details class="progress-bundle"><summary>查看 {len(progress)} 条过程更新</summary><div class="progress-content">{entries}</div></details>')
                progress.clear()

        for message in messages:
            body = body_for(message)
            if message["role"] == "user":
                flush_progress(); user_index += 1
                turns.append(f'<section class="user-message"><div class="message-label">你 <span>{user_index}</span></div><div class="message-body">{body}</div></section>')
            elif message["phase"] == "final_answer":
                flush_progress()
                turns.append(f'<section class="assistant-message"><div class="assistant-label">Codex</div><div class="message-body">{body}</div></section>')
            elif body:
                progress.append(body)
        flush_progress()
        unused = [x["file"] for x in metadata.get("extracted_inline_images", []) if (item["folder"], x["file"]) not in used]
        if unused:
            figs = "".join(f'<figure class="message-image"><img loading="lazy" src="../{html.escape(item["folder"], quote=True)}/assets/{html.escape(name, quote=True)}" alt="对话附件"></figure>' for name in unused)
            turns.append(f'<details class="asset-gallery"><summary>查看 {len(unused)} 张其他图片附件</summary>{figs}</details>')
        articles.append({"number": index, "title": item["title"], "date": date, "month": date[:7], "preview": preview, "user_count": user_index, "turns": "".join(turns)})

    sections, views = [], []
    months = sorted({x["month"] for x in articles})
    for month in months:
        month_items = [x for x in articles if x["month"] == month]
        links = []
        for article in month_items:
            number = f"{article['number']:02d}"
            search = html.escape((article["title"] + " " + article["preview"]).lower(), quote=True)
            links.append(f'<button class="thread-link" data-thread="{number}" data-search="{search}" aria-current="false"><span class="thread-index">{number}</span><span><strong>{html.escape(article["title"])}</strong><small>{html.escape(article["preview"])}</small></span></button>')
            views.append(f'<article class="thread-view" id="thread-{number}" data-thread-view="{number}" hidden><header class="thread-heading"><div class="heading-top"><button class="back-button" data-back type="button">‹ 目录</button><span>项目对话 · {number} / {len(articles)-1:02d}</span><time>{article["date"]}</time></div><h1>{html.escape(article["title"])}</h1><div class="thread-summary">{article["user_count"]} 条用户消息 · 完整答复外显，过程更新收起</div><div class="thread-tools"><button data-expand>展开过程更新</button><span>│</span><button data-collapse>收起过程更新</button></div></header><div class="dialogue">{article["turns"]}</div></article>')
        sections.append(f'<section class="month-group"><h2>{month}<small>{len(month_items)} 段对话</small></h2>{"".join(links)}</section>')

    template = r'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><meta name="description" content="__PROJECT__ 项目的离线对话记录"><title>__PROJECT__ | 项目对话</title>
<style>
:root{color-scheme:light;--ink:#171717;--muted:#686868;--line:#dedede;--paper:#fff;--soft:#f0f0f0;--sans:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}*{box-sizing:border-box}html,body{height:100%;margin:0}body{color:var(--ink);background:#fff;font:14px/1.65 var(--sans);-webkit-font-smoothing:antialiased}button,input{font:inherit}.app{height:100dvh;display:flex;flex-direction:column}.topbar{height:58px;flex:none;display:flex;align-items:center;gap:14px;padding:0 24px;border-bottom:1px solid var(--line)}.brand-name{font-weight:700}.top-separator{height:20px;border-left:1px solid var(--line)}.top-context,.top-meta{color:var(--muted)}.top-meta{margin-left:auto;font-size:12px}.workspace{min-height:0;flex:1;display:grid;grid-template-columns:310px minmax(0,1fr)}.rail{overflow:auto;border-right:1px solid var(--line);padding:22px 16px}.rail-heading{padding:0 4px 18px}.rail-heading h2{font-size:22px;margin:0 0 4px}.rail-heading p{margin:0;color:var(--muted);font-size:12px}.search{width:100%;margin:0 0 20px;padding:11px 13px;border:1px solid var(--line);border-radius:12px;background:#fff;color:var(--ink)}.month-group{margin:18px 0}.month-group h2{display:flex;justify-content:space-between;color:#555;font:600 11px var(--mono);margin:0 4px 8px}.month-group h2 small{font:11px var(--sans);color:#888}.thread-link{width:100%;display:grid;grid-template-columns:34px minmax(0,1fr);gap:10px;align-items:start;text-align:left;padding:10px 8px;border:0;border-radius:12px;background:transparent;cursor:pointer}.thread-link:hover{background:#f5f5f5}.thread-link[aria-current="true"]{background:#e9e9e9}.thread-index{width:28px;height:28px;display:grid;place-items:center;border-radius:9px;background:#e7e7e7;color:#444;font:11px var(--mono)}.thread-link strong,.thread-link small{display:block;overflow:hidden;text-overflow:ellipsis}.thread-link strong{font-size:13px;font-weight:650;white-space:nowrap}.thread-link small{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;margin-top:3px;color:#777;font-size:11px;line-height:1.45}.reader{min-width:0;overflow:auto}.thread-view{max-width:980px;margin:auto;padding:0 46px 32px}.thread-view[hidden]{display:none}.thread-heading{position:sticky;top:0;z-index:2;padding:22px 0 16px;background:rgba(255,255,255,.97);border-bottom:1px solid var(--line)}.heading-top{display:flex;justify-content:space-between;color:#222;font:11px var(--mono)}.heading-top time{color:#666}.back-button{display:none;border:0;background:transparent;color:#333;font:11px var(--sans);cursor:pointer}.thread-heading h1{margin:13px 0 7px;font-size:28px;line-height:1.3;letter-spacing:-.02em}.thread-summary{color:var(--muted);font-size:12px}.thread-tools{display:flex;gap:10px;align-items:center;margin-top:11px}.thread-tools button{border:0;background:transparent;padding:2px 0;color:#222;font-size:11px;cursor:pointer}.thread-tools span{color:#ccc}.dialogue{padding:22px 0}.user-message{max-width:88%;margin:0 0 18px auto;padding:14px 18px;border-radius:18px;background:#f0f0f0}.message-label,.assistant-label{font-size:11px;font-weight:650;color:#666}.message-label{display:flex;justify-content:space-between}.message-label span{font:10px var(--mono);color:#777}.message-body{padding-top:7px;overflow-wrap:anywhere;color:#171717;font-size:15px;line-height:1.7}.message-body p{margin:0 0 10px}.message-body h2,.message-body h3,.message-body h4{margin:17px 0 7px;font-size:16px;line-height:1.4}.message-body ul,.message-body ol{padding-left:22px;margin:7px 0 11px}.message-body li{margin:3px 0}.message-body blockquote{margin:10px 0;padding-left:12px;border-left:2px solid #ccc;color:#555}.message-body code{padding:1px 4px;border-radius:4px;background:#e6e6e6;font:.9em var(--mono)}.message-body pre{overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;margin:11px 0;padding:13px 14px;border:1px solid #e2e2e2;border-radius:12px;background:#f1f1f1;font:12px/1.65 var(--mono)}.message-body pre code{padding:0;background:transparent}.message-body pre[data-language]::before{content:attr(data-language);display:block;margin-bottom:6px;color:#666;font:10px var(--mono);text-transform:uppercase}.message-body a{color:#222;text-decoration:underline;text-underline-offset:2px}.assistant-message{margin:0 0 14px;padding:4px 0 18px}.assistant-label{margin-bottom:2px}.progress-bundle{margin:8px 0 14px}.progress-bundle summary,.asset-gallery summary{cursor:pointer;color:#777;font-size:12px;list-style:none}.progress-bundle summary::-webkit-details-marker,.asset-gallery summary::-webkit-details-marker{display:none}.progress-content{margin:5px 0 0 3px;padding:5px 0 0 12px;border-left:1px solid #d6d6d6}.progress-item{display:grid;grid-template-columns:10px minmax(0,1fr);gap:5px;padding:4px 0;color:#888}.progress-item .message-body{padding:0;color:#707070;font-size:12px}.asset-gallery{margin:12px 0}.message-image{margin:10px 0 0}.message-image img{display:block;max-width:min(100%,680px);max-height:560px;object-fit:contain;border:1px solid #ddd;border-radius:10px}.privacy-note{flex:none;padding:9px 18px;color:#777;text-align:center;font-size:10px;border-top:1px solid #eee}.empty-search{padding:15px;color:#777}.hidden{display:none!important}@media(max-width:760px){.topbar{height:52px;padding:0 14px}.top-context{display:none}.top-meta{font-size:10px}.workspace{display:block}.rail,.reader{height:100%}.rail{display:none}.reader{display:block}.is-mobile-list .rail{display:block}.is-mobile-list .reader{display:none}.rail{padding:16px 12px}.thread-view{padding:0 17px 24px}.thread-heading{padding:14px 0}.back-button{display:inline-block}.thread-heading h1{font-size:22px}.user-message{max-width:100%;padding:11px 13px}.message-body{font-size:14px}.privacy-note{display:none}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}
</style></head><body><div class="app" id="app"><header class="topbar"><span class="brand-name">__PROJECT__</span><span class="top-separator"></span><span class="top-context">项目对话档案</span><span class="top-meta">__RANGE__　·　__COUNT__ 段对话</span></header><div class="workspace"><aside class="rail"><div class="rail-heading"><h2>对话记录</h2><p>__COUNT__ 段，按时间排列<br>__RANGE__</p></div><input id="search" class="search" type="search" placeholder="搜索对话或需求"><nav id="thread-list">__SIDEBAR__<div id="empty" class="empty-search hidden">没有找到匹配的对话。</div></nav></aside><main class="reader" id="reader">__VIEWS__</main></div><footer class="privacy-note">原始 JSONL、图片和会话元数据保存在导出目录。对外分享前请检查个人信息、本机路径和附件内容。</footer></div>
<script>
const app=document.querySelector('#app'),links=[...document.querySelectorAll('.thread-link')],views=[...document.querySelectorAll('.thread-view')],search=document.querySelector('#search'),empty=document.querySelector('#empty');let active='';function show(id){if(!document.querySelector(`[data-thread-view="${id}"]`))return;active=id;for(const v of views)v.hidden=v.dataset.threadView!==id;for(const a of links){const on=a.dataset.thread===id;a.setAttribute('aria-current',on?'true':'false');if(on)a.scrollIntoView({block:'nearest'})}app.classList.remove('is-mobile-list');document.querySelector('#reader').scrollTop=0;if(location.hash!=='#'+id)location.hash=id}links.forEach(a=>a.addEventListener('click',()=>show(a.dataset.thread)));document.querySelectorAll('[data-back]').forEach(b=>b.addEventListener('click',()=>app.classList.add('is-mobile-list')));search.addEventListener('input',()=>{const q=search.value.trim().toLocaleLowerCase();let n=0;for(const a of links){const on=!q||(a.dataset.search+' '+a.innerText).toLocaleLowerCase().includes(q);a.classList.toggle('hidden',!on);if(on)n++}empty.classList.toggle('hidden',n>0)});document.querySelectorAll('[data-expand]').forEach(b=>b.addEventListener('click',()=>document.querySelectorAll(`#thread-${active} details.progress-bundle`).forEach(x=>x.open=true)));document.querySelectorAll('[data-collapse]').forEach(b=>b.addEventListener('click',()=>document.querySelectorAll(`#thread-${active} details.progress-bundle`).forEach(x=>x.open=false)));window.addEventListener('hashchange',()=>show(location.hash.slice(1)));show(location.hash.slice(1)||links[0]?.dataset.thread);
</script></body></html>'''
    start = min((a["date"] for a in articles if a["date"]), default="")[:7]
    end = max((a["date"] for a in articles if a["date"]), default="")[:7]
    date_range = start if start == end else f"{start} 至 {end}"
    page = (template.replace("__PROJECT__", html.escape(project_name))
            .replace("__RANGE__", html.escape(date_range))
            .replace("__COUNT__", str(len(articles)))
            .replace("__SIDEBAR__", "".join(sections))
            .replace("__VIEWS__", "".join(views)))
    output = html_dir / "index.html"
    output.write_text(page, encoding="utf-8")
    return output
