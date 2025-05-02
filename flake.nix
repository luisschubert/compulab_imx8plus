{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Dockerfile for the kernel build environment
        dockerfile = pkgs.writeText "Dockerfile" ''
          FROM ubuntu:20.04
          ENV DEBIAN_FRONTEND=noninteractive
          RUN apt-get update && apt-get install -y \
            build-essential \
            git \
            wget \
            xz-utils \
            bc \
            bison \
            flex \
            libssl-dev \
            libncurses5-dev \
            && rm -rf /var/lib/apt/lists/*
          # Install Linaro toolchain
          RUN wget -q https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz -O /tmp/linaro.tar.xz \
            && tar -xf /tmp/linaro.tar.xz -C /opt \
            && rm /tmp/linaro.tar.xz
          ENV ARCH=arm64
          ENV CROSS_COMPILE=/opt/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
          # Clone the kernel source
          RUN git clone -b linux-compulab_v6.6.23 https://github.com/compulab-yokneam/linux-compulab.git /linux-compulab
          WORKDIR /linux-compulab
          CMD ["/bin/bash"]
        '';

        # Script to build the Docker image
        buildImageScript = pkgs.writeShellScriptBin "build-imx8plus-image" ''
          cp ${dockerfile} ./Dockerfile
          ${pkgs.docker}/bin/docker build -t imx8plus-kernel-builder:latest -f ./Dockerfile .
          rm -f ./Dockerfile
        '';

        # Script to build the kernel interactively
        buildKernelScript = pkgs.writeShellScriptBin "build-imx8plus-kernel" ''
          if [ $# -lt 1 ]; then
            echo "Usage: build-imx8plus-kernel <machine> [menuconfig]"
            echo "Supported machines: ucm-imx8m-plus, ucm-imx8m-plus-sbev, mcm-imx8m-plus, iot-gate-imx8plus"
            exit 1
          fi
          MACHINE=$1
          ${buildImageScript}/bin/build-imx8plus-image
          ${pkgs.docker}/bin/docker run -it --rm \
            -v $(pwd)/output:/output \
            imx8plus-kernel-builder:latest \
            /bin/bash -c "\
              export MACHINE=$MACHINE && \
              make compulab_v8_defconfig compulab.config && \
              [ \"\$1\" = 'menuconfig' ] && make menuconfig || true && \
              make -j$(nproc) tarbz2-pkg && \
              ls arch/arm64/boot/ && \
              ls && \
              cp *.tar.bz2 /output/ && \
              cp arch/arm64/boot/Image /output/ && \
              cp arch/arm64/boot/dts/freescale/*.dtb /output/ || true \
            "
          echo "Kernel build completed. Output is in $(pwd)/output/"
        '';

      in
      {
        packages = {
          buildImage = buildImageScript;
          buildKernel = buildKernelScript;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ docker buildImageScript buildKernelScript ];
          shellHook = ''
            echo "iMX8M Plus Kernel Build Environment (Docker) Ready"
            echo "Run 'build-imx8plus-image' to build the Docker image."
            echo "Run 'build-imx8plus-kernel <machine> [menuconfig]' to build the kernel."
            echo "Supported machines: ucm-imx8m-plus, ucm-imx8m-plus-sbev, mcm-imx8m-plus, iot-gate-imx8plus"
            echo "Example: build-imx8plus-kernel ucm-imx8m-plus-sbev"
            export PS1='\[\e[32m\][Nix Shell: imx8plus-docker]\[\e[0m\] \u@\h:\w\$ '
          '';
        };
      }
    );
}