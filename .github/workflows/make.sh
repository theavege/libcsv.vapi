#!/usr/bin/env bash

set -euo pipefail

source '/etc/os-release'
case ${ID:?} in
    debian | ubuntu) sudo bash -c '
        apt-get update
        apt-get install -y meson ninja-build valac pkg-config libcsv-dev
    ' ;;
    fedora | alma) sudo dnf install -y meson ninja-build vala pkg-config libcsv-devel ;;
esac 1>/dev/null

meson setup build
meson compile -C build --warnlevel 2
meson test -C build --print-errorlogs --verbose
DESTDIR="${PWD}/destdir" meson install -C build