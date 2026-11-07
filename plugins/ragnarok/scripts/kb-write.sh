#!/usr/bin/env bash
# Helpers of the kb-write skill: the bench check of fixture mode, and the backup and restore of each write.
#
#   kb-write.sh bench <mirror>              print the bench home (the nearest ancestor folder of <mirror> that holds
#                                           .ragnarok-bench); exit 1 when there is none
#   kb-write.sh save <backup-dir> <file>... back up each file before the write: an existing file is copied (prints
#                                           "saved<TAB>path"), a missing file is recorded ("created<TAB>path"); a file
#                                           already in the backup keeps its first copy
#   kb-write.sh restore <backup-dir>        copy each saved file back and delete each created file
#
# Files are absolute paths with no newline or tab. `save` refuses a symbolic link. With KB_WRITE_WITHIN=<dir> (fixture
# mode: the mirror), `save` and `restore` refuse a path outside <dir>, and `save` refuses a file with more than one
# hard link. Use a new backup folder for each run (mktemp -d), so that a restore never touches another run.
# The backup folder holds manifest.tsv (one line per file or folder: saved|created|mkdir, a tab, the path) and
# files/<path>, the copies of the saved files.
set -euo pipefail

die() {
  printf 'kb-write.sh: %s\n' "$*" >&2
  exit 1
}

# The absolute path with . and .. removed. The file and its folders need not exist; the root folder must.
absolute() {
  local rest=$1 dir tail="" part
  case $rest in
    /*) ;;
    *) die "not an absolute path: $1" ;;
  esac
  dir=$rest
  while [ ! -d "$dir" ]; do
    part=$(basename "$dir")
    case $part in
      . | ..) die "a . or .. folder in $1" ;;
    esac
    tail="/$part$tail"
    dir=$(dirname "$dir")
  done
  dir=$(cd "$dir" && pwd -P)
  [ -n "$tail" ] || die "a folder, not a file: $1"
  printf '%s%s\n' "${dir%/}" "$tail"
}

# Record each missing folder of the path (outermost first), so that restore can remove it again.
record_folders() {
  local dir missing=()
  dir=$(dirname "$1")
  while [ ! -d "$dir" ]; do
    missing=("$dir" "${missing[@]+"${missing[@]}"}")
    dir=$(dirname "$dir")
  done
  for dir in "${missing[@]+"${missing[@]}"}"; do
    if ! cut -f2- "$2" | grep -Fxq -- "$dir"; then
      printf 'mkdir\t%s\n' "$dir" >>"$2"
    fi
  done
}

cmd_bench() {
  [ $# -eq 1 ] || die "usage: kb-write.sh bench <mirror>"
  local dir
  dir=$(cd "$1" 2>/dev/null && pwd -P) || die "no folder $1"
  # an ancestor only: the mirror itself is not its own bench home
  while [ "$dir" != / ]; do
    dir=$(dirname "$dir")
    if [ -f "$dir/.ragnarok-bench" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  die "$1 is not under a bench home (no .ragnarok-bench in an ancestor folder)"
}

# The resolved KB_WRITE_WITHIN folder, or nothing when it is not set.
within_dir() {
  if [ -n "${KB_WRITE_WITHIN:-}" ]; then
    (cd "$KB_WRITE_WITHIN" 2>/dev/null && pwd -P) || die "no folder $KB_WRITE_WITHIN"
  fi
}

# Exit when the path is not under the folder (no check when the folder is empty).
check_within() {
  [ -n "$2" ] || return 0
  case $1 in
    *$'\n'* | *$'\t'*) die "a newline or a tab in the path: $1" ;;
    "$2"/*) ;;
    *) die "$1 is outside $2" ;;
  esac
}

# The number of hard links of a file (GNU stat, else BSD stat).
link_count() {
  stat -c %h -- "$1" 2>/dev/null || stat -f %l -- "$1"
}

cmd_save() {
  [ $# -ge 2 ] || die "usage: kb-write.sh save <backup-dir> <file>..."
  local backup=$1 within file path links paths=()
  shift
  within=$(within_dir)
  # check every path before the first copy, so that a refusal leaves no partial backup
  for file in "$@"; do
    case $file in
      *$'\n'* | *$'\t'*) die "a newline or a tab in the path: $file" ;;
    esac
    path=$(absolute "$file")
    check_within "$path" "$within"
    if [ -L "$path" ]; then
      die "a symbolic link: $path (the files must be real files)"
    fi
    if [ -e "$path" ]; then
      [ -f "$path" ] || die "not a regular file: $path"
      if [ -n "$within" ]; then
        # fail closed: a link count that cannot be read refuses the file
        links=$(link_count "$path") || die "cannot read the link count: $path"
        case $links in
          '' | *[!0-9]*) die "cannot read the link count: $path" ;;
        esac
        if [ "$links" -gt 1 ]; then
          die "a file with more than one hard link: $path (the mirror must be a real copy)"
        fi
      fi
    fi
    paths+=("$path")
  done
  mkdir -p "$backup/files"
  touch "$backup/manifest.tsv"
  for path in "${paths[@]}"; do
    if cut -f2- "$backup/manifest.tsv" | grep -Fxq -- "$path"; then
      continue
    fi
    if [ -e "$path" ]; then
      mkdir -p "$backup/files$(dirname "$path")"
      cp -p "$path" "$backup/files$path"
      printf 'saved\t%s\n' "$path" >>"$backup/manifest.tsv"
      printf 'saved\t%s\n' "$path"
    else
      record_folders "$path" "$backup/manifest.tsv"
      printf 'created\t%s\n' "$path" >>"$backup/manifest.tsv"
      printf 'created\t%s\n' "$path"
    fi
  done
}

cmd_restore() {
  [ $# -eq 1 ] || die "usage: kb-write.sh restore <backup-dir>"
  local backup=$1 within state path failed=0
  [ -f "$backup/manifest.tsv" ] || die "no manifest.tsv in $backup"
  within=$(within_dir)
  # check every line before the first change
  while IFS=$'\t' read -r state path; do
    case $state in
      saved | created | mkdir) check_within "$path" "$within" ;;
      *) die "bad manifest line: $state" ;;
    esac
  done <"$backup/manifest.tsv"
  while IFS=$'\t' read -r state path; do
    case $state in
      saved)
        if [ ! -L "$path" ] && cp -p "$backup/files$path" "$path"; then
          printf 'restored\t%s\n' "$path"
        else
          printf 'FAILED\t%s\n' "$path" >&2
          failed=1
        fi
        ;;
      created)
        if rm -f -- "$path"; then
          printf 'deleted\t%s\n' "$path"
        else
          printf 'FAILED\t%s\n' "$path" >&2
          failed=1
        fi
        ;;
    esac
  done <"$backup/manifest.tsv"
  # the folders that save recorded as missing, innermost first; rmdir removes only an empty folder
  while IFS=$'\t' read -r state path; do
    if [ "$state" = mkdir ] && rmdir -- "$path" 2>/dev/null; then
      printf 'removed\t%s\n' "$path"
    fi
  done < <(grep $'^mkdir\t' "$backup/manifest.tsv" | sort -r -t $'\t' -k2)
  return "$failed"
}

[ $# -ge 1 ] || die "usage: kb-write.sh bench|save|restore ..."
command=$1
shift
case $command in
  bench) cmd_bench "$@" ;;
  save) cmd_save "$@" ;;
  restore) cmd_restore "$@" ;;
  *) die "unknown command: $command" ;;
esac
