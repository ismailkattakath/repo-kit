# The repo-kit flake-parts module. `localFlake` is repo-kit's own flake (importApply), so the
# kit's inputs (treefmt-nix, files) come from the kit's lock, not the consumer's.
localFlake:
{
  config,
  lib,
  flake-parts-lib,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.repoKit;

  # The ONE Dependabot generator (also exported as `repo-kit.lib.dependabot`).
  mkDependabot = import ../lib/dependabot.nix { inherit lib; };

  licenseText =
    let
      raw = builtins.readFile (../licenses + "/${cfg.license.spdx}.txt");
    in
    if cfg.license.spdx == "MIT" then
      builtins.replaceStrings [ "<year>" "<copyright holders>" ] [ cfg.license.year cfg.license.holder ]
        raw
    else
      raw;

  # Community health files (ADR-016 § 3), for an owner's `.github` repository only: GitHub
  # serves them as defaults to every public repo of the owner without its own copy. ONE
  # text, two knobs (the owner, for absolute links; the CoC contact).
  community =
    let
      fill =
        builtins.replaceStrings
          [ "@OWNER@" "@CONTACT@" ]
          [ cfg.community.owner cfg.community.conductContact ];
      read = name: fill (builtins.readFile (../community + "/${name}"));
      # Contributor Covenant 3.0, vendored verbatim (EthicalSource/contributor_covenant @
      # 8d00b918, content/version/3/0/code_of_conduct.md, front matter removed): its two
      # placeholders are replaced here, so the vendored file stays diffable against upstream.
      reportingNote = "**[NOTE: describe your means of reporting here.]**";
      enforcementNote = "**[NOTE: The remedies and repairs outlined below are suggestions based on best practices in code of conduct enforcement. If your community has its own established enforcement process, be sure to edit this section to describe your own policies.]**\n\n";
      coc =
        builtins.replaceStrings
          [ reportingNote enforcementNote ]
          [
            "email the maintainer at <${cfg.community.conductContact}>. Only the maintainer reads these reports, and they are kept confidential."
            ""
          ]
          (builtins.readFile ../community/contributor-covenant-3.0.md);
    in
    assert lib.assertMsg (
      !lib.hasInfix "[NOTE:" coc
    ) "repo-kit: an upstream Contributor Covenant placeholder survived; update the replacements";
    {
      ".github/CODE_OF_CONDUCT.md".text = coc;
      ".github/CONTRIBUTING.md".text = read "CONTRIBUTING.md";
      ".github/SECURITY.md".text = read "SECURITY.md";
      ".github/SUPPORT.md".text = read "SUPPORT.md";
      ".github/pull_request_template.md".text = read "pull_request_template.md";
      ".github/ISSUE_TEMPLATE/config.yml".text = read "ISSUE_TEMPLATE/config.yml";
      ".github/ISSUE_TEMPLATE/bug_report.yml".text = read "ISSUE_TEMPLATE/bug_report.yml";
      ".github/ISSUE_TEMPLATE/feature_request.yml".text = read "ISSUE_TEMPLATE/feature_request.yml";
      ".github/ISSUE_TEMPLATE/question.yml".text = read "ISSUE_TEMPLATE/question.yml";
    };

  # The kit's .editorconfig baseline. Sections render sorted, so [*] comes first and
  # every narrower section after it (editorconfig: later sections win).
  editorconfigBaseline = {
    "*" = {
      charset = "utf-8";
      end_of_line = "lf";
      insert_final_newline = true;
      trim_trailing_whitespace = true;
      indent_style = "space";
      indent_size = 2;
    };
    "*.py".indent_size = 4;
    "Makefile".indent_style = "tab";
    "*.md".trim_trailing_whitespace = false;
  };

  # kattakath/nix-config ADR-015: the fleet's shared, public devcontainer image.
  devcontainer = {
    inherit (cfg) name;
    image = cfg.devcontainer.image;
    workspaceFolder = "/workspaces/${cfg.name}";
    workspaceMount = "source=\${localWorkspaceFolder},target=/workspaces/${cfg.name},type=bind";
    # `-C /`: git must not inspect the workspace first, or a git worktree (whose .git points at
    # a host path absent in the container) fails the command itself.
    postStartCommand = "git -C / config --global --add safe.directory \${containerWorkspaceFolder}";
    # Trust THIS workspace's .envrc once, at create (the image bakes direnv + nix-direnv and
    # no whitelist): a nested clone or any other .envrc still asks.
    postCreateCommand = "direnv allow \${containerWorkspaceFolder}";
    customizations.vscode = {
      extensions = cfg.devcontainer.extensions;
      settings = {
        # Plain bash: the image's direnv hook loads the devShell from .envrc (cached by
        # nix-direnv), the same environment the direnv extension gives tasks and tools.
        "terminal.integrated.defaultProfile.linux" = "bash";
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
      # `.github` is the one dotted name: an owner's community-defaults repository.
      type = types.strMatching ''\.github|[a-z0-9][a-z0-9._-]*'';
      description = "The repository name (kebab-case, or `.github`). The devcontainer workspace is /workspaces/<name>.";
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
    editorconfig = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Generate .editorconfig.";
      };
      # home-manager's editorconfig.settings shape (modules/misc/editorconfig.nix):
      # an INI attrset, `root = true` added on render. The kit's baseline is the
      # default of each key, so a consumer adds sections or overrides one key.
      settings = mkOption {
        # The value type pkgs.formats.ini builds; spelled out because a flake-level
        # option has no pkgs.
        type = types.attrsOf (
          types.attrsOf (
            types.oneOf [
              types.bool
              types.int
              types.str
            ]
          )
        );
        default = { };
        example = {
          "*.user.js".max_line_length = 100;
        };
        description = "Extra or overriding .editorconfig sections, merged over the kit's baseline.";
      };
    };
    community = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Generate the owner-wide community health files (CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, SUPPORT, issue forms, PR template) under .github/. Only for an owner's public `.github` repository: a local copy in any other repo shadows the owner default.";
      };
      owner = mkOption {
        type = types.strMatching "[A-Za-z0-9-]+";
        description = "The GitHub owner (user or org) whose `.github` repository this is; used for absolute links.";
      };
      conductContact = mkOption {
        type = types.str;
        description = "Where Code of Conduct reports go (an email address), published in CODE_OF_CONDUCT.md.";
      };
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
    dependabot = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Generate .github/dependabot.yml: the fleet's github-actions entry (weekly, one group, 7-day cooldown) plus repoKit.dependabot.updates. Opt-in, so a repo-kit bump never turns a consumer's drift check red; the template turns it on for new repos. Set the other dependabot options BEFORE `nix run .#write-files`, or the written file drops a repo's extra entries.";
      };
      githubActions = {
        directories = mkOption {
          type = types.listOf (types.strMatching "/.*");
          default = [ ];
          example = [ "/.github/actions/nix-setup" ];
          description = "Directories beyond `/` for the github-actions entry: each composite action with its own `uses:`. The `dependabot-directories` check fails when one under .github/actions or actions is missing.";
        };
        settings = mkOption {
          # A Dependabot entry is YAML-shaped data; spelled out because a flake-level option has no pkgs.
          type = types.attrsOf types.anything;
          default = { };
          example = {
            commit-message.prefix = "ci";
          };
          description = "Keys ADDED to the shared github-actions entry. Setting a shared key (package-ecosystem, directories, schedule, cooldown, groups) fails evaluation.";
        };
      };
      updates = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = [ ];
        example = [
          {
            package-ecosystem = "npm";
            directory = "/";
            schedule.interval = "monthly";
          }
        ];
        description = "More Dependabot update entries (other ecosystems), after the github-actions one. Each gets `cooldown.default-days = 7` unless it sets its own cooldown.";
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
        dependabot = mkDependabot {
          inherit pkgs;
          inherit (cfg.dependabot.githubActions) directories settings;
          inherit (cfg.dependabot) updates;
          src = self;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = pcfg.devPackages ++ [ config.files.writer.drv ];
          inherit (pcfg) shellHook;
        };

        checks =
          lib.optionalAttrs cfg.dependabot.enable {
            dependabot-schema = dependabot.schemaCheck;
            dependabot-directories = dependabot.directoriesCheck;
          }
          // lib.optionalAttrs (pcfg.requiredBins != [ ]) {
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
                # Generated by repo-kit (nix run .#write-files); change repoKit.editorconfig, not this file.
                ${lib.generators.toINIWithGlobalSection { mkKeyValue = lib.generators.mkKeyValueDefault { } " = "; }
                  {
                    globalSection.root = true;
                    sections = lib.recursiveUpdate editorconfigBaseline cfg.editorconfig.settings;
                  }
                }'';
            })
            (lib.mkIf cfg.community.enable community)
            (lib.mkIf cfg.devcontainer.enable {
              ".devcontainer/devcontainer.json".source =
                (pkgs.formats.json { }).generate "devcontainer.json"
                  devcontainer;
            })
            (lib.mkIf cfg.dependabot.enable { ".github/dependabot.yml".source = dependabot; })
          ];
        };
      };
  };
}
