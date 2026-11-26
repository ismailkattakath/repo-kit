# repo-kit — one repository shape for the fleet (kattakath/nix-config ADR-016).
#
# A consumer imports `flakeModules.default` and gets, from ONE source:
#   - a devShell and a `toolchain-complete` check from one package list
#   - treefmt (`nix fmt`) and its formatting check
#   - generated per-repo files (LICENSE, .envrc, .editorconfig, devcontainer.json),
#     each with a drift check, written by `nix run .#write-files`
#   - one nixpkgs, via `inputs.nixpkgs.follows = "repo-kit/nixpkgs"`
# This flake consumes its own module: its LICENSE, .envrc and friends are generated too.
{
  description = "One repository shape for a Nix fleet: shared devShell, formatting, checks and generated files with drift checks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Only its flake-parts module is imported, so its own flake inputs and nixConfig
    # (pipe-operators, abort-on-warn) never reach a consumer's lock. THIRD-PARTY: pinned to
    # a reviewed rev (ADR-016 § 4), bumped by PR, never moved by a bare `nix flake update`.
    files = {
      url = "github:mightyiam/files/3c14e6fc4450ffa0ea73ef1ac1613cdc7c5e9d50";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, ... }:
      let
        kit = flake-parts-lib.importApply ./modules/kit.nix { inherit inputs; };
      in
      {
        imports = [ kit ];

        flake = {
          flakeModules.default = kit;
          templates.default = {
            path = ./template;
            description = "A repository in the fleet's shape (repo-kit)";
          };
        };

        # Dogfood: the kit's own files come from the kit.
        repoKit = {
          name = "repo-kit";
          license = {
            spdx = "MIT";
            year = "2026";
            holder = "Ismail Kattakath";
          };
        };

        perSystem =
          { pkgs, ... }:
          {
            repoKit = {
              devPackages = [
                pkgs.git
                pkgs.gh
              ];
              requiredBins = [
                "git"
                "gh"
              ];
            };
          };
      }
    );
}
