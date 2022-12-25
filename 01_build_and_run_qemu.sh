#!/bin/bash

# set verbose level
__VERBOSE=6

declare -A LOG_LEVELS
# https://en.wikipedia.org/wiki/Syslog#Severity_level
#LOG_LEVELS=([0]="emerg" [1]="alert" [2]="crit" [3]="err" [4]="warning" [5]="notice" [6]="info" [7]="debug")
LOG_LEVELS=([emerg]=0 [alert]=1 [crit]=2 [err]=3 [warning]=4 [notice]=5 [info]=6 [debug]=7)
function log () {
  local LEVEL=${1}
  shift
  if [ ${__VERBOSE} -ge ${LOG_LEVELS[$LEVEL]} ]; then
    echo ${LEVEL} "$@"
  fi
}

packages_dependency() {
cat << 'EOF'
  Packages requirements:
  1. QEMU
     GCC at least 8, different distribution go with different packages.
     For example for SUSE running Santa Clara there are git-core, gcc-c++,
     glib2-devel, libpixman-1-0-devel.
     Details here https://wiki.qemu.org/Hosts/Linux
  2. linux-cxl: GCC
  3. run_qemu: mkosi, dracut, argbash

  Usually it requires the root privliges to install them.
EOF
}

usage() {
cat << EOF
Usage: ${0} -c <command>
	   all: build and run all
	   clone: clone all the repos
	   build_qemu: build qemu
	   config_linux: configure Linux kernel. run_qemu requires that
	   run_qemu: run qemu with cxl until linux prompt

EOF
	packages_dependency
	exit
}

test -d `pwd`/workdir || mkdir -p `pwd`/workdir
cd `pwd`/workdir
WORKDIR=`pwd`
#echo $WORKDIR
export_paths=()
export_pkg_config_path=()

# cxl repos
clone_repos() {
	log info ${FUNCNAME[0]}

	: <<- CMT
	# for fetching a toolchain
	git clone -b master https://github.com/u-boot/u-boot.git

	# install toolchain. Not really needed if the toolchain is already there.
	( cd u-boot; HOME=${WORKDIR}; ./tools/buildman/buildman --fetch-arch x86_64 )
	echo "toolchain is now in $WORKDIR/.buildman-toolchains/gcc-11.1.0-nolibc/x86_64-linux/bin"
	export PATH=$WORKDIR/.buildman-toolchains/gcc-11.1.0-nolibc/x86_64-linux/bin:$PATH
	fi
	CMT

	export https_proxy=http://proxy-us.intel.com:912
	# install mkosi
	python3 -m pip install git+https://github.com/systemd/mkosi.git -t $WORKDIR

	# install argbash
	git clone https://github.com/matejak/argbash
	(
	cd argbash/resources
	make install PREFIX=$WORKDIR
	)

	# install slirp
	# To install slirp we need meson and ninja, and pkg-config for libslirp.so
	# install meson first
	test -d $WORKDIR/bin || mkdir -p $WORKDIR/bin
	python3 -m pip install meson -t $WORKDIR/bin

	# It gets installed to bin and cannot find dependency later on. Work it around
	cp $WORKDIR/bin/bin/meson $WORKDIR/bin/meson

	# install ninja
	python3 -m pip install ninja -t $WORKDIR/bin

	export_paths+=("$WORKDIR/bin")
	PATH=$(IFS=:; echo "${export_paths[*]}"):$PATH
	export PATH

	meson --help
	git clone https://github.com/openSUSE/qemu-slirp.git
	(
	cd qemu-slirp
	#meson configure build
	meson setup -Dprefix=${WORKDIR}/slirp build/
	ninja -C build install
	)

	git clone -b master https://github.com/MarekBykowski/qemu.git
	git clone -b wip https://github.com/MarekBykowski/linux-cxl.git
	git clone -b santa_clara https://github.com/MarekBykowski/run_qemu.git
}

