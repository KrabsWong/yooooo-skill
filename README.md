# yooooo-skills

Personal Codex skills managed as independent skill directories.

## Repository Layout

- `skills/<skill-name>/` contains first-party skills maintained in this repository.
- `external/<source>/<repo>/` is reserved for third-party skill repositories added as Git submodules.
- Keep each skill self-contained. Do not mix files from different skills in one directory.

## Skills

| Skill | Purpose | Path |
| --- | --- | --- |
| `git-post-merge-cleanup` | Sync trunk after a merge and safely prune merged Git branches. | `skills/git-post-merge-cleanup` |

## Install

Codex discovers skills under `$CODEX_HOME/skills`, or `~/.codex/skills` when `CODEX_HOME` is not set.

Install one skill with a symlink:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -sfn "$PWD/skills/git-post-merge-cleanup" "${CODEX_HOME:-$HOME/.codex}/skills/git-post-merge-cleanup"
```

Install all first-party skills:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
for skill in "$PWD"/skills/*; do
  [ -d "$skill" ] || continue
  ln -sfn "$skill" "${CODEX_HOME:-$HOME/.codex}/skills/$(basename "$skill")"
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
