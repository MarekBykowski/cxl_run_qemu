#!/bin/bash

packages_dependency() {
cat << 'EOF'
  Packages requirements:
  1. QEMU
     QEMU requires:
     - GCC at least 8
     - eg. for SUSE running Santa Clara: git-core gcc-c++ make qemu glib2-devel libpixman-1-0-devel
     Details on packages here https://wiki.qemu.org/Hosts/Linux.
  2. linux-cxl
     linux-cxl requires GCC
  3. run_qemu
     run_qemu requires mkosi, dracut, argbash

  Usually it requires the root privliges to install them.
EOF
}

usage() {
	cat << EOF
Usage: ${0} -c <command>:
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

# cxl repos
clone_repos() {
	# for fetching a toolchain
	# git clone -b master https://github.com/u-boot/u-boot.git
	# get toolchain. Not really needed if the toolchain is already there.
	#( cd u-boot; HOME=${WORKDIR}; ./tools/buildman/buildman --fetch-arch x86_64 )
	# toolchain is now in $WORKDIR/.buildman-toolchains/gcc-11.1.0-nolibc/x86_64-linux/bin:$PATH
	git clone -b master https://github.com/MarekBykowski/qemu.git
	git clone -b wip https://github.com/MarekBykowski/linux-cxl.git
	git clone -b cxl_6 https://github.com/MarekBykowski/run_qemu.git
}

build_qemu() {
	echo ${FUNCNAME[0]}
	cd $WORKDIR/qemu
	test -d build || mkdir build
	(
	cd build
	../configure --target-list=x86_64-softmmu
	make -j8
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
		rebuild=img
	else
		echo error rebuild for ${FUNCNAME[0]}
		exit
	fi
	(
	cd $WORKDIR/linux-cxl
	qemu_bin=$WORKDIR/qemu/build/qemu-system-x86_64
	qemu=${qemu_bin} ../run_qemu/run_qemu.sh --cxl --git-qemu \
		-r ${rebuild} --cxl-debug
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
