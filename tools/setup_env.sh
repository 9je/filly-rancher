#!/usr/bin/env bash
# Downloads portable Godot + Blender into tools/bin/. Idempotent. No sudo.
set -euo pipefail
cd "$(dirname "$0")"

# Preflight: every external command this script shells out to. Failing here with a
# clear name beats failing 200MB into a download with a bare "command not found".
for c in curl unzip tar sha256sum sha512sum awk; do
  command -v "$c" >/dev/null || { echo "missing required command: $c" >&2; exit 1; }
done

mkdir -p bin && cd bin

# Verifies $1 against the pinned hash $2 using algorithm $3 (sha256sum/sha512sum).
# Fails hard (removes the bad file, exits non-zero) on any mismatch so a
# corrupted or tampered download can never silently reach extraction.
verify_checksum() {
  local file="$1" expected="$2" tool="$3" actual
  actual="$("$tool" "$file" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: checksum mismatch for $file" >&2
    echo "  expected ($tool): $expected" >&2
    echo "  actual   ($tool): $actual" >&2
    rm -f "$file"
    exit 1
  fi
}

GODOT_VER="4.7.2-stable"   # latest stable as of 2026-10-22 (v1 overhaul, M0.1)
# SHA512 pinned from the release's own SHA512-SUMS.txt:
# https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt
GODOT_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
if [ ! -x godot ]; then
  curl -fL --connect-timeout 30 --max-time 900 -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
  verify_checksum godot.zip "$GODOT_SHA512" sha512sum
  unzip -o godot.zip && mv "Godot_v${GODOT_VER}_linux.x86_64" godot && rm godot.zip
fi

BLENDER_VER="4.2.23"   # latest 4.2.x LTS as of 2026-08-26
# download.blender.org fronts both the tarball and its .sha256 with a
# Cloudflare JS challenge that blocks non-browser clients (curl gets HTTP 403
# with no way to solve the challenge), so we pull the tarball from the
# official mirror.clarkson.edu mirror instead. The pinned hash below is from
# that same mirror's published checksum file:
# https://mirror.clarkson.edu/blender/release/Blender4.2/blender-4.2.23.sha256
# (the "blender-4.2.23-linux-x64.tar.xz" line), and was cross-checked by
# independently computing sha256sum on the tarball actually downloaded from
# the mirror -- it matched exactly.
BLENDER_SHA256="bea0eb3146be13eae6225409a117b215184f41b7f79e799f97cb3abb8f6dc404"
if [ ! -x blender/blender ]; then
  curl -fL --connect-timeout 30 --max-time 1800 -o blender.tar.xz "https://mirror.clarkson.edu/blender/release/Blender${BLENDER_VER%.*}/blender-${BLENDER_VER}-linux-x64.tar.xz"
  verify_checksum blender.tar.xz "$BLENDER_SHA256" sha256sum
  tar xf blender.tar.xz && mv "blender-${BLENDER_VER}-linux-x64" blender && rm blender.tar.xz
fi

./godot --version
./blender/blender --version | head -1

# SourceIO: Blender addon for importing Source-engine .mdl/.bsp/.vtf/.vmt (Task 6, tier-c probe).
# Master's __init__.py hard-requires bpy.app.version >= (4, 2, 0) and Python 3.11+
# (Blender 4.2 is the oldest Blender bundling Python 3.11, which the addon's
# compiled pylib needs) -- https://github.com/REDxEYE/SourceIO/blob/master/__init__.py
# Release 5.5.4 (2026-08-03, non-prerelease) is current as of 2026-08-26 and its
# release notes list "Minimum Blender version raised to 4.0", i.e. compatible with
# our pinned Blender 4.2.23. Hash below is sha256 of the downloaded SourceIO.zip,
# cross-checked against the "digest" field GitHub's Releases API reports for this
# asset (`gh api repos/REDxEYE/SourceIO/releases/tags/5.5.4`) -- both matched exactly.
#
# NOTE on layout: this portable Blender has no "portable install" marker, so by
# default it reads/writes user prefs and addons from the OS user config dir
# (~/.config/blender/4.2/), not a tree under tools/bin/. To keep the addon itself
# repo-local we register a *second* script-search root via the
# preferences.filepaths.script_directories API (Blender 4.2+) pointing at
# tools/bin/blender_scripts/{addons/SourceIO}, then call bpy.utils.refresh_script_paths()
# so sys.path actually picks it up (addon_utils.modules() lists the module without
# this, but bpy.ops.preferences.addon_enable's importlib.import_module still fails
# with "No module named 'SourceIO'" until refresh_script_paths() runs). That
# script-directory registration + the addon's enabled flag are then persisted via
# save_userpref() into the (non-portable, home-dir) userpref.blend, so later
# headless invocations of tools/bin/blender/blender pick SourceIO up automatically
# with no extra flags/env vars -- verified by relaunching blender fresh and checking
# hasattr(bpy.ops, 'sourceio') without repeating any of the steps below.
SOURCEIO_VER="5.5.4"
SOURCEIO_SHA256="c6da6d989120b430df0a74315307fc42b8f87fa3c1d98554ee589c7e93f79e4d"
SCRIPTS_ROOT="$PWD/blender_scripts"
ADDONS_DIR="$SCRIPTS_ROOT/addons"
if [ ! -d "$ADDONS_DIR/SourceIO" ]; then
  mkdir -p "$ADDONS_DIR"
  curl -fL --connect-timeout 30 --max-time 300 -o sourceio.zip "https://github.com/REDxEYE/SourceIO/releases/download/${SOURCEIO_VER}/SourceIO.zip"
  verify_checksum sourceio.zip "$SOURCEIO_SHA256" sha256sum
  # The release zip's top-level folder is "SourceIO-master/", not "SourceIO/" --
  # bpy's addon loader keys the module name off the folder name, so it must be
  # renamed or bpy.ops.preferences.addon_enable(module='SourceIO') can't find it.
  rm -rf "$ADDONS_DIR/SourceIO"
  unzip -oq sourceio.zip -d "$ADDONS_DIR" && rm sourceio.zip
  mv "$ADDONS_DIR/SourceIO-master" "$ADDONS_DIR/SourceIO"
