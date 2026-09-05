#!/usr/bin/env bash
# Fetch and process every row of tools/sound_manifest.txt into game/assets/audio/, then
# regenerate game/assets/audio/sound_report.txt. This is tools/convert_props.sh's shape
# applied to audio: read that file first if anything here looks arbitrary.
#
# usage: tools/fetch_sounds.sh [--manifest FILE] [--only dest[,dest...]] [--force]
#                              [--dry-run]
#
# IDEMPOTENT. A dest that already exists is skipped unless --force or --only names it, so
# re-running after adding one row costs one download and one encode, not forty nine. The
# raw downloads live in tools/sound_cache/ (gitignored) and are never re-fetched.
#
# THE REPORT IS THE VERDICT. Every processed file is measured with ebur128 and written to
# the report as PASS or FAIL; a FAIL row makes the whole run exit non zero. Two things can
# fail a row: a true peak over the ceiling (the file clips), or an integrated loudness more
# than the tolerance away from the row's own gain= target. game/test/test_sound_library.gd
# asserts every LIBRARY file appears in that report with PASS, so a red row cannot be
# committed and forgotten.
#
# FILLY_FFMPEG and FILLY_FFPROBE override the binaries.
set -uo pipefail
cd "$(dirname "$0")/.."

MANIFEST="tools/sound_manifest.txt"
CACHE="tools/sound_cache"
OUT_ROOT="game/assets/audio"
REPORT="$OUT_ROOT/sound_report.txt"
FFMPEG="${FILLY_FFMPEG:-/usr/bin/ffmpeg}"
FFPROBE="${FILLY_FFPROBE:-/usr/bin/ffprobe}"
# kenney.nl's page serving is fine with curl, but a browser agent costs nothing and this
# script is the only thing in the project that talks to it.
UA="Mozilla/5.0 (X11; Linux x86_64)"
# True peak ceiling, dBTP. A row over this clips and fails.
PEAK_CEILING="-1.5"
# How far an integrated loudness may sit from its target before the row fails, in LU.
LUFS_TOLERANCE="2.0"

ONLY=""
FORCE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for bin in "$FFMPEG" "$FFPROBE" curl unzip; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: '$bin' not found on PATH." >&2
    exit 1
  fi
done
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: manifest '$MANIFEST' not found." >&2
  exit 1
fi

mkdir -p "$CACHE"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

wanted_row() {
  # $1 dest. Empty --only means every row.
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# --- source acquisition -------------------------------------------------------------------
#
# Two kinds of source. A plain URL is curled into the cache under its own basename. A URL
# with a #fragment is a zip plus the member wanted out of it: the zip is curled once, and
# the member is extracted into the cache under a name derived from both, so two rows taking
# two members of one zip share the single download.
fetch_source() {
  # $1 source_url. Prints the cached file path on stdout, or nothing on failure.
  local url="$1" zip_url member zip_path out
  case "$url" in
    *"#"*)
      zip_url="${url%%#*}"
      member="${url#*#}"
      zip_path="$CACHE/$(basename "$zip_url")"
      out="$CACHE/$(basename "$zip_url" .zip)__$(basename "$member")"
      if [ ! -s "$zip_path" ]; then
        curl -sSL -A "$UA" -o "$zip_path" "$zip_url" || return 1
      fi
      if [ ! -s "$out" ]; then
        unzip -p "$zip_path" "$member" > "$out" 2>/dev/null || return 1
        [ -s "$out" ] || return 1
      fi
      ;;
    *)
      out="$CACHE/$(basename "$url")"
      if [ ! -s "$out" ]; then
        curl -sSL -A "$UA" -o "$out" "$url" || return 1
      fi
      ;;
  esac
  [ -s "$out" ] || return 1
  printf '%s' "$out"
}

