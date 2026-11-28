# Generated files

Each file `repo-kit` generates, and the option that switches it. `nix run .#write-files`
writes them; `nix flake check` has one `files:<path>` drift check per file.

| File | Option | Content |
|---|---|---|
| `LICENSE` | `repoKit.license.spdx` (`MIT`, `CC-BY-4.0`, or `null`) | SPDX licence text |
| `.envrc` | `repoKit.envrc.enable` | `.envrc.local` (if present), then `use flake`, then `.env` |
| `.editorconfig` | `repoKit.editorconfig.enable`, `.settings` | one editor baseline; `settings` adds or overrides sections (home-manager's `editorconfig.settings` shape) |
| `.devcontainer/devcontainer.json` | `repoKit.devcontainer.enable` | the fleet's shared, public image (`:1`) |
| `.github/dependabot.yml` | `repoKit.dependabot.enable`, `.githubActions.directories`, `.githubActions.settings`, `.updates` | the fleet's github-actions entry (weekly, one group, 7-day cooldown); see below |
| `.github/` community files | `repoKit.community.enable` (off by default; set `owner` and `conductContact`) | Code of Conduct (Contributor Covenant 3.0), CONTRIBUTING, SECURITY, SUPPORT, issue forms and `config.yml`, PR template |

Turn `community` on **only in an owner's public `.github` repository**. GitHub serves those
files as defaults to every public repository of that owner that has no copy of its own, so
one text covers the whole owner. A local copy anywhere else would shadow the default.

## Dependabot

GitHub reads only a repository's own `.github/dependabot.yml`; nothing is inherited from
the owner. So the fleet's entry is generated here, and a repository **adds** to it rather than
copying it:

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

The option definitions live in [`modules/kit.nix`](../../modules/kit.nix).
