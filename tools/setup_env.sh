#!/usr/bin/env bash
# Downloads portable Godot + Blender into tools/bin/. Idempotent. No sudo.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin && cd bin

GODOT_VER="4.5.2-stable"   # latest 4.5.x stable as of 2026-08-26
if [ ! -x godot ]; then
  curl -fL --connect-timeout 30 --max-time 900 -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
  unzip -o godot.zip && mv "Godot_v${GODOT_VER}_linux.x86_64" godot && rm godot.zip
fi

BLENDER_VER="4.2.23"   # latest 4.2.x LTS as of 2026-08-26
if [ ! -x blender/blender ]; then
  # download.blender.org fronts downloads with a Cloudflare JS challenge that
  # blocks non-browser clients (curl gets HTTP 403 with no way to solve the
  # challenge), so we pull from the official mirror.clarkson.edu mirror instead.
  curl -fL --connect-timeout 30 --max-time 1800 -o blender.tar.xz "https://mirror.clarkson.edu/blender/release/Blender${BLENDER_VER%.*}/blender-${BLENDER_VER}-linux-x64.tar.xz"
  tar xf blender.tar.xz && mv "blender-${BLENDER_VER}-linux-x64" blender && rm blender.tar.xz
fi

./godot --version
./blender/blender --version | head -1
echo "toolchain ready"