# --- the pick verb --------------------------------------------------------------------------
#
# "The Nth non silent segment". silencedetect prints a silence_end for the start of every
# non silent run and a silence_start for its end; walking those pairs gives a segment list
# that is a function of the audio and of nothing else, which is why this exists instead of
# hand typed trim windows that drift the moment a source is re-downloaded.
pick_window() {
  # $1 file, $2 index (1 based), $3 noise floor dB, $4 minimum silence seconds.
  # Prints "START END" or nothing.
  local file="$1" want="$2" noise="${3:--30}" dur="${4:-0.12}"
  "$FFMPEG" -nostats -hide_banner -i "$file" \
    -af "silencedetect=noise=${noise}dB:d=$dur" -f null - 2>&1 \
  | awk -v want="$want" '
      /silence_end/ { for (i = 1; i <= NF; i++) if ($i == "silence_end:") start = $(i + 1) + 0 ; have = 1 }
      /silence_start/ {
        if (have) {
          for (i = 1; i <= NF; i++) if ($i == "silence_start:") stop = $(i + 1) + 0
          n += 1
          if (n == want) { printf "%.3f %.3f\n", start, stop ; exit }
          have = 0
        }
      }
    '
}

# --- one row ---------------------------------------------------------------------------------
process_row() {
  # $1 dest, $2 source_url, $3 recipe. Echoes one report line. Returns 1 on failure.
  local dest="$1" url="$2" recipe="$3"
  local out="$OUT_ROOT/$dest"
  local src work ext filters rate="44100" chans="2"
  local trim="" pick="" speed="" loopsec="" fadein="" fadeout="" target="" gaindb=""

  local verb
  IFS=',' read -ra verbs <<< "$recipe"
  for verb in "${verbs[@]}"; do
    case "$verb" in
      rate=*)    rate="${verb#rate=}" ;;
      mono)      chans="1" ;;
      trim=*)    trim="${verb#trim=}" ;;
      pick=*)    pick="${verb#pick=}" ;;
      speed=*)   speed="${verb#speed=}" ;;
      loop=*)    loopsec="${verb#loop=}" ;;
      fade=*)    fadein="${verb#fade=}"; fadeout="${fadein#*:}"; fadein="${fadein%%:*}" ;;
      gain=*)    target="${verb#gain=}" ;;
      gain_db=*) gaindb="${verb#gain_db=}" ;;
      "")        ;;
      *) echo "  unknown recipe verb '$verb' in row '$dest'" >&2; return 1 ;;
    esac
  done

  src="$(fetch_source "$url")" || { echo "  download failed: $url" >&2; return 1; }
  [ -n "$src" ] || { echo "  download failed: $url" >&2; return 1; }

  mkdir -p "$(dirname "$out")"
  work="$tmp_root/$(basename "$dest").wav"

  # STAGE 1: cut. pick= wins over trim= when both are given, because pick= is the measured
  # answer and trim= is the guess somebody wrote down.
  local cut_args=()
  if [ -n "$pick" ]; then
    local window start stop pick_n pick_noise pick_dur pick_tune
    pick_n="${pick%%@*}"
    pick_noise="-30"; pick_dur="0.12"
    case "$pick" in
      *"@"*)
        pick_tune="${pick#*@}"
        pick_noise="${pick_tune%%:*}"
        pick_dur="${pick_tune#*:}"
        ;;
    esac
    window="$(pick_window "$src" "$pick_n" "$pick_noise" "$pick_dur")"
    if [ -z "$window" ]; then
      echo "  pick=$pick found no such segment in $src" >&2
      return 1
    fi
    start="${window%% *}"; stop="${window##* }"
    cut_args=(-ss "$start" -to "$stop")
  elif [ -n "$trim" ]; then
    cut_args=(-ss "${trim%%-*}" -to "${trim##*-}")
  fi

  # STAGE 2: the filter chain, in a fixed order so a row's meaning never depends on the
  # order somebody happened to type the verbs in.
  filters="aresample=$rate"
  [ "$chans" = "1" ] && filters="$filters,pan=mono|c0=0.5*c0+0.5*c1"
  if [ -n "$speed" ]; then
    filters="$filters,asetrate=$(awk -v r="$rate" -v s="$speed" 'BEGIN{printf "%d", r*s}'),aresample=$rate"
  fi

  if [ -n "$loopsec" ]; then
    # A SEAMLESS BUTT LOOP. Take loopsec plus one second of overlap, split it, and
    # acrossfade the overlap tail into the head: the file's last second and its first are
    # then the same material, so playing it end to start has no seam. Godot loops the ogg
    # on its own with loop=true in the .import sidecar; this is only about the join.
    local total overlap
    overlap="1.0"
    total="$(awk -v a="$loopsec" -v b="$overlap" 'BEGIN{printf "%.3f", a+b}')"
    "$FFMPEG" -y -nostats -hide_banner "${cut_args[@]}" -i "$src" -t "$total" \
      -filter_complex \
        "[0:a]$filters,asplit=2[a][b];[a]atrim=0:$loopsec[head];[b]atrim=$loopsec,asetpts=PTS-STARTPTS[tail];[head][tail]acrossfade=d=$overlap:c1=tri:c2=tri[out]" \
      -map "[out]" -c:a pcm_s16le "$work" >/dev/null 2>&1 || {
        echo "  ffmpeg loop stage failed for $dest" >&2; return 1; }
  else
    [ -n "$fadein" ] && filters="$filters,afade=t=in:st=0:d=$fadein"
    "$FFMPEG" -y -nostats -hide_banner "${cut_args[@]}" -i "$src" \
      -af "$filters" -c:a pcm_s16le "$work" >/dev/null 2>&1 || {
        echo "  ffmpeg cut stage failed for $dest" >&2; return 1; }
    if [ -n "$fadeout" ]; then
      local dur faded
      dur="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$work")"
      faded="$tmp_root/faded_$(basename "$dest").wav"
      "$FFMPEG" -y -nostats -hide_banner -i "$work" \
        -af "afade=t=out:st=$(awk -v d="$dur" -v f="$fadeout" 'BEGIN{printf "%.3f", (d-f > 0 ? d-f : 0)}'):d=$fadeout" \
        -c:a pcm_s16le "$faded" >/dev/null 2>&1 || {
          echo "  ffmpeg fade stage failed for $dest" >&2; return 1; }
      mv "$faded" "$work"
    fi
  fi

  # STAGE 3: level. A loudness target is hit by measuring the work file with the same
  # ebur128 filter the report verdict uses, then applying the one flat gain that closes
  # the gap; integrated loudness shifts by exactly the gain applied (a linear property of
  # BS.1770), so this lands on target for a two second one shot as reliably as for a
  # minute long bed, where ffmpeg's own loudnorm filter measures short transient material
  # through a different gating path than ebur128 does and can miss by several LU.
  # gain_db= skips measurement entirely and applies a flat gain, for a one shot too short
  # for EBU gating to measure honestly at all.
  local levelled="$tmp_root/level_$(basename "$dest").wav"
  if [ -n "$target" ]; then
    local measured needed
    measured="$(measure_integrated "$work")"
    needed="$(awk -v t="$target" -v m="$measured" 'BEGIN{printf "%.2f", t - m}')"
    "$FFMPEG" -y -nostats -hide_banner -i "$work" \
      -af "volume=${needed}dB,alimiter=limit=0.84" \
      -ar "$rate" -c:a pcm_s16le "$levelled" >/dev/null 2>&1 || {
        echo "  loudness gain failed for $dest" >&2; return 1; }
  else
    "$FFMPEG" -y -nostats -hide_banner -i "$work" \
      -af "volume=${gaindb:-0}dB,alimiter=limit=0.84" \
      -ar "$rate" -c:a pcm_s16le "$levelled" >/dev/null 2>&1 || {
        echo "  gain stage failed for $dest" >&2; return 1; }
  fi

  # STAGE 4: encode to whatever the dest's extension asks for.
  ext="${dest##*.}"
  if [ "$ext" = "ogg" ]; then
    "$FFMPEG" -y -nostats -hide_banner -i "$levelled" -c:a libvorbis -q:a 5 "$out" \
      >/dev/null 2>&1 || { echo "  ogg encode failed for $dest" >&2; return 1; }
  else
    "$FFMPEG" -y -nostats -hide_banner -i "$levelled" -c:a pcm_s16le "$out" \
      >/dev/null 2>&1 || { echo "  wav encode failed for $dest" >&2; return 1; }
  fi

  measure_row "$dest" "$out" "${target:-none}"
}

