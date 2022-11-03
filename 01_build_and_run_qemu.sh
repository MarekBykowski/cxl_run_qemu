#!/bin/bash

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

# cxl repos
clone_repos() {
	: << CMT
	# for fetching a toolchain
	git clone -b master https://github.com/u-boot/u-boot.git

	# install toolchain. Not really needed if the toolchain is already there.
	( cd u-boot; HOME=${WORKDIR}; ./tools/buildman/buildman --fetch-arch x86_64 )
	echo "toolchain is now in $WORKDIR/.buildman-toolchains/gcc-11.1.0-nolibc/x86_64-linux/bin"
	export PATH=$WORKDIR/.buildman-toolchains/gcc-11.1.0-nolibc/x86_64-linux/bin:$PATH
	fi
CMT
	# install mkosi
	python3 -m pip install git+https://github.com/systemd/mkosi.git -t $WORKDIR

	#install argbash
	git clone https://github.com/matejak/argbash
	(
	cd argbash/resources
	make install PREFIX=$WORKDIR
	)

	git clone -b master https://github.com/MarekBykowski/qemu.git

	# On occasion it fails ONLY on santa clara due to large history.
	# Don't check out a single branch but shallow the whole history.
	if git clone --depth 1 https://github.com/MarekBykowski/linux-cxl.git; then
		(
		cd linux-cxl
		git checkout -b wip --track origin/wip
		#git fetch --unshallow
		#git fetch --depth 100
		)
	fi

	# finally clone run_qmu utility
	git clone -b cxl_6 https://github.com/MarekBykowski/run_qemu.git
}

build_qemu() {
	echo ${FUNCNAME[0]}
	cd $WORKDIR/qemu

	# qemu uses pkg-config to retrive info about the libs installed.
	#
	#    ( eg. for gmodule-2.0 from glib:
	#      prefix=/usr/intel/pkgs/glib/2.56.0, exec_prefix=${prefix},
	#      libdir=${exec_prefix}/lib, includedir=${prefix}/include,
	#      Libs: -L${libdir} -Wl,--export-dynamic -lgmodule-2.0 -pthread )
	#
	# As qemu requires glib 2.56, that is 'non-standard' search path,
	# /usr/intel/pkgs/glib/2.56.0, let pkg-config know where it is with
	# PKG_CONFIG_PATH
	export PKG_CONFIG_PATH=/usr/intel/pkgs/glib/2.56.0/lib/pkgconfig

	test -d build || mkdir build
	(
	cd build
	../configure --target-list=x86_64-softmmu --cc=gcc --disable-werror
	make -j4
	)
}

configure_linux-cxl() {
	echo ${FUNCNAME[0]}
	(
	cd $WORKDIR/linux-cxl
	ARCH=x86 make cxl_defconfig
	)
}

run_qemu() {
	echo ${FUNCNAME[0]}
	if [[ $1 == run ]]; then
		rebuild=none
	elif [[ $1 == build_run ]]; then
		rebuild=kmod
	else
		echo error rebuild for ${FUNCNAME[0]}
		exit
	fi

	set -x
	test -d $WORKDIR/linux-cxl/qbuild/mkosi.extra/boot || mkdir -p $WORKDIR/linux-cxl/qbuild/mkosi.extra/boot
	ln -s $WORKDIR/../initramfs-5.19.0-rc3+.img $WORKDIR/linux-cxl/qbuild/mkosi.extra/boot
	ln -s $WORKDIR/../{OVMF_VARS.fd,OVMF_CODE.fd} $WORKDIR/linux-cxl/qbuild
	ln -s $WORKDIR/../root.img $WORKDIR/linux-cxl/qbuild

	(
	cd $WORKDIR/linux-cxl

	export_paths+=("/nfs/site/disks/ive_gnr_pss_cxl_sw_interop/users/mbykowsx/cxl_run_qemu/workdir/bin")
	PATH=$(IFS=:; echo "${export_paths[*]}"):$PATH
	export PATH

	qemu_bin=$WORKDIR/qemu/build/qemu-system-x86_64
	qemu=${qemu_bin} ../run_qemu/run_qemu.sh --cxl --git-qemu \
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
