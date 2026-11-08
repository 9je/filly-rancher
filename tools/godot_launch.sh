#!/usr/bin/env bash
# THE ENGINE, AS EVERY TOOL HERE STARTS IT (tools/bin/godot is a link to this file; the binary
# is tools/bin/godot-4.7.2). G18: Godot keeps only five logs in the player's own folder
# (~/.local/share/godot/app_userdata/Filly Rancher/logs), so every launch that forgot
# --log-file rotated a log of the owner's real play out of it, and a brief rule to always pass
# it failed more than once. A log cannot be redirected from inside a script (the engine opens
# it before any script runs), so it is done here: a headless, scripted (-s/--script), import,
# check-only or export launch that names no --log-file gets one in a fresh temp directory.
# A RELATIVE --log-file is made absolute against the caller's directory: Godot resolves it
# against the player's own folder (user://), and a perf run's "build/..." path once grew a
# build/ tree in there.
# The player's own launch (play.sh: no -s, not headless) passes through untouched.
set -uo pipefail
real="$(dirname "$(readlink -f "$0")")/bin/godot-4.7.2"
tooling=0
has_log=0
args=()
want_log_path=0
for a in "$@"; do
  if [ "$want_log_path" = 1 ]; then
    want_log_path=0
    case "$a" in /*) ;; *) a="$PWD/$a" ;; esac
    args+=("$a")
    continue
  fi
  case "$a" in
    -s|--script|--headless|--import|--check-only|--export-release|--export-debug|--export-pack|--doctool)
      tooling=1 ;;
    --log-file)
      has_log=1; want_log_path=1 ;;
    --log-file=*)
      # Godot takes no "=" form: it would ignore the flag and log into the player's folder.
      has_log=1
      p="${a#--log-file=}"
      case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
      args+=(--log-file "$p")
      continue ;;
  esac
  args+=("$a")
done
if [ "$tooling" = 1 ] && [ "$has_log" = 0 ]; then
  exec "$real" --log-file "$(mktemp -d "${TMPDIR:-/tmp}/filly-godot-log.XXXXXX")/godot.log" "${args[@]}"
fi
exec "$real" "${args[@]}"
