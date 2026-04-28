{
  nixConfig = {
    extra-substituters = "https://cache.nixos.org https://hydra.nixos.org https://quaynor.cachix.org https://nix-community.cachix.org";
    extra-trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs= quaynor.cachix.org-1:VdcBFxLwfO1L23J973e4UolSnt3QlSZvT1E23+L+9WU= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    extra-experimental-features = "nix-command flakes";
  };
  description = "Quaynor - local LLM inference for Python, Flutter, and React Native";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
    crate2nix.url = "github:nix-community/crate2nix";
    crate2nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      android-nixpkgs,
      crate2nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (
          import nixpkgs {
            inherit system;
            config = {
              android_sdk.accept_license = true;
            };
          }
        );

        workspace = pkgs.callPackage ./quaynor/workspace.nix { inherit crate2nix; };

        # python stuff
        quaynor-python = pkgs.callPackage ./quaynor/python { inherit workspace; };

        # flutter stuff
        quaynor-flutter = workspace.workspaceMembers.quaynor-flutter.build;
        flutter_tests = pkgs.callPackage ./quaynor/flutter/quaynor {
          quaynor_flutter_rust = quaynor-flutter;
        };

        # cargo tests
        test-models = pkgs.callPackage ./quaynor/models.nix { };
        quaynor-tested = workspace.workspaceMembers.quaynor.build.override {
          runTests = true;
          testPreRun = ''
            export TEST_MODEL=${test-models.TEST_MODEL}
            export TEST_EMBEDDINGS_MODEL=${test-models.TEST_EMBEDDINGS_MODEL}
            export TEST_CROSSENCODER_MODEL=${test-models.TEST_CROSSENCODER_MODEL}
          '';
        };

      in
      {
        # default package
        packages.default = quaynor-python;

        # checks
        checks.default = flutter_tests;
        checks.flutter_tests = flutter_tests;

        checks.cargo-test = quaynor-tested;
        checks.quaynor-python = quaynor-python;

        checks.react-native-jest = pkgs.buildNpmPackage {
          pname = "react-native-jest";
          version = "0.0.0"; # nix derivation metadata only, does not need to match the npm package version
          src = ./quaynor/react-native;
          npmDepsHash = "sha256-aSDOiQJ4VIk01riMXmQefbTnIc6Z95BWL0STnfg3vkk=";
          dontNpmBuild = true;
          checkPhase = "npx jest";
          doCheck = true;
          installPhase = "touch $out";
        };

        # the Everything devshell
        devShells.default = pkgs.callPackage ./quaynor/shell.nix { inherit android-nixpkgs; };

        # flutter stuff
        packages.flutter_rust = quaynor-flutter;

        # python stuff
        packages.quaynor-python = quaynor-python;
        devShells.quaynor-python = pkgs.mkShell {
          # a devshell that includes the built python package
          # useful for testing local changes in repl or pytest
          packages = [
            (quaynor-python.override { doCheck = false; })
            pkgs.python3Packages.pytest
            pkgs.python3Packages.pytest-asyncio
          ];
        };

        devShells.android = pkgs.callPackage ./quaynor/android.nix { inherit android-nixpkgs; };
      }
    );
}
