#!/usr/bin/env bash
set -euo pipefail

remote="origin"
trunk=""
delete_local=0
delete_remote=0
yes=0

usage() {
  cat <<'USAGE'
Usage: git-post-merge-cleanup.sh [options]

Sync the trunk branch, list merged local/remote branch cleanup candidates,
and optionally delete them.

Options:
  --remote <name>      Remote to use. Default: origin
  --trunk <name>       Trunk branch to use. Default: remote HEAD, main, master
  --delete-local       Delete merged local branch candidates
  --delete-remote      Delete merged remote branch candidates
  --yes                Required with --delete-local or --delete-remote
  -h, --help           Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      remote="${2:?missing value for --remote}"
      shift 2
      ;;
    --trunk)
      trunk="${2:?missing value for --trunk}"
      shift 2
      ;;
    --delete-local)
      delete_local=1
      shift
      ;;
    --delete-remote)
      delete_remote=1
      shift
      ;;
    --yes)
      yes=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$delete_local" -eq 1 || "$delete_remote" -eq 1 ]] && [[ "$yes" -ne 1 ]]; then
  echo "Refusing to delete branches without --yes." >&2
  exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a Git worktree." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain=v1)" ]]; then
  echo "Worktree is not clean. Resolve, commit, or stash changes before cleanup." >&2
  git status --short
  exit 1
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  echo "Remote '$remote' does not exist." >&2
  exit 1
fi

git fetch "$remote" --prune

if [[ -z "$trunk" ]]; then
  remote_head="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
  if [[ -n "$remote_head" ]]; then
    trunk="${remote_head#"$remote"/}"
  elif git show-ref --verify --quiet "refs/remotes/$remote/main"; then
    trunk="main"
  elif git show-ref --verify --quiet "refs/remotes/$remote/master"; then
    trunk="master"
  else
    echo "Could not determine trunk. Pass --trunk <branch>." >&2
    exit 1
  fi
fi

protected_regex='^(main|master|develop|dev|trunk|release|staging|production|prod)$'

if [[ "$trunk" =~ $protected_regex ]]; then
  :
else
  echo "Using non-standard trunk '$trunk'." >&2
fi

if git show-ref --verify --quiet "refs/heads/$trunk"; then
  git switch "$trunk"
elif git show-ref --verify --quiet "refs/remotes/$remote/$trunk"; then
  git switch -c "$trunk" --track "$remote/$trunk"
else
  echo "Trunk '$trunk' not found locally or on '$remote'." >&2
  exit 1
fi

git pull --ff-only "$remote" "$trunk"

local_candidates=()
while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  [[ "$branch" == "$trunk" ]] && continue
  [[ "$branch" =~ $protected_regex ]] && continue
  if git merge-base --is-ancestor "$branch" "$trunk"; then
    local_candidates+=("$branch")
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

remote_candidates=()
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  [[ "$ref" == "$remote/HEAD" ]] && continue
  branch="${ref#"$remote"/}"
  [[ "$branch" == "$trunk" ]] && continue
  [[ "$branch" =~ $protected_regex ]] && continue
  remote_candidates+=("$branch")
done < <(git branch -r --merged "$remote/$trunk" | sed 's/^[* ]*//')

echo
echo "Repository: $repo_root"
echo "Remote:     $remote"
echo "Trunk:      $trunk"

echo
echo "Merged local branch candidates:"
if [[ "${#local_candidates[@]}" -eq 0 ]]; then
  echo "  (none)"
else
  printf '  %s\n' "${local_candidates[@]}"
fi

echo
echo "Merged remote branch candidates:"
if [[ "${#remote_candidates[@]}" -eq 0 ]]; then
  echo "  (none)"
else
  printf '  %s\n' "${remote_candidates[@]}"
fi

if [[ "$delete_local" -eq 1 ]]; then
  for branch in "${local_candidates[@]}"; do
    git branch -d "$branch"
  done
fi

if [[ "$delete_remote" -eq 1 ]]; then
  for branch in "${remote_candidates[@]}"; do
    git push "$remote" --delete "$branch"
  done
fi

echo
git status --short --branch
