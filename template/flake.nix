{
  # REQUIRED before first use: the `throw`s below and this description. Each throw
  # stops evaluation with its message, so a forgotten field can never generate (and
  # drift-check green) a LICENSE for a placeholder holder. kattakath/.github's
  # scripts/new-repo.sh fills every one of them.
  description = "One line: what this repository is";

  inputs = {
    repo-kit.url = "github:ismailkattakath/repo-kit";
    # One nixpkgs and one flake-parts for the whole fleet: follow the kit's.
    nixpkgs.follows = "repo-kit/nixpkgs";
    flake-parts.follows = "repo-kit/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, repo-kit, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ repo-kit.flakeModules.default ];

      repoKit = {
        name = throw "repo-kit template: set repoKit.name to the repository name (kebab-case)";
        license = {
          spdx = "MIT";
          year = throw "repo-kit template: set repoKit.license.year (the copyright year)";
          holder = throw "repo-kit template: set repoKit.license.holder (the copyright holder)";
        };
      };

      perSystem =
        { pkgs, ... }:
        {
          repoKit = {
            devPackages = [ pkgs.git ];
            requiredBins = [ "git" ];
          };
        };
    };
}
