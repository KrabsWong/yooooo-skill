# AGENTS.md

This repository stores portable Agent Skills.

## Repository Rules

- Keep first-party skills at the repository root as `<namespace>-<skill-name>/`.
- Use `yooooo-` as the namespace prefix for first-party skills.
- Reserve `external/` for third-party skill repositories, usually as Git submodules.
- Do not auto-install or modify third-party skills under `external/` unless explicitly requested.

## Skill Compatibility

- Target the Agent Skills format: each skill directory must contain `SKILL.md`.
- Keep the `name` field exactly equal to the parent directory name.
- Use lowercase letters, digits, and single hyphens only in skill names.
- Keep frontmatter portable: prefer only `name`, `description`, `license`, `compatibility`, and `metadata`.
- Avoid agent-specific config files inside skill directories unless the user explicitly asks for that agent integration.
- Put helper scripts in `scripts/`, optional documentation in `references/`, and static resources in `assets/`.

## Script Rules

- Scripts must be self-contained and avoid hardcoded user-specific paths.
- Destructive workflows should default to dry-run or explicit confirmation.
- Scripts should print clear failure messages that another agent can relay to the user.
