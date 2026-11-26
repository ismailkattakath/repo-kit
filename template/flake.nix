{
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
        name = "my-repo";
        license = {
          spdx = "MIT";
          year = "2026";
          holder = "Your Name";
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
