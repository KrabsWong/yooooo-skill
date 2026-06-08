#!/usr/bin/env bash

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
start_dir="$(pwd)"

dry_run=0
yes=0
list_only=0
want_all=0
want_first=0
want_external=0

skill_names=()
skill_paths=()
skill_origins=()
selected=()
targets=()
requested_skills=()

usage() {
  cat <<'USAGE'
Install Agent Skills from this repository by creating symlinks.

Usage:
  scripts/install-skills.sh
  scripts/install-skills.sh --list
  scripts/install-skills.sh --all --global codex --yes
  scripts/install-skills.sh --first-party --global all --yes
  scripts/install-skills.sh --skill write --project /path/to/project --yes
  scripts/install-skills.sh --all --target /path/to/skills --dry-run

Options:
  --all                  Install every discovered skill.
  --first-party          Install root-level first-party skills.
  --external             Install skills discovered under external/.
  --skill NAME           Install one skill by directory name. Repeatable.
  --global AGENT         shared, codex, claude, opencode, pi, or all.
  --project PATH         Install to PATH/.agents/skills.
  --target PATH          Install to an explicit skills directory.
  --dry-run              Print actions without creating links.
  --yes, -y              Skip confirmation.
  --list                 Print discovered skills and exit.
  --help, -h             Show this help.

Interactive mode runs when no options are provided.
Existing symlinks are updated. Real files or directories are skipped.
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

expand_path() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

relpath() {
  case "$1" in
    "$repo_root"/*) printf '%s\n' "${1#$repo_root/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

discover_skills() {
  local skill_md skill_dir

  while IFS= read -r skill_md; do
    [ -n "$skill_md" ] || continue
    skill_dir="$(dirname "$skill_md")"
    skill_names+=("$(basename "$skill_dir")")
    skill_paths+=("$skill_dir")
    skill_origins+=("first-party")
  done < <(find "$repo_root" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | sort)

  [ -d "$repo_root/external" ] || return

  while IFS= read -r skill_md; do
    [ -n "$skill_md" ] || continue
    skill_dir="$(dirname "$skill_md")"
    skill_names+=("$(basename "$skill_dir")")
    skill_paths+=("$skill_dir")
    skill_origins+=("external")
  done < <(find "$repo_root/external" -maxdepth 6 -name SKILL.md -type f | sort)
}

list_skills() {
  local i
  [ "${#skill_names[@]}" -gt 0 ] || die "no skills found"

  for i in "${!skill_names[@]}"; do
    printf '%2d) %-34s %-12s %s\n' \
      "$((i + 1))" \
      "${skill_names[$i]}" \
      "${skill_origins[$i]}" \
      "$(relpath "${skill_paths[$i]}")"
  done
}

add_target() {
  local target existing
  target="$(expand_path "$1")"

  for existing in "${targets[@]}"; do
    [ "$existing" = "$target" ] && return
  done

  targets+=("$target")
}

add_global_target() {
  case "$1" in
    all)
      add_global_target shared
      add_global_target codex
      add_global_target claude
      add_global_target opencode
      add_global_target pi
      ;;
    shared) add_target "$HOME/.agents/skills" ;;
    codex) add_target "${CODEX_HOME:-$HOME/.codex}/skills" ;;
    claude) add_target "$HOME/.claude/skills" ;;
    opencode) add_target "$HOME/.config/opencode/skills" ;;
    pi) add_target "$HOME/.pi/agent/skills" ;;
    *) die "unknown global target: $1" ;;
  esac
}

already_selected() {
  local idx existing
  idx="$1"
  for existing in "${selected[@]}"; do
    [ "$existing" = "$idx" ] && return 0
  done
  return 1
}

select_index() {
  local idx
  idx="$1"

  [ "$idx" -ge 0 ] && [ "$idx" -lt "${#skill_names[@]}" ] || die "skill index out of range: $((idx + 1))"
  already_selected "$idx" || selected+=("$idx")
}

select_all() {
  local i
  for i in "${!skill_names[@]}"; do
    select_index "$i"
  done
}

select_origin() {
  local origin i
  origin="$1"
  for i in "${!skill_names[@]}"; do
    [ "${skill_origins[$i]}" = "$origin" ] && select_index "$i"
  done
}

select_name() {
  local name i match_count match_index
  name="$1"
  match_count=0
  match_index=-1

  for i in "${!skill_names[@]}"; do
    if [ "${skill_names[$i]}" = "$name" ]; then
      match_count=$((match_count + 1))
      match_index="$i"
    fi
  done

  [ "$match_count" -gt 0 ] || die "skill not found: $name"
  [ "$match_count" -eq 1 ] || die "multiple skills named '$name'; choose by number in interactive mode"

  select_index "$match_index"
}

select_tokens() {
  local token start end n
  selected=()

  for token in $1; do
    if [ "$token" = "all" ]; then
      select_all
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      select_index "$((token - 1))"
    elif [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      [ "$start" -le "$end" ] || die "invalid range: $token"
      n="$start"
      while [ "$n" -le "$end" ]; do
        select_index "$((n - 1))"
        n="$((n + 1))"
      done
    else
      select_name "$token"
    fi
  done
}

resolve_cli_selection() {
  local name

  [ "$want_all" -eq 1 ] && select_all
  [ "$want_first" -eq 1 ] && select_origin first-party
  [ "$want_external" -eq 1 ] && select_origin external

  for name in "${requested_skills[@]}"; do
    select_name "$name"
  done

  [ "${#selected[@]}" -gt 0 ] || die "no skills selected"
}

print_summary() {
  local idx target

  printf '\nSelected skills:\n'
  for idx in "${selected[@]}"; do
    printf '  - %-34s %s\n' "${skill_names[$idx]}" "$(relpath "${skill_paths[$idx]}")"
  done

  printf '\nTarget directories:\n'
  for target in "${targets[@]}"; do
    printf '  - %s\n' "$target"
  done
  printf '\n'
}

confirm() {
  local answer
  [ "$yes" -eq 1 ] && return

  print_summary
  if [ "$dry_run" -eq 1 ]; then
    printf 'Run dry-run now? [y/N] '
  else
    printf 'Create/update these symlinks? [y/N] '
  fi
  read -r answer

  case "$answer" in
    y|Y|yes|YES) ;;
    *) die "cancelled" ;;
  esac
}

install_links() {
  local target idx source name dest current
  local linked=0 updated=0 already=0 conflicts=0

  [ "${#selected[@]}" -gt 0 ] || die "no skills selected"
  [ "${#targets[@]}" -gt 0 ] || die "no targets selected"

  for target in "${targets[@]}"; do
    for idx in "${selected[@]}"; do
      source="${skill_paths[$idx]}"
      name="${skill_names[$idx]}"
      dest="$target/$name"

      if [ "$dry_run" -eq 1 ]; then
        printf '[dry-run] mkdir -p %s\n' "$target"
        printf '[dry-run] ln -s %s %s\n' "$source" "$dest"
        continue
      fi

      mkdir -p "$target" || die "failed to create target directory: $target"

      if [ -L "$dest" ]; then
        current="$(readlink "$dest" || true)"
        if [ "$current" = "$source" ]; then
          printf 'already linked: %s -> %s\n' "$dest" "$source"
          already=$((already + 1))
        else
          rm "$dest" || die "failed to remove symlink: $dest"
          ln -s "$source" "$dest" || die "failed to create symlink: $dest"
          printf 'updated link:  %s -> %s\n' "$dest" "$source"
          updated=$((updated + 1))
        fi
      elif [ -e "$dest" ]; then
        printf 'skipped:       %s already exists and is not a symlink\n' "$dest" >&2
        conflicts=$((conflicts + 1))
      else
        ln -s "$source" "$dest" || die "failed to create symlink: $dest"
        printf 'linked:        %s -> %s\n' "$dest" "$source"
        linked=$((linked + 1))
      fi
    done
  done

  printf '\n'
  if [ "$dry_run" -eq 1 ]; then
    printf 'Dry-run complete.\n'
  else
    printf 'Done. linked=%d updated=%d already=%d conflicts=%d\n' "$linked" "$updated" "$already" "$conflicts"
    [ "$conflicts" -eq 0 ] || exit 1
  fi
}

interactive_main() {
  local choice tokens target_choice token project custom answer

  printf 'Skill installer\n'
  printf 'Repository: %s\n\n' "$repo_root"
  list_skills

  while true; do
    printf '\nInstall which skills?\n'
    printf '  1) All discovered skills\n'
    printf '  2) First-party skills only\n'
    printf '  3) External skills only\n'
    printf '  4) Choose by number/name\n'
    printf 'Choose [1-4]: '
    read -r choice

    case "$choice" in
      1) select_all; break ;;
      2) select_origin first-party; break ;;
      3) select_origin external; break ;;
      4)
        printf 'Enter numbers, ranges, names, or all. Example: 1 3-5 write\n'
        printf 'Skills: '
        read -r tokens
        [ -n "$tokens" ] || die "no skills selected"
        select_tokens "$tokens"
        break
        ;;
      *) printf 'Please choose 1, 2, 3, or 4.\n' ;;
    esac
  done

  printf '\nInstall where?\n'
  printf '  1) Shared global      %s/.agents/skills\n' "$HOME"
  printf '  2) Codex global       %s/skills\n' "${CODEX_HOME:-$HOME/.codex}"
  printf '  3) Claude Code global %s/.claude/skills\n' "$HOME"
  printf '  4) OpenCode global    %s/.config/opencode/skills\n' "$HOME"
  printf '  5) Pi global          %s/.pi/agent/skills\n' "$HOME"
  printf '  6) All global targets\n'
  printf '  7) Project-local      <project>/.agents/skills\n'
  printf '  8) Custom target directory\n'
  printf 'Enter one or more numbers. Example: 1 2 7\n'
  printf 'Targets: '
  read -r target_choice
  [ -n "$target_choice" ] || die "no targets selected"

  for token in $target_choice; do
    case "$token" in
      1) add_global_target shared ;;
      2) add_global_target codex ;;
      3) add_global_target claude ;;
      4) add_global_target opencode ;;
      5) add_global_target pi ;;
      6) add_global_target all ;;
      7)
        printf 'Project root [%s]: ' "$start_dir"
        read -r project
        [ -n "$project" ] || project="$start_dir"
        add_target "$(expand_path "$project")/.agents/skills"
        ;;
      8)
        printf 'Target skills directory: '
        read -r custom
        [ -n "$custom" ] || die "custom target cannot be empty"
        add_target "$custom"
        ;;
      *) die "unknown target choice: $token" ;;
    esac
  done

  printf '\nRun mode:\n'
  printf '  1) Install symlinks\n'
  printf '  2) Dry-run only\n'
  printf 'Choose [1-2]: '
  read -r answer
  case "$answer" in
    1) dry_run=0 ;;
    2) dry_run=1 ;;
    *) die "unknown run mode: $answer" ;;
  esac

  confirm
  install_links
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) want_all=1 ;;
      --first-party) want_first=1 ;;
      --external) want_external=1 ;;
      --skill)
        [ "$#" -ge 2 ] || die "--skill requires a value"
        requested_skills+=("$2")
        shift
        ;;
      --skill=*) requested_skills+=("${1#*=}") ;;
      --global)
        [ "$#" -ge 2 ] || die "--global requires a value"
        add_global_target "$2"
        shift
        ;;
      --global=*) add_global_target "${1#*=}" ;;
      --project)
        [ "$#" -ge 2 ] || die "--project requires a value"
        add_target "$(expand_path "$2")/.agents/skills"
        shift
        ;;
      --project=*) add_target "$(expand_path "${1#*=}")/.agents/skills" ;;
      --target)
        [ "$#" -ge 2 ] || die "--target requires a value"
        add_target "$2"
        shift
        ;;
      --target=*) add_target "${1#*=}" ;;
      --dry-run) dry_run=1 ;;
      --yes|-y) yes=1 ;;
      --list) list_only=1 ;;
      --help|-h) usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
    shift
  done
}

main() {
  discover_skills

  if [ "$#" -eq 0 ]; then
    [ -t 0 ] || { usage; exit 1; }
    interactive_main
    return
  fi

  parse_args "$@"

  if [ "$list_only" -eq 1 ]; then
    list_skills
    return
  fi

  resolve_cli_selection
  confirm
  install_links
}

main "$@"
