#!/usr/bin/env bash

set -euo pipefail

source '/etc/os-release'
declare -ar PKGS=(meson ninja-build vala pkg-config)
if ! command -v vala; then
    case ${ID:?} in
        debian | ubuntu)
            sudo apt-get update
            sudo apt-get install -y "${PKGS[@]}" libcsv-dev
            ;;
        fedora | alma) sudo dnf install -y "${PKGS[@]}" libcsv-devel ;;
    esac 1>/dev/null
fi

shellcheck --external-sources "${0}"
shfmt -ci -fn -i 4 -d "${0}"

meson setup build
meson compile -C build
meson test -C build --print-errorlogs --verbose
DESTDIR="${PWD}/destdir" meson install -C build

declare -ar VAR=(
    --verbose
    --fatal-warnings
    --Xcc=-O3
    --cc=clang
    --vapidir=src
    --enable-{checking,mem-profiler,gobject-tracing}
    --pkg=libcsv
    -X -lcsv
)
vala "${VAR[@]}" 'examples/read_csv.vala' --run-args 'sample.csv'
