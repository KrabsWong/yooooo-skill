---
name: git-post-merge-cleanup
description: "Safely finish a Git branch after its work has been merged: verify a clean worktree, switch to the trunk branch, fetch/prune, pull the latest trunk with fast-forward only, then identify and optionally delete stale local and remote merged branches. Use when the user says a PR/branch has been merged, asks to return to main/master, pull trunk, prune branches, clean local or remote Git branches, or run post-merge Git cleanup across repositories."
---

# Git Post-Merge Cleanup

## Overview

Use this skill to complete the repeated post-merge workflow without losing work or deleting shared branches accidentally. Keep the workflow conservative: inspect first, sync trunk second, delete only candidates that are provably merged and explicitly approved.

## Safety Rules

- Require a clean worktree before switching branches or pulling. If `git status --short` is non-empty, stop and ask the user how to handle the changes. Do not stash, commit, or discard changes silently.
- Prefer the remote default branch from `origin/HEAD`; otherwise use `main`, then `master`, unless the user specifies a trunk branch.
- Use `git pull --ff-only` on trunk. Do not create merge commits during cleanup.
- Delete local branches with `git branch -d`, not `-D`, unless the user explicitly requests a forced delete.
- Treat remote deletion as destructive. List remote candidates and get explicit user confirmation before running `git push <remote> --delete <branch>`.
- Never delete protected branch names: `main`, `master`, `develop`, `dev`, `trunk`, `release`, `staging`, `production`, or `prod`.
- If branch ancestry, remote, or trunk is ambiguous, ask instead of guessing.

## Standard Workflow

1. Inspect the repository:
   - `git status --short --branch`
   - `git remote -v`
   - `git symbolic-ref --short refs/remotes/origin/HEAD` when available
2. Confirm the worktree is clean. If not clean, stop.
3. Fetch and prune:
   - `git fetch origin --prune`
4. Switch to trunk:
   - `git switch main`
   - If the local trunk does not exist but `origin/main` does, create the tracking branch with `git switch -c main --track origin/main`.
5. Update trunk:
   - `git pull --ff-only origin main`
6. Identify local branches merged into trunk:
   - `git branch --merged main`
   - Exclude the current branch, trunk, and protected names.
7. Delete local candidates only after confirming they are correct:
   - `git branch -d <branch>`
8. Identify remote branches merged into trunk:
   - `git branch -r --merged origin/main`
   - Exclude `origin/HEAD`, trunk, and protected names.
9. Delete remote candidates only after explicit confirmation:
   - `git push origin --delete <branch-without-origin-prefix>`
10. Verify final state:
   - `git status --short --branch`
   - `git branch`
   - `git branch -r`

## Script

Use `scripts/git-post-merge-cleanup.sh` when a deterministic dry run is useful.

Default dry run and trunk sync:

```bash
bash /path/to/git-post-merge-cleanup/scripts/git-post-merge-cleanup.sh
```

Specify a trunk or remote:

```bash
bash /path/to/git-post-merge-cleanup/scripts/git-post-merge-cleanup.sh --trunk main --remote origin
```

Delete local merged candidates after reviewing the dry-run output:

```bash
bash /path/to/git-post-merge-cleanup/scripts/git-post-merge-cleanup.sh --delete-local --yes
```

Delete remote merged candidates only after explicit user approval:

```bash
bash /path/to/git-post-merge-cleanup/scripts/git-post-merge-cleanup.sh --delete-remote --yes
```

## Reporting

When finished, report the trunk branch, remote, whether trunk was updated, which local branches were deleted, which remote branches were deleted, and any candidates intentionally left untouched.
