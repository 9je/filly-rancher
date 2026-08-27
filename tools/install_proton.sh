#!/usr/bin/env bash
# Downloads a pinned GE-Proton (Glorious Eggroll's Proton-GE) release tarball
# and extracts it into Steam's compatibilitytools.d/ so `proton run <exe>` and
# the bundled wine64 work for the Windows-build verification tier
# (tools/run_windows_build.sh, docs/windows-testing.md). Idempotent. No sudo,
# no GUI, no ProtonUp-Qt -- a plain GitHub Releases download, same integrity
# discipline as tools/setup_env.sh (pinned version + provenance comment +
# verify_checksum + guard + success gated on a printed marker).
#
# Proton itself is NOT installed under this repo and is NOT gitignored-inside
# -- it lives entirely under ~/.steam/root/compatibilitytools.d/, outside the
# repo tree, so there is nothing here for git to ever pick up.
set -euo pipefail
cd "$(dirname "$0")"

for c in curl tar sha512sum awk; do
  command -v "$c" >/dev/null || { echo "missing required command: $c" >&2; exit 1; }
done

# Same verify_checksum shape as tools/setup_env.sh: fails hard (removes the
# bad file, exits non-zero) on any mismatch so a corrupted or tampered
# download can never silently reach extraction.
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

PROTON_VER="GE-Proton11-5"   # latest proton-ge-custom release as of 2026-08-27
# SHA512 pinned from the release's own published sums file (fetched directly,
# not computed by us first and only cross-checked afterward):
# https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-5/GE-Proton11-5-x86_64.sha512sum
# -> "8fb1f3ae65a8dc22efd8099ff489075f0eebddf01c445b423244589f6f0a1e19c01de5d1e722b97fc1ebaf6390c813052ed55290058f8d21f1353a36146f4a2c  GE-Proton11-5-x86_64.tar.gz"
# Cross-checked against the "digest" field GitHub's Releases API reports for
# this asset (sha256, a different algorithm, so it is a check on the download
# being the right bytes, not a redundant re-statement of the same hash):
# `curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/tags/GE-Proton11-5`
# -> asset "GE-Proton11-5-x86_64.tar.gz", digest "sha256:de43c4b25f3c047db49b96c44d84759952c5a01332a68805a09e69f95dc38a75"
PROTON_SHA512="8fb1f3ae65a8dc22efd8099ff489075f0eebddf01c445b423244589f6f0a1e19c01de5d1e722b97fc1ebaf6390c813052ed55290058f8d21f1353a36146f4a2c"

COMPAT_ROOT="${STEAM_COMPAT_TOOLS_D:-$HOME/.steam/root/compatibilitytools.d}"
INSTALL_DIR="$COMPAT_ROOT/$PROTON_VER"
DOWNLOAD_DIR="$(mktemp -d)"
trap 'rm -rf "$DOWNLOAD_DIR"' EXIT

mkdir -p "$COMPAT_ROOT"

if [ ! -x "$INSTALL_DIR/proton" ]; then
  echo "Downloading $PROTON_VER (~530MB)..." >&2
  curl -fL --connect-timeout 30 --max-time 1800 -C - \
    -o "$DOWNLOAD_DIR/proton.tar.gz" \
    "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VER}/${PROTON_VER}-x86_64.tar.gz"
  verify_checksum "$DOWNLOAD_DIR/proton.tar.gz" "$PROTON_SHA512" sha512sum
  rm -rf "$COMPAT_ROOT/${PROTON_VER}.partial"
  mkdir -p "$COMPAT_ROOT/${PROTON_VER}.partial"
  tar xf "$DOWNLOAD_DIR/proton.tar.gz" -C "$COMPAT_ROOT/${PROTON_VER}.partial" --strip-components=1
  rm -rf "$INSTALL_DIR"
  mv "$COMPAT_ROOT/${PROTON_VER}.partial" "$INSTALL_DIR"
fi

# Verify actual installed content, not just that the commands above didn't
# error -- same reasoning as setup_env.sh's SOURCEIO_OK / GUT_INSTALL_OK
# gates: a wrong archive-internal layout could leave `tar` succeeding against
# the wrong path or the target missing its real contents.
#
# files/bin/wine64 does NOT exist in this GE-Proton11-5 layout -- Wine 10+
# dropped separate 32-bit/64-bit launcher binaries in favor of one unified
# files/bin/wine (confirmed by inspecting the extracted tree: `file` reports
# it as a 64-bit ELF, and the real wine64 PE loader lives one level down at
# files/lib/wine/x86_64-unix/wine64, an internal binary invoked BY files/bin/wine,
# not meant to be run directly). Accept whichever of the two exists so this
# check tracks the two Proton layouts users may actually have pinned, rather
# than hard-failing a correct install because an older assumption baked in
# the "wine64" filename.
wine_bin=""
[ -x "$INSTALL_DIR/files/bin/wine64" ] && wine_bin="$INSTALL_DIR/files/bin/wine64"
[ -z "$wine_bin" ] && [ -x "$INSTALL_DIR/files/bin/wine" ] && wine_bin="$INSTALL_DIR/files/bin/wine"

if [ -x "$INSTALL_DIR/proton" ] && [ -n "$wine_bin" ]; then
  echo "PROTON_INSTALL_OK path=$INSTALL_DIR wine_bin=$wine_bin"
else
  echo "ERROR: Proton install verification failed (missing $INSTALL_DIR/proton or files/bin/wine[64])" >&2
  exit 1
fi
