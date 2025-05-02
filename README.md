# Compulab imx8plus

build compulab imx8plus image with nix and docker ([bleh](https://pbs.twimg.com/media/DxcapsOVAAAFrYJ.jpg))

[Compulab Wiki iMX8M-Plus Linux Resources](https://mediawiki.compulab.com/w/index.php?title=UCM-iMX8M-Plus_NXP_iMX8M-Plus_Linux_Resources)

## set up nix shell
```bash
builder@nixos-builder ~/D/l/g/l/compulab_imx8plus (ljs/docker-build)> nix develop
iMX8M Plus Kernel Build Environment (Docker) Ready
Run 'build-imx8plus-image' to build the Docker image.
Run 'build-imx8plus-kernel <machine> [menuconfig]' to build the kernel.
Supported machines: ucm-imx8m-plus, ucm-imx8m-plus-sbev, mcm-imx8m-plus, iot-gate-imx8plus
Example: build-imx8plus-kernel ucm-imx8m-plus-sbev
```

## build docker image
```bash
[Nix Shell: imx8plus-docker] builder@nixos-builder:~/Documents/ljs/github/luisschubert/compulab_imx8plus$ build-imx8plus-image
[+] Building 309.3s (9/9) FINISHED                                                                                                  docker:default
 => [internal] load build definition from Dockerfile                                                                                          0.0s
 => => transferring dockerfile: 852B                                                                                                          0.0s
 => [internal] load metadata for docker.io/library/ubuntu:20.04                                                                               0.7s
 => [internal] load .dockerignore                                                                                                             0.0s
 => => transferring context: 2B                                                                                                               0.0s
 => CACHED [1/5] FROM docker.io/library/ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214                  0.0s
 => [2/5] RUN apt-get update && apt-get install -y   build-essential   git   wget   xz-utils   bc   bison   flex   libssl-dev   libncurses5  27.1s
 => [3/5] RUN wget -q https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-a  80.4s 
 => [4/5] RUN git clone -b linux-compulab_v6.6.23 https://github.com/compulab-yokneam/linux-compulab.git /linux-compulab                    195.9s 
 => [5/5] WORKDIR /linux-compulab                                                                                                             0.1s 
 => exporting to image                                                                                                                        4.8s 
 => => exporting layers                                                                                                                       4.7s 
 => => writing image sha256:c771fd3a257b3fb7b884979a5a851cebdd12567540f718144985a9dc7f61c138                                                  0.0s 
 => => naming to docker.io/library/imx8plus-kernel-builder:latest                                                                             0.0s

```

## run and build imx8plus image
```
[Nix Shell: imx8plus-docker] builder@nixos-builder:~/Documents/ljs/github/luisschubert/compulab_imx8plus$ build-imx8plus-kernel ucm-imx8m-plus-sbev
[+] Building 0.8s (9/9) FINISHED                                                                                                    docker:default
 => [internal] load build definition from Dockerfile                                                                                          0.0s
 => => transferring dockerfile: 852B                                                                                                          0.0s
 => [internal] load metadata for docker.io/library/ubuntu:20.04                                                                               0.6s
 => [internal] load .dockerignore                                                                                                             0.0s
 => => transferring context: 2B                                                                                                               0.0s
 => [1/5] FROM docker.io/library/ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214                         0.0s
 => CACHED [2/5] RUN apt-get update && apt-get install -y   build-essential   git   wget   xz-utils   bc   bison   flex   libssl-dev   libnc  0.0s
 => CACHED [3/5] RUN wget -q https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x8  0.0s
 => CACHED [4/5] RUN git clone -b linux-compulab_v6.6.23 https://github.com/compulab-yokneam/linux-compulab.git /linux-compulab               0.0s
 => CACHED [5/5] WORKDIR /linux-compulab                                                                                                      0.0s
 => exporting to image                                                                                                                        0.0s
 => => exporting layers                                                                                                                       0.0s
 => => writing image sha256:c771fd3a257b3fb7b884979a5a851cebdd12567540f718144985a9dc7f61c138                                                  0.0s
 => => naming to docker.io/library/imx8plus-kernel-builder:latest                                                                             0.0s

...

  OBJCOPY arch/arm64/boot/Image
  GZIP    arch/arm64/boot/Image.gz
Kernel build completed. Output is in /home/builder/Documents/ljs/github/luisschubert/compulab_imx8plus/output/
```

## Build Artifact
```bash
[Nix Shell: imx8plus-docker] builder@nixos-builder:~/Documents/ljs/github/luisschubert/compulab_imx8plus$ tree .
.
├── flake.lock
├── flake.nix
└── output
    ├── Image
```

### ls -ll  output/Image
```bash
-rw-r--r-- 1 root root 34816512 May  2 08:15 output/Image
```
### file output/Image
```bash 
output/Image: Linux kernel ARM64 boot executable Image, little-endian, 4K pages
```