# --- measurement -------------------------------------------------------------------------
measure_integrated() {
  # $1 file. Prints its integrated loudness in LUFS via the same ebur128 filter measure_row
  # verifies with, so a gain computed from this and a verdict read from measure_row always
  # agree.
  local file="$1" summary integrated
  summary="$("$FFMPEG" -nostats -hide_banner -i "$file" -filter_complex ebur128=peak=true \
    -f null - 2>&1 | tail -40)"
  integrated="$(printf '%s' "$summary" | grep -A1 'Integrated loudness' | grep -oE 'I: *-?[0-9.]+' | grep -oE '\-?[0-9.]+$' | tail -1)"
  printf '%s' "${integrated:-0}"
}

measure_row() {
  # $1 dest, $2 file, $3 target LUFS or "none". Echoes the report line; returns 1 on FAIL.
  local dest="$1" file="$2" target="$3" summary integrated peak dur verdict
  dur="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$file")"
  summary="$("$FFMPEG" -nostats -hide_banner -i "$file" -filter_complex ebur128=peak=true \
    -f null - 2>&1 | tail -40)"
  integrated="$(printf '%s' "$summary" | grep -A1 'Integrated loudness' | grep -oE 'I: *-?[0-9.]+' | grep -oE '\-?[0-9.]+$' | tail -1)"
  peak="$(printf '%s' "$summary" | grep -A1 'True peak' | grep -oE 'Peak: *-?[0-9.]+' | grep -oE '\-?[0-9.]+$' | tail -1)"
  integrated="${integrated:-0}"
  peak="${peak:-0}"
  verdict="PASS"
  if awk -v p="$peak" -v c="$PEAK_CEILING" 'BEGIN{exit !(p > c)}'; then
    verdict="FAIL"
  fi
  if [ "$target" != "none" ]; then
    if awk -v i="$integrated" -v t="$target" -v tol="$LUFS_TOLERANCE" \
        'BEGIN{d = i - t; if (d < 0) d = -d; exit !(d > tol)}'; then
      verdict="FAIL"
    fi
  fi
  printf '%-4s  %-34s  dur=%-8.2f  I=%-8s  TP=%-7s  target=%s\n' \
    "$verdict" "$dest" "$dur" "$integrated" "$peak" "$target"
  [ "$verdict" = "PASS" ]
}

