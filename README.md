## Intro

branches:
- `master`: main branch for the systems in which the user has sudo rights
- santa-clara: is for the HOST in which the (regular) users do not have the root rigths. It must have the artifcats copied before running the script
- docker-generic: for containers which are not ready to run dracut and mkosi but which have the sudo rights

Artifacts needed are in this repo packages link.

Pick `docker-generic` if unsure. 

## Artifacts

I have put together the sripts for publishing and installing the artifacts using the docker https://github.com/MarekBykowski/ghcr-publish-install-packages. 

Below are steps for cloning that repo with the help scripts and running them.

- copy the files from that repo
```
tmpdir=$(mktemp -d)
git clone --depth=1 --branch master \
   https://github.com/MarekBykowski/ghcr-publish-install-packages \
   "$tmpdir"
cp -a "$tmpdir"/Dockerfile-artifacts "$tmpdir"/publish-install.sh .
rm -rf "$tmpdir"
```

- run `publish-install.sh install`: It should download the artifacts to `artifacts-<rundom number>`.
- untar
```
tar -xJf artifacts-<rundom number>/artifacts.tar.xz
```

## Toolchain
```
git clone -b master https://github.com/u-boot/u-boot.git                
cd u-boot                                                               
./tools/buildman/buildman --fetch-arch list                             
./tools/buildman/buildman --fetch-arch <arch>                           
export PATH=$HOME/.buildman-toolchains/<gcc>/bin:$PATH                  
export ARCH=x86                                                         
export CROSS_COMPILE=i386-linux-                              
```

## Install dependencies/apt packages

```
sudo apt update; sudo apt-get install -y autoconf
```

## Run
```
./01_build_and_run_qemu.sh -c <command>
```

