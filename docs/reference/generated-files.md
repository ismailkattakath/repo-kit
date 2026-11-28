# Generated files

Each file `repo-kit` generates, and the option that switches it. `nix run .#write-files`
writes them; `nix flake check` has one `files:<path>` drift check per file.

| File | Option | Content |
|---|---|---|
| `LICENSE` | `repoKit.license.spdx` (`MIT`, `CC-BY-4.0`, or `null`) | SPDX licence text |
| `.envrc` | `repoKit.envrc.enable` | `.envrc.local` (if present), then `use flake`, then `.env` |
| `.editorconfig` | `repoKit.editorconfig.enable`, `.settings` | one editor baseline; `settings` adds or overrides sections (home-manager's `editorconfig.settings` shape) |
| `.devcontainer/devcontainer.json` | `repoKit.devcontainer.enable` | the fleet's shared, public image (`:1`) |
| `.github/dependabot.yml` | `repoKit.dependabot.enable` (off by default; the template turns it on), `.githubActions.directories`, `.githubActions.settings`, `.updates` | the fleet's github-actions entry (weekly, one group, 7-day cooldown); see below |
| `.github/` community files | `repoKit.community.enable` (off by default; set `owner` and `conductContact`) | Code of Conduct (Contributor Covenant 3.0), CONTRIBUTING, SECURITY, SUPPORT, issue forms and `config.yml`, PR template |

Turn `community` on **only in an owner's public `.github` repository**. GitHub serves those
files as defaults to every public repository of that owner that has no copy of its own, so
one text covers the whole owner. A local copy anywhere else would shadow the default.

## Dependabot

GitHub reads only a repository's own `.github/dependabot.yml`; nothing is inherited from
the owner. So the fleet's entry is generated here, and a repository **adds** to it rather than
copying it.

### Opting in

The file is **opt-in**, so a repo-kit lock bump never turns an existing repository's drift
check red. A repository made from the template already has it on.

1. Bump `repo-kit` in `flake.lock`.
2. Set `repoKit.dependabot.enable = true;` and **every option your current file needs** (the
   table below). Do this **before** `write-files`: the written file holds only what the
   options say, so a hand-written npm entry or commit prefix that is not an option yet is lost.
3. `git add -A && nix run .#write-files`, then `nix flake check`.
4. Diff the new `.github/dependabot.yml` against the old one. Every difference should be one
   you meant, such as gaining the cooldown.

| Need | Option | Example |
|---|---|---|
| a composite action with its own `uses:` | `githubActions.directories` | `[ "/.github/actions/nix-setup" ]` |
| another key on the github-actions entry | `githubActions.settings` | `{ commit-message.prefix = "ci"; }` |
| another ecosystem | `updates` (each gets the 7-day cooldown unless it sets one) | `[ { package-ecosystem = "npm"; directory = "/"; schedule.interval = "monthly"; } ]` |

Three checks guard it:

- `githubActions.settings` cannot set a shared key (`package-ecosystem`, `directories`,
  `schedule`, `cooldown`, `groups`). Evaluation fails and names the key.
- `dependabot-directories` fails when a composite action with its own `uses:` (one level under
  `.github/actions/` or `actions/`) is not listed. Dependabot treats `/` as `.github/workflows`
  only, so an unlisted action's pins never move.
- `dependabot-schema` validates the file with `check-jsonschema --builtin-schema
  vendor.dependabot`. It also runs the same generator with one bad value and requires that
  copy to fail.

### Without the module: `lib.dependabot`

A repository that does not import the flakeModule renders the same file through the same
function, [`lib/dependabot.nix`](../../lib/dependabot.nix):

```nix
dependabot = inputs.repo-kit.lib.dependabot {
  inherit pkgs;                                  # rendering YAML needs remarshal
  directories = [ "/" "/.github/actions/nix-setup" ];  # "/" is always included
  settings = { };                                # keys added to the github-actions entry
  updates = [ ];                                 # more ecosystems
  src = self;                                    # optional: enables directoriesCheck
};
# the file: dependabot (a derivation)
# checks:   dependabot.schemaCheck, dependabot.directoriesCheck
```

The option definitions live in [`modules/kit.nix`](../../modules/kit.nix).
