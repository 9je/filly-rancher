#!/usr/bin/env bash
# Downloads portable Godot + Blender into tools/bin/. Idempotent. No sudo.
set -euo pipefail
cd "$(dirname "$0")"
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

GODOT_VER="4.5.2-stable"   # latest 4.5.x stable as of 2026-08-26
# SHA512 pinned from the release's own SHA512-SUMS.txt:
# https://github.com/godotengine/godot/releases/download/4.5.2-stable/SHA512-SUMS.txt
GODOT_SHA512="e3ce6194b6d4d2dcef5e5b5136752c084d9d8b9071c10bc2d2011b947ec7439a257c8d23c541cb30699f16d9edea6dff36e6e84d2bec14a8fe9b4e9aacbe5a8d"
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
./blender/blender -b --python-expr "
import bpy
sd = bpy.context.preferences.filepaths.script_directories
if 'SourceIO_root' not in sd:
    item = sd.new()
    item.name = 'SourceIO_root'
    item.directory = '$SCRIPTS_ROOT'
bpy.utils.refresh_script_paths()
import addon_utils
addon_utils.modules_refresh()
bpy.ops.preferences.addon_enable(module='SourceIO')
bpy.ops.wm.save_userpref()
print('SOURCEIO_OK')
"

echo "toolchain ready"
