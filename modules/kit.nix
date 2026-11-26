# The repo-kit flake-parts module. `localFlake` is repo-kit's own flake (importApply), so the
# kit's inputs (treefmt-nix, files) come from the kit's lock, not the consumer's.
localFlake:
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.repoKit;

  licenseText =
    let
      raw = builtins.readFile (../licenses + "/${cfg.license.spdx}.txt");
    in
    if cfg.license.spdx == "MIT" then
      builtins.replaceStrings [ "<year>" "<copyright holders>" ] [ cfg.license.year cfg.license.holder ]
        raw
    else
      raw;

  # kattakath/nix-config ADR-015: the fleet's shared, public devcontainer image.
  devcontainer = {
    inherit (cfg) name;
    image = cfg.devcontainer.image;
    workspaceFolder = "/workspaces/${cfg.name}";
    workspaceMount = "source=\${localWorkspaceFolder},target=/workspaces/${cfg.name},type=bind";
    # `-C /`: git must not inspect the workspace first, or a git worktree (whose .git points at
    # a host path absent in the container) fails the command itself.
    postStartCommand = "git -C / config --global --add safe.directory \${containerWorkspaceFolder}";
    customizations.vscode = {
      extensions = cfg.devcontainer.extensions;
      settings = {
        "terminal.integrated.defaultProfile.linux" = "nix develop";
        "terminal.integrated.profiles.linux" = {
          bash.path = "bash";
          "nix develop" = {
            path = "bash";
            args = [
              "-lc"
              "exec nix develop"
            ];
            icon = "beaker";
          };
          claude = {
            path = "bash";
            args = [
              "-lc"
              "exec nix develop github:kattakath/nix-config#fleet -c claude"
            ];
            icon = "claude";
          };
        };
      };
    };
  };
in
{
  imports = [
    localFlake.inputs.treefmt-nix.flakeModule
    (localFlake.inputs.files + "/flake-module.nix")
  ];

  options.repoKit = {
    name = mkOption {
      type = types.strMatching "[a-z0-9][a-z0-9._-]*";
      description = "The repository name (kebab-case). The devcontainer workspace is /workspaces/<name>.";
    };
    license = {
      spdx = mkOption {
        type = types.nullOr (
          types.enum [
            "MIT"
            "CC-BY-4.0"
          ]
        );
        default = "MIT";
        description = "SPDX id of the generated LICENSE (MIT for code, CC-BY-4.0 for content), or null for none.";
      };
      year = mkOption {
        type = types.str;
        description = "Copyright year for MIT.";
      };
      holder = mkOption {
        type = types.str;
        description = "Copyright holder for MIT.";
      };
    };
    envrc.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Generate .envrc (.envrc.local first when present, then `use flake`, then .env).";
    };
    editorconfig.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Generate .editorconfig.";
    };
    devcontainer = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Generate .devcontainer/devcontainer.json for the fleet's shared image.";
      };
      image = mkOption {
        type = types.str;
        default = "ghcr.io/kattakath/devcontainer:1";
        description = "The devcontainer image; consumers pin the major tag.";
      };
      extensions = mkOption {
        type = types.listOf types.str;
        default = [ "anthropic.claude-code" ];
        description = "VS Code extensions installed in the devcontainer.";
      };
    };
  };

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.repoKit = {
        devPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "ONE list: the devShell's packages, and what `toolchain-complete` builds against.";
        };
        requiredBins = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Binaries the repo shells out to; `toolchain-complete` fails if the devShell lacks one.";
        };
        shellHook = mkOption {
          type = types.lines;
          default = "";
          description = "Run on entering the devShell (e.g. a hint when a required environment variable is unset).";
        };
      };
    }
  );

  config = {
    systems = lib.mkDefault [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];

    perSystem =
      { config, pkgs, ... }:
      let
        pcfg = config.repoKit;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = pcfg.devPackages ++ [ config.files.writer.drv ];
          inherit (pcfg) shellHook;
        };

        checks = lib.optionalAttrs (pcfg.requiredBins != [ ]) {
          toolchain-complete =
            pkgs.runCommandLocal "toolchain-complete" { nativeBuildInputs = pcfg.devPackages; }
              ''
                missing=""
                for bin in ${lib.escapeShellArgs pcfg.requiredBins}; do
                  command -v "$bin" >/dev/null 2>&1 || missing="$missing $bin"
                done
                if [ -n "$missing" ]; then
                  echo "devShell is missing:$missing" >&2
                  exit 1
                fi
                echo "all ${toString (builtins.length pcfg.requiredBins)} required binaries resolve" > "$out"
              '';
        };

        treefmt = {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = lib.mkDefault true;
          # Generated files belong to their `files:` drift checks; a formatter rewriting one
          # would fight them.
          settings.global.excludes = builtins.attrNames config.files.file;
        };

        files = {
          writer.app = true;
          file = lib.mkMerge [
            (lib.mkIf (cfg.license.spdx != null) { "LICENSE".text = licenseText; })
            (lib.mkIf cfg.envrc.enable {
              ".envrc".text = ''
                # Generated by repo-kit (nix run .#write-files); change the repoKit options, not this file.
                # .envrc.local first, so its variables exist when the devShell's shellHook runs.
                source_env_if_exists .envrc.local
                use flake
                dotenv_if_exists .env
              '';
            })
            (lib.mkIf cfg.editorconfig.enable {
              ".editorconfig".text = ''
                # Generated by repo-kit (nix run .#write-files); change the repoKit options, not this file.
                root = true

                [*]
                charset = utf-8
                end_of_line = lf
                insert_final_newline = true
                trim_trailing_whitespace = true
                indent_style = space
                indent_size = 2

                [*.py]
                indent_size = 4

                [Makefile]
                indent_style = tab

                [*.md]
                trim_trailing_whitespace = false
              '';
            })
            (lib.mkIf cfg.devcontainer.enable {
              ".devcontainer/devcontainer.json".source =
                (pkgs.formats.json { }).generate "devcontainer.json"
                  devcontainer;
            })
          ];
        };
      };
  };
}
