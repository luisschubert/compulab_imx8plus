{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    linux-compulab = {
      url = "github:compulab-yokneam/linux-compulab/linux-compulab_v6.6.23";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, linux-compulab }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Linaro toolchain derivation
        linaro-toolchain-raw = pkgs.stdenv.mkDerivation {
          name = "linaro-toolchain-raw-9.2-2019.12";
          src = pkgs.fetchurl {
            url = "https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz";
            sha256 = "0rkaw1v66l9bpvp3i2flhnm1dik86c53rkskkkxh9ggh64anizld";
          };
          nativeBuildInputs = [ pkgs.xz ];
          installPhase = ''
            mkdir -p $out
            tar -xf $src -C $out --strip-components=1
          '';
          dontFixup = true;
        };

        # Wrap the toolchain in an FHS environment
        linaro-toolchain = pkgs.buildFHSEnv {
          name = "linaro-toolchain";
          targetPkgs = pkgs: [
            linaro-toolchain-raw
            pkgs.zlib # Required by gcc
            pkgs.glibc # Provides libc.so
            pkgs.gcc # Native gcc for HOSTCC
          ];
          multiPkgs = pkgs: [];
          runScript = "bash";
          extraOutputsToInstall = [ "out" ];
        };

        # Kernel build script
        buildKernelScript = pkgs.writeShellScriptBin "build-imx8plus-kernel" ''
          set -e  # Exit on any error

          # Set MACHINE outside the FHS command
          MACHINE="''${1:-ucm-imx8m-plus}"

          # Define the compiler path directly
          COMPILER=${linaro-toolchain-raw}/bin/aarch64-none-linux-gnu-gcc

          # Run the build inside the FHS environment
          ${linaro-toolchain}/bin/linaro-toolchain -c "
            export ARCH=arm64
            export CROSS_COMPILE=${linaro-toolchain-raw}/bin/aarch64-none-linux-gnu-
            export HOSTCC=/usr/bin/gcc  # Use native gcc for host tools

            # Verify the cross-compiler works
            if ! $COMPILER --version > /dev/null 2>&1; then
              echo 'Error: Cross-compiler not working inside FHS environment.'
              exit 1
            fi

            # Verify the host compiler works
            if ! \$HOSTCC --version > /dev/null 2>&1; then
              echo 'Error: Host compiler not working inside FHS environment.'
              exit 1
            fi

            # Use the linux-compulab source from the flake input
            SRC_DIR=${linux-compulab}
            BUILD_DIR=$(pwd)/linux-compulab-build

            # Copy the source to a writable directory
            if [ ! -d \$BUILD_DIR ]; then
              echo 'Copying kernel source to \$BUILD_DIR...'
              cp -r \$SRC_DIR \$BUILD_DIR
              chmod -R u+w \$BUILD_DIR
            fi

            cd \$BUILD_DIR

            # Use the MACHINE variable
            export MACHINE=\$MACHINE

            # Apply default config
            echo 'Applying default configuration for \$MACHINE...'
            make compulab_v8_defconfig compulab.config

            # Optional: Run menuconfig if requested
            if [ -n '\$2' ] && [ '\$2' = 'menuconfig' ]; then
              make menuconfig
            fi

            # Build the kernel
            echo 'Building kernel with $(nproc) jobs...'
            nice make -j$(nproc)

            echo 'Kernel build completed. Output is in \$BUILD_DIR/arch/arm64/boot/'
          "
        '';

        # Development shell with FHS-wrapped toolchain
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            gnumake
            ncurses # for menuconfig
            flex
            bison
            bc
            openssl
            binutils
            (buildFHSEnv {
              name = "linaro-toolchain-shell";
              targetPkgs = pkgs: [
                linaro-toolchain-raw
                pkgs.zlib
                pkgs.glibc
                pkgs.gcc # Native gcc for testing
              ];
              multiPkgs = pkgs: [];
              runScript = "bash";
            })
            buildKernelScript
          ];

          shellHook = ''
            echo "iMX8M Plus Kernel Build Environment Ready"
            echo "Supported machines: ucm-imx8m-plus, ucm-imx8m-plus-sbev, mcm-imx8m-plus, iot-gate-imx8plus"
            echo "Usage: build-imx8plus-kernel <machine> [menuconfig]"
            echo "Example: build-imx8plus-kernel ucm-imx8m-plus-sbev"
            echo "Example with menuconfig: build-imx8plus-kernel ucm-imx8m-plus-sbev menuconfig"
            echo "To test the compiler: linaro-toolchain-shell -c '${linaro-toolchain-raw}/bin/aarch64-none-linux-gnu-gcc --version'"
            export PS1='\[\e[32m\][Nix Shell: imx8plus-kernel]\[\e[0m\] \u@\h:\w\$ '
          '';
        };
      in
      {
        packages = {
          buildKernel = buildKernelScript;
        };

        devShells.default = devShell;
      }
    );
}