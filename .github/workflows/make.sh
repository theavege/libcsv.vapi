#!/usr/bin/env bash
set -euo pipefail

cmd=${1:-all}

run_root() {
	if [[ "$(id -u)" -eq 0 ]] || ! command -v sudo >/dev/null 2>&1; then
		"$@"
	else
		sudo "$@"
	fi
}

setup_linux() {
	if [[ ! -f /etc/os-release ]]; then
		return 0
	fi
	# shellcheck disable=SC1091
	source /etc/os-release
	case ${ID:?} in
		debian | ubuntu)
			run_root apt-get update
			run_root apt-get install -y meson ninja-build valac pkg-config libcsv-dev gcc
			;;
		fedora | almalinux | centos | rhel)
			run_root dnf install -y meson ninja-build vala pkgconfig libcsv-devel gcc
			;;
		*)
			echo "Unknown distro ${ID}; assuming Vala and libcsv are already installed" >&2
			;;
	esac
}

build_libcsv_from_source() {
	if echo '#include <csv.h>' | "${CC:-cc}" -x c -E - >/dev/null 2>&1; then
		return 0
	fi

	echo "csv.h not found; building rgamble/libcsv from source"
	local src
	src=$(mktemp -d)
	git clone --depth 1 https://github.com/rgamble/libcsv.git "${src}/libcsv"
	(
		cd "${src}/libcsv"
		if [[ -x ./configure ]]; then
			./configure --prefix="${PREFIX:-/usr/local}"
			make
			run_root make install
		else
			"${CC:-cc}" -fPIC -shared -o libcsv.so libcsv.c
			run_root install -d "${PREFIX:-/usr/local}/include" "${PREFIX:-/usr/local}/lib"
			run_root install -m644 csv.h "${PREFIX:-/usr/local}/include/"
			run_root install -m755 libcsv.so "${PREFIX:-/usr/local}/lib/"
		fi
	)
	if command -v ldconfig >/dev/null 2>&1; then
		run_root ldconfig || true
	fi
}

configure() {
	meson setup build --warnlevel 2
}

compile() {
	meson compile -C build
}

check() {
	meson test -C build --print-errorlogs --verbose
}

install_local() {
	DESTDIR="${PWD}/destdir" meson install -C build
}

case ${cmd} in
	setup)
		setup_linux
		build_libcsv_from_source
		;;
	build)
		[[ -d build ]] || configure
		compile
		check
		install_local
		;;
	all)
		setup_linux
		build_libcsv_from_source
		configure
		compile
		check
		install_local
		;;
	*)
		echo "usage: $0 {setup|build|all}" >&2
		exit 1
		;;
esac
