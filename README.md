# yooooo-skills

Personal Agent Skills managed as independent, portable skill directories.

## Repository Layout

- `<namespace>-<skill-name>/` contains first-party skills maintained in this repository.
- `external/<source>/<repo>/` is reserved for third-party skill repositories added as Git submodules.
- Keep each skill self-contained. Do not mix files from different skills in one directory.

This repository uses `yooooo-` as the namespace prefix for first-party skills. The prefix makes locally installed personal skills easy to distinguish from bundled, team, or community skills.

First-party skills target the Agent Skills format: a directory containing `SKILL.md`, plus optional `scripts/`, `references/`, and `assets/` directories. Avoid agent-specific frontmatter or product-specific config inside skill directories unless a skill explicitly needs it.

## Skills

| Skill | Purpose | Path |
| --- | --- | --- |
| `yooooo-git-post-merge-cleanup` | Sync trunk after a merge and safely prune merged Git branches. | `yooooo-git-post-merge-cleanup` |
| `yooooo-telegram-message-channel` | Send reports, alerts, and automation outputs to Telegram channels or chats. | `yooooo-telegram-message-channel` |

## Install

Keep this repository as the source of truth and symlink skill directories into each agent's global skill location.

Common global locations:

| Agent | Global skill directory |
| --- | --- |
| Agent-compatible shared path | `~/.agents/skills` |
| Claude Code | `~/.claude/skills` |
| OpenCode | `~/.config/opencode/skills` |
| Pi | `~/.pi/agent/skills` |
| Codex | `${CODEX_HOME:-$HOME/.codex}/skills` |

Install one skill with a symlink:

```bash
target="$HOME/.agents/skills"
mkdir -p "$target"
ln -sfn "$PWD/yooooo-git-post-merge-cleanup" "$target/yooooo-git-post-merge-cleanup"
```

Install all first-party skills to one target:

```bash
target="$HOME/.agents/skills"
mkdir -p "$target"
for skill_md in "$PWD"/*/SKILL.md; do
  [ -f "$skill_md" ] || continue
  skill_dir="$(dirname "$skill_md")"
  ln -sfn "$skill_dir" "$target/$(basename "$skill_dir")"
done
```

Install all first-party skills to several agents:

```bash
for target in \
  "$HOME/.agents/skills" \
  "$HOME/.claude/skills" \
  "$HOME/.config/opencode/skills" \
  "$HOME/.pi/agent/skills" \
  "${CODEX_HOME:-$HOME/.codex}/skills"
do
  mkdir -p "$target"
  for skill_md in "$PWD"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_dir="$(dirname "$skill_md")"
    ln -sfn "$skill_dir" "$target/$(basename "$skill_dir")"
  done
done
```

## Third-Party Skills

Submodules are a good fit when you want to pin community skills to exact upstream commits and update them deliberately:

```bash
git submodule add <repo-url> external/<owner>/<repo>
git submodule update --init --recursive
```

Clone this repository with submodules:

```bash
git clone --recurse-submodules git@github.com:KrabsWong/yooooo-skill.git
```

Use `git subtree` instead if you want third-party skill files copied into this repository without nested Git metadata. Submodules are cleaner for tracking upstream ownership; subtree is simpler for consumers who dislike submodule workflows.

Review third-party skill contents before installing them. Skills can include executable scripts and instructions that direct an agent to run commands.
