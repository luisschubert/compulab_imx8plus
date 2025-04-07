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

        # Linaro toolchain derivation
        linaro-toolchain = pkgs.stdenv.mkDerivation {
          name = "linaro-toolchain-9.2-2019.12";
          src = pkgs.fetchurl {
            url = "https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz";
            sha256 = "0rkaw1v66l9bpvp3i2flhnm1dik86c53rkskkkxh9ggh64anizld"; # Replace with actual SHA256
          };
          nativeBuildInputs = [ pkgs.xz ];
          installPhase = ''
            mkdir -p $out
            tar -xf $src -C $out --strip-components=1
          '';
          dontFixup = true;
        };

        # Kernel build script
        buildKernelScript = pkgs.writeShellScriptBin "build-imx8plus-kernel" ''
          # Set environment variables
          export ARCH=arm64
          export CROSS_COMPILE=${linaro-toolchain}/bin/aarch64-none-linux-gnu-

          # Check if source is already cloned, if not, clone it
          if [ ! -d "linux-compulab" ]; then
            git clone -b linux-compulab_v6.6.23 https://github.com/compulab-yokneam/linux-compulab.git
          fi

          cd linux-compulab

          # Set MACHINE if provided, default to ucm-imx8m-plus
          MACHINE=''${1:-ucm-imx8m-plus}
          export MACHINE

          # Apply default config
          make compulab_v8_defconfig compulab.config

          # Optional: Run menuconfig if requested
          if [ "$2" = "menuconfig" ]; then
            make menuconfig
          fi

          # Build the kernel
          nice make -j$(nproc)

          echo "Kernel build completed. Output is in $(pwd)/arch/arm64/boot/"
        '';

        # Development shell
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            gnumake
            ncurses # for menuconfig
            flex
            bison
            bc
            openssl
            linaro-toolchain
            buildKernelScript
          ];

          shellHook = ''
            echo "iMX8M Plus Kernel Build Environment Ready"
            echo "Supported machines: ucm-imx8m-plus, ucm-imx8m-plus-sbev, mcm-imx8m-plus, iot-gate-imx8plus"
            echo "Usage: build-imx8plus-kernel <machine> [menuconfig]"
            echo "Example: build-imx8plus-kernel ucm-imx8m-plus"
            echo "Example with menuconfig: build-imx8plus-kernel ucm-imx8m-plus menuconfig"
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