fi
# The `directory` is (re)assigned unconditionally, not just when the named entry is
# missing: the entry is keyed by NAME, so a userpref.blend carrying a 'SourceIO_root'
# pointing at a moved/renamed/other checkout would otherwise never be corrected and
# every tier-c run would keep failing with ModuleNotFoundError. Rewriting it every
# run is what actually makes this self-healing.
#
# Blender exits 0 even when a --python-expr raises, so `set -e` cannot see a failed
# enable -- the SOURCEIO_OK marker is the only trustworthy success signal, hence the
# grep gate below. Without it this script printed "toolchain ready" over a broken
# SourceIO install.
sourceio_log="$(./blender/blender -b --python-expr "
import bpy
sd = bpy.context.preferences.filepaths.script_directories
item = sd.get('SourceIO_root')
if item is None:
    item = sd.new()
    item.name = 'SourceIO_root'
item.directory = '$SCRIPTS_ROOT'
bpy.utils.refresh_script_paths()
import addon_utils
addon_utils.modules_refresh()
bpy.ops.preferences.addon_enable(module='SourceIO')
bpy.ops.wm.save_userpref()
print('SOURCEIO_OK')
" 2>&1 || true)"
printf '%s\n' "$sourceio_log"
printf '%s\n' "$sourceio_log" | grep -q SOURCEIO_OK || { echo "ERROR: SourceIO enable failed" >&2; exit 1; }


# GUT (Godot Unit Test): headless GDScript test framework, installed as a Godot addon
# under game/addons/gut/ (must live inside the Godot project tree at that exact path --
# it's loaded via res://addons/gut/..., not from tools/bin/).
#
# Version pin: GUT's own README compatibility table (https://github.com/bitwes/Gut/blob/master/README.md,
# "Version Links" section) lists 9.7.1 as the row for Godot 4.7.x, matching our pinned
# Godot 4.7.2 (9.5.0 was the 4.5.x row, used before the v1 engine upgrade). Fetched from the tag's GitHub source-archive zip (no
# packaged release asset is published for this repo, only the archive/tarball links the
# README itself points at). SHA256 below was computed locally on the downloaded bytes and
# cross-checked by downloading the same URL a second time independently -- both runs produced
# byte-identical zips and the identical hash.
GUT_VER="9.7.1"
GUT_SHA256="14969aa46adc84aa08cdd21b9f6d1a64addd92ae60b36f02d0521ed305aa4086"
GUT_TARGET="../../game/addons/gut"
if [ ! -f "$GUT_TARGET/plugin.cfg" ]; then
  curl -fL --connect-timeout 30 --max-time 300 -o gut.zip "https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VER}.zip"
  verify_checksum gut.zip "$GUT_SHA256" sha256sum
  rm -rf gut_extract
  mkdir -p gut_extract
  unzip -oq gut.zip -d gut_extract
  rm -f gut.zip
  rm -rf "$GUT_TARGET"
  mkdir -p "$(dirname "$GUT_TARGET")"
  mv "gut_extract/Gut-${GUT_VER}/addons/gut" "$GUT_TARGET"
  rm -rf gut_extract
fi
# Verify actual installed content, not just that the commands above didn't error --
# a wrong archive-internal layout (e.g. a GitHub zip restructuring) could leave mv
# succeeding against the wrong source path or the target missing its real contents.
# Gated on a printed marker so this step can never be reported as succeeding when it
# didn't (same reasoning as the SourceIO SOURCEIO_OK gate above).
if [ -f "$GUT_TARGET/plugin.cfg" ] && grep -q "version=\"${GUT_VER}\"" "$GUT_TARGET/plugin.cfg"; then
  echo "GUT_INSTALL_OK"
else
  echo "ERROR: GUT install verification failed (missing or wrong-version plugin.cfg at $GUT_TARGET)" >&2
  exit 1
fi

echo "toolchain ready"
