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
echo "toolchain ready"
