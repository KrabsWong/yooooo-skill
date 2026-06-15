# AGENTS.md

This repository stores the user's first-party skills and imported external skills.
The expected output of work in this repository is a reusable skill, or a focused change to an existing skill.

## Repository Rules

- Keep first-party skills at the repository root as `<namespace>-<skill-name>/`.
- Use `yooooo-` as the namespace prefix for first-party skills.
- Reserve `external/` for third-party skill repositories, usually as Git submodules.
- Do not auto-install or modify third-party skills under `external/` unless explicitly requested.

## Skill Authoring Rules

- Write skills for a class of recurring tasks, not for a single one-off case.
- Distill concrete examples into reusable workflows, checks, decision rules, or templates.
- Do not hardcode highly specific names, dates, companies, people, tickers, incidents, product releases, or one-time facts into the core skill instructions unless the skill's purpose is explicitly about that entity.
- If specific names or events are useful, put them in examples or references and label them as examples, not as universal rules.
- When updating a skill from a new sample, ask what general behavior the sample reveals before adding new instructions.

## Skill Compatibility

- Target the Agent Skills format: each skill directory must contain `SKILL.md`.
- Keep the `name` field exactly equal to the parent directory name.
- Use lowercase letters, digits, and single hyphens only in skill names.
- Keep frontmatter portable: prefer only `name`, `description`, `license`, `compatibility`, and `metadata`.
- Avoid agent-specific config files inside skill directories unless the user explicitly asks for that agent integration.
- Put helper scripts in `scripts/`, optional documentation in `references/`, and static resources in `assets/`.
- Design first-party skills to be portable across agents by default. Do not assume Codex, Claude Code, OpenCode, Pi, or any other single agent runtime unless the skill explicitly targets that integration.
- When a skill needs user-provided environment variables, prefix variable names with the skill namespace, such as `YOOOOO_`, to avoid collisions with the user's existing shell, CI, or agent environment.

## Script Rules

- Scripts must be self-contained and avoid hardcoded user-specific paths.
- Destructive workflows should default to dry-run or explicit confirmation.
- Scripts should print clear failure messages that another agent can relay to the user.
