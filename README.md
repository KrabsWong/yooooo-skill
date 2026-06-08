# yooooo-skills

Portable Agent Skills managed from one repository and installed with symlinks.

## Skills

| Skill | Purpose | Path |
| --- | --- | --- |
| `yooooo-git-post-merge-cleanup` | Sync trunk after a merge and safely prune merged Git branches. | `yooooo-git-post-merge-cleanup` |
| `yooooo-telegram-message-channel` | Send reports, alerts, and automation outputs to Telegram channels or chats. | `yooooo-telegram-message-channel` |

## Quick Start

Clone with submodules, install dependencies, then open the TUI installer:

```bash
git clone --recurse-submodules git@github.com:KrabsWong/yooooo-skill.git
cd yooooo-skill
npm install
npm run install-skills
```

The installer is a Node TUI powered by Ink. It can:

- install all, first-party, external, or selected skills
- show skill descriptions from `SKILL.md` before installation
- install to global agent locations, project-local `.agents/skills`, or a custom directory
- run in dry-run mode before writing symlinks
- inspect installed skills with `View installed skills`

Existing symlinks are updated. Existing real files or directories are skipped.

## Commands

```bash
# Open the interactive installer.
npm run install-skills

# List discovered skills.
npm run list-skills

# View installed skills in known global locations.
npm run installed-skills

# View installed skills for one project.
npm run installed-skills -- --project /path/to/project

# Install all discovered skills to Codex.
npm run install-skills -- --all --global codex --yes

# Install only first-party skills to all known global locations.
npm run install-skills -- --first-party --global all --yes

# Install one external skill into a project-local skill directory.
npm run install-skills -- --skill write --project /path/to/project --yes

# Preview without writing anything.
npm run install-skills -- --all --global codex --dry-run
```

Common global locations:

| Agent | Global skill directory |
| --- | --- |
| Agent-compatible shared path | `~/.agents/skills` |
| Codex | `${CODEX_HOME:-$HOME/.codex}/skills` |
| Claude Code | `~/.claude/skills` |
| OpenCode | `~/.config/opencode/skills` |
| Pi | `~/.pi/agent/skills` |

## Standalone Binary

Build a local standalone executable with Bun:

```bash
npm run build:bin
```

This writes `bin/yooooo-skills-install`. The generated file embeds the Bun runtime and the TUI code. It is not a shell script, and it does not require Node or Bun at runtime.

`bin/` is ignored by Git because the executable is large, platform-specific, and reproducible from source. If you want to distribute it, attach it to a GitHub Release instead of committing it to the repository.

Run it directly:

```bash
./bin/yooooo-skills-install
./bin/yooooo-skills-install --list
./bin/yooooo-skills-install --all --global codex --dry-run
```

The binary still needs this repository as the skill source because installation creates symlinks to directories such as `yooooo-*` and `external/*/skills/*`. Run it from this repository, keep it under `bin/`, or point it at the repository explicitly:

```bash
YOOOOO_SKILLS_REPO=/path/to/yooooo-skills ./bin/yooooo-skills-install
```

### Release Binary

Binary releases are built by GitHub Actions only when pushing a `bin-v*` tag:

```bash
git tag bin-v0.1.0
git push origin bin-v0.1.0
```

The workflow builds `yooooo-skills-install-darwin-arm64.tar.gz` and attaches it to the tag's GitHub Release. Normal skill-only changes on `main` do not run `build:bin`.

## Repository Layout

- `<namespace>-<skill-name>/` contains first-party skills maintained in this repository.
- `external/<source>/<repo>/` is reserved for third-party skill repositories added as Git submodules.
- Each skill directory must contain `SKILL.md`.
- Optional helper scripts, docs, and static files live in `scripts/`, `references/`, and `assets/` inside each skill directory.

## Third-Party Skills

Submodules are used to pin community skill repositories to exact upstream commits:

```bash
git submodule add <repo-url> external/<owner>/<repo>
git submodule update --init --recursive
```

Review third-party skill contents before installing them. Skills can include executable scripts and instructions that direct an agent to run commands.

## License

This repository's first-party code and skills are licensed under `AGPL-3.0-only`. See [LICENSE](LICENSE).

Third-party skills under `external/` are Git submodules and remain governed by their own upstream licenses.
