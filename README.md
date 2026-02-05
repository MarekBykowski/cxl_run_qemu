## Intro

branches:
- `master`: main branch for the systems in which the user has sudo rights
- `docker-generic`: for system without sudo or for containers which are not designed to run `dracut` and `mkosi`. It must have the artifcats copied before running the script

Artifacts needed are in this repo packages link.

Pick `docker-generic` if unsure. 

## Artifacts

I have put together the sripts for publishing and installing the artifacts using the docker https://github.com/MarekBykowski/ghcr-publish-install-packages. 

Below are steps for cloning that repo with the scripts using Docker and running them.

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
sudo apt install -y ninja-build pkg-config libglib2.0-dev
sudo apt install -y libslirp-dev
sudo apt install -y flex bison libelf-dev
```

## Run
```
./01_build_and_run_qemu.sh -c <command>
```

## Newest QEMU requires Python 3.19
```
sudo apt install -y \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libncurses5-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  libffi-dev \
  liblzma-dev \
  wget

wget https://www.python.org/ftp/python/3.9.19/Python-3.9.19.tgz
tar -xf Python-3.9.19.tgz
cd Python-3.9.19
./configure --prefix=/opt/python3.9
make -j$(nproc)
sudo make install
```
