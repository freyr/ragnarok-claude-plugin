#!/usr/bin/env bash
# Helpers of the kb-write skill: the bench check of fixture mode, and the backup and restore of each write.
#
#   kb-write.sh bench <mirror>              print the bench home (the nearest ancestor folder of <mirror> that holds
#                                           .ragnarok-bench); exit 1 when there is none
#   kb-write.sh save <backup-dir> <file>... back up each file before the write: an existing file is copied, a missing
#                                           file is recorded as created; a file already in the backup keeps its first copy
#   kb-write.sh restore <backup-dir>        copy each saved file back and delete each created file
#
# Files are absolute paths. With KB_WRITE_WITHIN=<dir>, `save` refuses a file outside <dir> (fixture mode: the mirror).
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

cmd_save() {
  [ $# -ge 2 ] || die "usage: kb-write.sh save <backup-dir> <file>..."
  local backup=$1 within="" file path
  shift
  if [ -n "${KB_WRITE_WITHIN:-}" ]; then
    within=$(cd "$KB_WRITE_WITHIN" 2>/dev/null && pwd -P) || die "no folder $KB_WRITE_WITHIN"
  fi
  mkdir -p "$backup/files"
  touch "$backup/manifest.tsv"
  for file in "$@"; do
    path=$(absolute "$file")
    if [ -n "$within" ]; then
      case $path in
        "$within"/*) ;;
        *) die "$path is outside $within" ;;
      esac
    fi
    if cut -f2- "$backup/manifest.tsv" | grep -Fxq -- "$path"; then
      continue
    fi
    if [ -e "$path" ]; then
      [ -f "$path" ] || die "not a regular file: $path"
      mkdir -p "$backup/files$(dirname "$path")"
      cp -p "$path" "$backup/files$path"
      printf 'saved\t%s\n' "$path" >>"$backup/manifest.tsv"
    else
      record_folders "$path" "$backup/manifest.tsv"
      printf 'created\t%s\n' "$path" >>"$backup/manifest.tsv"
    fi
    printf '%s\n' "$path"
  done
}

cmd_restore() {
  [ $# -eq 1 ] || die "usage: kb-write.sh restore <backup-dir>"
  local backup=$1 state path failed=0
  [ -f "$backup/manifest.tsv" ] || die "no manifest.tsv in $backup"
  while IFS=$'\t' read -r state path; do
    case $state in
      saved)
        if cp -p "$backup/files$path" "$path"; then
          printf 'restored\t%s\n' "$path"
        else
          printf 'FAILED\t%s\n' "$path" >&2
          failed=1
        fi
        ;;
      created)
        rm -f -- "$path"
        printf 'deleted\t%s\n' "$path"
        ;;
      mkdir) ;;
      *) die "bad manifest line: $state" ;;
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
