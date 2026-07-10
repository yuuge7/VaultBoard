#!/usr/bin/env bash
#
# Builds the Flutter Linux release bundle and packages it for the three big
# distro families plus a portable tarball:
#
#   dist/vaultboard_<version>_amd64.deb            Debian / Ubuntu / Mint
#   dist/vaultboard-<version>-1.x86_64.rpm         Fedora / RHEL / openSUSE
#   dist/vaultboard-<version>-1-x86_64.pkg.tar.zst Arch / Manjaro / EndeavourOS
#   dist/vaultboard-<version>-linux-x86_64.tar.gz  Portable (any distro)
#
# Requirements: flutter, fpm (https://fpm.readthedocs.io — `gem install fpm`),
# and for the .rpm target the `rpm` package (rpmbuild). `rsvg-convert`
# (librsvg) is optional and adds raster icons next to the SVG one.
#
# Usage: packaging/linux/build_packages.sh [version]
#        (version defaults to the one in pubspec.yaml)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

VERSION="${1:-$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)}"
DIST="$REPO_ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

command -v fpm >/dev/null 2>&1 || {
  echo "error: fpm not found. Install it with: gem install fpm" >&2
  exit 1
}

echo "==> Building VaultBoard $VERSION (Linux release bundle)"
flutter build linux --release

BUNDLE="build/linux/x64/release/bundle"
[ -d "$BUNDLE" ] || { echo "error: bundle not found at $BUNDLE" >&2; exit 1; }

echo "==> Staging filesystem tree"
mkdir -p \
  "$STAGE/usr/lib/vaultboard" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps" \
  "$STAGE/usr/share/metainfo"

cp -r "$BUNDLE"/. "$STAGE/usr/lib/vaultboard/"
ln -s ../lib/vaultboard/vaultboard "$STAGE/usr/bin/vaultboard"
install -m644 packaging/linux/vaultboard.desktop "$STAGE/usr/share/applications/"
install -m644 packaging/linux/vaultboard.svg \
  "$STAGE/usr/share/icons/hicolor/scalable/apps/"
install -m644 packaging/linux/vaultboard.metainfo.xml "$STAGE/usr/share/metainfo/"

if command -v rsvg-convert >/dev/null 2>&1; then
  echo "==> Rendering raster icons"
  for size in 64 128 256; do
    dir="$STAGE/usr/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$dir"
    rsvg-convert -w "$size" -h "$size" \
      packaging/linux/vaultboard.svg -o "$dir/vaultboard.png"
  done
fi

mkdir -p "$DIST"

common=(
  --input-type dir
  --chdir "$STAGE"
  --name vaultboard
  --version "$VERSION"
  --license MIT
  --url "https://github.com/yuuge7/VaultBoard"
  --maintainer "VaultBoard contributors"
  --description "Offline-first, local-only Kanban board for desktop"
  --force
)

echo "==> Building .deb (Debian/Ubuntu)"
fpm "${common[@]}" --output-type deb --architecture amd64 \
  --depends 'libgtk-3-0 | libgtk-3-0t64' \
  --package "$DIST/vaultboard_${VERSION}_amd64.deb" usr

echo "==> Building .rpm (Fedora)"
fpm "${common[@]}" --output-type rpm --architecture x86_64 \
  --depends gtk3 \
  --package "$DIST/vaultboard-${VERSION}-1.x86_64.rpm" usr

echo "==> Building .pkg.tar.zst (Arch)"
fpm "${common[@]}" --output-type pacman --architecture x86_64 \
  --depends gtk3 \
  --package "$DIST/vaultboard-${VERSION}-1-x86_64.pkg.tar.zst" usr

echo "==> Building portable tar.gz"
tar -C "$BUNDLE" -czf "$DIST/vaultboard-${VERSION}-linux-x86_64.tar.gz" .

echo "==> Done. Packages in $DIST:"
ls -lh "$DIST"
