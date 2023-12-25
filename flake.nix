{
  description = "example - description";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.rust = {
    url = "github:oxalica/rust-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };
  inputs.crane = {
    url = "github:ipetkov/crane";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
    inputs.rust-overlay.follows = "rust";
  };

  outputs = { self, nixpkgs, flake-utils, rust, crane }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ rust.overlays.default ];

        pkgs = import nixpkgs { inherit system overlays; };

        buildInputs = with pkgs; [
        ] ++ pkgs.lib.optionals (pkgs.stdenv.isDarwin) (with pkgs.darwin.apple_sdk.frameworks; [
        ]) ++ pkgs.lib.optionals (pkgs.stdenv.isLinux) (with pkgs; [
        ]);

        nativeBuildInputs = with pkgs; [
        ] ++ pkgs.lib.optionals (pkgs.stdenv.isLinux) [
        ] ++ pkgs.lib.optionals (pkgs.stdenv.isDarwin) [

        ];

        toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        # needed for nightly rustfmt options
        rustfmt-nightly = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.rustfmt);

        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        example = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./.);

          inherit buildInputs;
          inherit nativeBuildInputs;
        };
      in
      rec {
        checks = {
          inherit example;
        };

        packages.default = example;

        apps.default = flake-utils.lib.mkApp {
          drv = example;
        };


        devShell = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks.${system};
          nativeBuildInputs = [
            rustfmt-nightly
            (toolchain.override { extensions = [ "rust-src" "llvm-tools-preview" ]; })
          ];

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;
        };
      });
}
