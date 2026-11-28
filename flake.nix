# repo-kit — one repository shape for the fleet (kattakath/nix-config ADR-016).
#
# A consumer imports `flakeModules.default` and gets, from ONE source:
#   - a devShell and a `toolchain-complete` check from one package list
#   - treefmt (`nix fmt`) and its formatting check
#   - generated per-repo files (LICENSE, .envrc, .editorconfig, devcontainer.json,
#     .github/dependabot.yml),
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
          # The same Dependabot generator the module uses, for a repo that renders its own
          # file without importing the module (kattakath/nix-config). See lib/dependabot.nix.
          lib.dependabot = import ./lib/dependabot.nix { inherit (inputs.nixpkgs) lib; };
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
          dependabot.enable = true;
        };

        perSystem =
          {
            pkgs,
            config,
            lib,
            ...
          }:
          let
            mk = args: self'.lib.dependabot ({ inherit pkgs; } // args);
            self' = inputs.self;
            # The lib path in nix-config's shape: a composite action, an added key, an ecosystem.
            nixConfigShape = mk {
              directories = [
                "/"
                "/.github/actions/nix-setup"
              ];
              settings.commit-message.prefix = "ci";
              updates = [
                {
                  package-ecosystem = "npm";
                  directory = "/";
                  schedule.interval = "monthly";
                }
              ];
              src = ./tests/dependabot-fixture;
            };
            unlisted = mk { src = ./tests/dependabot-fixture; };
            clash = builtins.tryEval (mk { settings.schedule.interval = "monthly"; }).config;
          in
          {
            # Both paths through the ONE generator: the module (this repo's own file, checked by
            # the module's dependabot-schema/-directories) and lib.dependabot, here.
            checks = {
              lib-dependabot-schema = nixConfigShape.schemaCheck;
              lib-dependabot-directories = nixConfigShape.directoriesCheck;
              lib-dependabot-cases =
                assert lib.assertMsg (
                  unlisted.missingDirectories == [ "/.github/actions/nix-setup" ]
                ) "lib.dependabot: an unlisted composite action with uses: was not reported";
                assert lib.assertMsg (!clash.success) "lib.dependabot: overriding a shared key evaluated";
                assert lib.assertMsg (
                  (builtins.elemAt nixConfigShape.config.updates 1).cooldown.default-days == 7
                ) "lib.dependabot: an added ecosystem lacks the 7-day cooldown";
                pkgs.runCommandLocal "lib-dependabot-cases" { } ''
                  # The module renders through the same function: same options, same bytes.
                  cmp ${config.files.file.".github/dependabot.yml".source} ${mk { src = self'; }}
                  echo "unlisted action reported; shared-key override rejected; cooldown added; module == lib" > "$out"
                '';
            };

            # `nix run github:ismailkattakath/repo-kit#init -- NAME YEAR HOLDER DESCRIPTION`:
            # copies the template into the current (empty) directory and fills its four
            # required fields. The ONE implementation of the fill: kattakath/.github's
            # new-repo.sh calls it, and this repo's CI instantiates the template with it.
            apps.init.program = pkgs.writeShellApplication {
              name = "repo-kit-init";
              runtimeInputs = [ pkgs.python3 ];
              text = ''
                [ $# -eq 4 ] || { echo "usage: init NAME YEAR HOLDER DESCRIPTION" >&2; exit 2; }
                [ -e flake.nix ] && { echo "error: ./flake.nix exists; run init in an empty repository" >&2; exit 1; }
                cp -R ${./template}/. .
                chmod -R u+w .
                python3 -I ${./scripts/fill-template.py} flake.nix "$@"
              '';
            };

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