# --- the run -------------------------------------------------------------------------------
#
# The manifest is read on its own descriptor (fd 3), not stdin. ffmpeg polls stdin for
# keyboard shortcuts even when it is not a terminal, and a plain "done < $MANIFEST" hands
# ffmpeg the same descriptor the read builtin is walking, which steals bytes out of the
# manifest mid loop and mangles the next row.
rows=0; made=0; skipped=0; failed=0
report_lines=""

while IFS= read -r line <&3; do
  case "$line" in ""|"#"*) continue ;; esac
  dest="${line%%|*}"
  rest="${line#*|}"
  url="${rest%%|*}"
  recipe="${rest#*|}"
  rows=$((rows + 1))
  wanted_row "$dest" || continue
  if [ "$DRY" = "1" ]; then
    echo "would process: $dest  <- $url  [$recipe]"
    continue
  fi
  if [ -s "$OUT_ROOT/$dest" ] && [ "$FORCE" = "0" ] && [ -z "$ONLY" ]; then
    skipped=$((skipped + 1))
    skip_target="$(printf '%s' "$recipe" | grep -oE '(^|,)gain=-?[0-9.]+' | grep -oE '\-?[0-9.]+$')"
    skip_target="${skip_target:-none}"
    line_out="$(measure_row "$dest" "$OUT_ROOT/$dest" "$skip_target")"
    measured=$?
    report_lines="$report_lines$line_out"$'\n'
    [ "$measured" -ne 0 ] && failed=$((failed + 1))
    continue
  fi
  echo "processing: $dest"
  if line_out="$(process_row "$dest" "$url" "$recipe")"; then
    made=$((made + 1))
  else
    failed=$((failed + 1))
    line_out="${line_out:-FAIL  $dest  (processing error, see above)}"
  fi
  report_lines="$report_lines$line_out"$'\n'
done 3< "$MANIFEST"

if [ "$DRY" = "1" ]; then
  echo "dry run: $rows row(s) in $MANIFEST"
  exit 0
fi

{
  echo "# Regenerated by tools/fetch_sounds.sh. Do not hand edit."
  echo "# Loudness targets: ambient beds -24 LUFS, world and casino SFX -18, UI -20."
  echo "# True peak ceiling $PEAK_CEILING dBTP; LUFS tolerance $LUFS_TOLERANCE LU."
  echo "# A row reading FAIL fails the run, and game/test/test_sound_library.gd fails too."
  printf '%s' "$report_lines" | sort -k2
} > "$REPORT"

echo "sounds: $made processed, $skipped already present, $failed failed, of $rows row(s)."
[ "$failed" -eq 0 ]
