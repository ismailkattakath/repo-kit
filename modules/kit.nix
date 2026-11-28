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

  # Dependabot (kattakath/nix-config's .github/dependabot.yml is the reference shape). GitHub
  # has no org-level or inherited dependabot.yml, so the one source is this generator.
  dependabot =
    let
      dcfg = cfg.dependabot;
      # The fleet's github-actions entry. A consumer ADDS to it (directories, other keys) but
      # cannot override these keys: that is how userscripts drifted to monthly/ungrouped.
      sharedActions = {
        package-ecosystem = "github-actions";
        directories = [ "/" ] ++ dcfg.githubActions.directories;
        schedule.interval = "weekly";
        # A supply-chain hold, not a convenience: a compromised release yanked within a week
        # never becomes a pinned SHA. 7 = the default-days zizmor's dependabot-cooldown wants.
        cooldown.default-days = 7;
        groups.github-actions.patterns = [ "*" ];
      };
      clash = lib.intersectLists (builtins.attrNames dcfg.githubActions.settings) (
        builtins.attrNames sharedActions
      );
      # zizmor's dependabot-cooldown checks every entry, so added ecosystems get the hold too.
      extra = map (u: lib.recursiveUpdate { cooldown.default-days = 7; } u) dcfg.updates;
    in
    assert lib.assertMsg (clash == [ ])
      "repo-kit: repoKit.dependabot.githubActions.settings may only ADD keys; it sets the shared ${lib.concatStringsSep ", " clash} (add directories through githubActions.directories)";
    {
      version = 2;
      updates = [ (sharedActions // dcfg.githubActions.settings) ] ++ extra;
    };

  # A composite action is its own manifest location to Dependabot: "/" covers only
  # .github/workflows, so an unlisted action.yml with its own `uses:` never gets a bump
  # (kattakath/nix-config measured 0 of 10 grouped bumps reaching one). Found here from the
  # repository's own source, one level under each root.
  compositeActionDirs =
    let
      src = "${self}";
      inRoot =
        root:
        let
          dir = "${src}/${root}";
          hasUses =
            name:
            lib.any
              (
                f:
                let
                  p = "${dir}/${name}/${f}";
                in
                builtins.pathExists p
                && lib.any (l: builtins.match "[[:space:]-]*uses:.*" l != null) (
                  lib.splitString "\n" (builtins.readFile p)
                )
              )
              [
                "action.yml"
                "action.yaml"
              ];
        in
        lib.optionals (builtins.pathExists dir) (
          map (n: "/${root}/${n}") (
            builtins.filter hasUses (
              builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir dir))
            )
          )
        );
    in
    lib.concatMap inRoot [
      ".github/actions"
      "actions"
    ];

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
        default = true;
        description = "Generate .github/dependabot.yml: the fleet's github-actions entry (weekly, one group, 7-day cooldown), plus repoKit.dependabot.updates.";
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
        yaml = pkgs.formats.yaml { };
        withHeader =
          name: value:
          pkgs.runCommandLocal name { } ''
            {
              echo "# Generated by repo-kit (nix run .#write-files); change repoKit.dependabot, not this file."
              echo "# github-actions: weekly, one grouped PR, a 7-day cooldown (a supply-chain hold), on /"
              echo "# plus each composite action with its own uses: (repoKit.dependabot.githubActions)."
              # remarshal opens with a `%YAML 1.1` directive; dropped so the header comment leads.
              grep -v '^%YAML' ${yaml.generate "${name}.body" value}
            } > "$out"
          '';
        dependabotFile = withHeader "dependabot.yml" dependabot;
        # Negative control: the same generator with ONE bad value must fail the same validator,
        # or a green schema check would prove nothing.
        dependabotBad = withHeader "dependabot-bad.yml" (
          dependabot
          // {
            updates = map (u: u // { schedule.interval = "fortnightly"; }) dependabot.updates;
          }
        );
        missingDirs = lib.subtractLists (builtins.head dependabot.updates).directories compositeActionDirs;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = pcfg.devPackages ++ [ config.files.writer.drv ];
          inherit (pcfg) shellHook;
        };

        checks =
          lib.optionalAttrs cfg.dependabot.enable {
            dependabot-schema =
              pkgs.runCommandLocal "dependabot-schema" { nativeBuildInputs = [ pkgs.check-jsonschema ]; }
                ''
                  check-jsonschema --builtin-schema vendor.dependabot ${dependabotFile}
                  if check-jsonschema --builtin-schema vendor.dependabot ${dependabotBad} >bad.log 2>&1; then
                    echo "negative control: a schedule.interval of 'fortnightly' passed the schema" >&2
                    exit 1
                  fi
                  grep -q fortnightly bad.log || { cat bad.log >&2; echo "negative control failed for another reason" >&2; exit 1; }
                  echo "dependabot.yml matches the schema; the negative control is rejected" > "$out"
                '';
            dependabot-directories = pkgs.runCommandLocal "dependabot-directories" { } (
              if missingDirs == [ ] then
                ''echo "every composite action with a uses: is listed (${toString (builtins.length compositeActionDirs)} found)" > "$out"''
              else
                ''
                  echo "composite actions with their own uses: missing from repoKit.dependabot.githubActions.directories: ${toString missingDirs}" >&2
                  exit 1
                ''
            );
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
            (lib.mkIf cfg.dependabot.enable { ".github/dependabot.yml".source = dependabotFile; })
          ];
        };
      };
  };
}