build_qemu() {
	log info ${FUNCNAME[0]}

	# qemu uses pkg-config to retrive info about the headers and libs
	# installed.
	#
	#    ( eg. for gmodule-2.0 from glib:
	#      prefix=/usr/intel/pkgs/glib/2.56.0, exec_prefix=${prefix},
	#      libdir=${exec_prefix}/lib, includedir=${prefix}/include,
	#      Libs: -L${libdir} -Wl,--export-dynamic -lgmodule-2.0 -pthread )
	#
	# As qemu requires glib 2.56, that is a 'non-standard' search path,
	# /usr/intel/pkgs/glib/2.56.0, let pkg-config know where it is with
	# PKG_CONFIG_PATH
	export_pkg_config_path+=("/usr/intel/pkgs/glib/2.56.0/lib/pkgconfig")

	# Also qemu needs slirp for networking
	export_pkg_config_path+=("$WORKDIR/slirp/lib64/pkgconfig")
	PKG_CONFIG_PATH=$(IFS=:; echo "${export_pkg_config_path[*]}")
	export PKG_CONFIG_PATH

	log debug export_pkg_config_path ${export_pkg_config_path[*]}
	log debug PKG_CONFIG_PATH $PKG_CONFIG_PATH

	exit 0
	(
	cd $WORKDIR/qemu
	test -d build || mkdir build
	cd build
	echo PKG_CONFIG_PATH $PKG_CONFIG_PATH
	../configure --target-list=x86_64-softmmu --cc=gcc --disable-werror --enable-slirp
	make -j4
	)
}

configure_linux-cxl() {
	log info ${FUNCNAME[0]}

	(
	cd $WORKDIR/linux-cxl
	ARCH=x86 make cxl_defconfig
	)
}

run_qemu() {
	log info ${FUNCNAME[0]}

	if [[ $1 == run ]]; then
		rebuild=none
	elif [[ $1 == build_run ]]; then
		rebuild=kmod
	else
		echo error rebuild for ${FUNCNAME[0]}
		exit
	fi

	test -d $WORKDIR/linux-cxl/qbuild/mkosi.extra/boot || mkdir -p $WORKDIR/linux-cxl/qbuild/mkosi.extra/boot
	# qemu requires initramfs with the version of a kernel. Go check it.
	pushd $WORKDIR/linux-cxl
	kver=$(make -s kernelrelease)
	popd
	ln -sf $WORKDIR/../initramfs-5.19.0-rc3+.img $WORKDIR/linux-cxl/qbuild/mkosi.extra/boot/initramfs-$kver.img
	ln -sf $WORKDIR/../{OVMF_VARS.fd,OVMF_CODE.fd} $WORKDIR/linux-cxl/qbuild
	ln -sf $WORKDIR/../root.img $WORKDIR/linux-cxl/qbuild

	(
	cd $WORKDIR/linux-cxl

	export_paths+=("$WORKDIR/bin")
	PATH=$(IFS=:; echo "${export_paths[*]}"):$PATH
	export PATH

	qemu_bin=$WORKDIR/qemu/build/qemu-system-x86_64
	qemu=${qemu_bin} ../run_qemu/run_qemu.sh --cxl --cxl-single --git-qemu \
		--cxl-debug -r ${rebuild}
	)
}


[[ $# -eq 2 || $1 =~ help ]] || usage

OPTIND=1 # reset to gett on safe side if it was modified in shell previously
while getopts ":c:" opt; do
  case $opt in
    c)
      arg=$OPTARG
      #echo "$0 -c $arg"
      ;;
    *)
      usage ;;
   esac
done

case $arg in
  all)
    clone_repos; build_qemu; configure_linux-cxl; run_qemu build_run ;;
  clone)
    clone_repos ;;
  build_qemu)
    build_qemu ;;
  config_linux)
    configure_linux-cxl ;;
  run_qemu)
    run_qemu build_run ;;
esac
