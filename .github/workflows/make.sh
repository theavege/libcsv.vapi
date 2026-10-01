#!/usr/bin/env bash

set -euo pipefail
source '/etc/os-release'
declare -ar PKGS=(shellcheck shfmt)
if ! command -v vala; then
    case ${ID:?} in
        debian | ubuntu)
            sudo apt-get update
            sudo apt-get install -y "${PKGS[@]}" valac libcsv-dev
            ;;
        fedora | alma) sudo dnf install -y "${PKGS[@]}" vala libcsv-devel ;;
    esac 1>/dev/null
fi

shellcheck --external-sources "${0}"
shfmt -ci -fn -i 4 -d "${0}"

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

vala "${VAR[@]}" 'tests/simple.vala'
vala "${VAR[@]}" 'examples/simple.vala' --run-args 'sample.csv'
