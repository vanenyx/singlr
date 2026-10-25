#!/usr/bin/env bash
# Build singlr-desktop from the committed tree and publish it to the local pacman
# repository (.local/repo). Versions follow Arch's VCS convention
# <base>.r<commits>.g<hash>, so every build is newer than the previous one and
# `pacman -Syu` updates Singlr with the rest of the system. Never pushes anywhere.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
git diff --quiet HEAD || { echo "Hay cambios sin commit: el paquete se construye desde HEAD" >&2; exit 1; }
base=$(sed -n 's/^pkgver=//p' packaging/arch/PKGBUILD | head -1)
base=${base%%.r*}
version="$base.r$(git rev-list --count HEAD).g$(git rev-parse --short=7 HEAD)"
work=$(mktemp -d); trap 'rm -rf -- "$work"' EXIT
git archive --format=tar.gz --prefix="singlr-$version/" -o "$work/singlr-$version.tar.gz" HEAD
sed "s/^pkgver=.*/pkgver=$version/" packaging/arch/PKGBUILD > "$work/PKGBUILD"
(cd "$work" && makepkg -f --nodeps >makepkg.log 2>&1) || { tail -20 "$work/makepkg.log" >&2; exit 1; }
repo="$root/.local/repo"; mkdir -p "$repo"
cp "$work"/singlr-desktop-"$version"-*.pkg.tar.zst "$repo/"
repo-add -q -R "$repo/singlr.db.tar.gz" "$repo"/singlr-desktop-"$version"-*.pkg.tar.zst
echo "singlr-desktop $version → $repo"
