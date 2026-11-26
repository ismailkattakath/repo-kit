# Generated files

Each file `repo-kit` generates, and the option that switches it. `nix run .#write-files`
writes them; `nix flake check` has one `files:<path>` drift check per file.

| File | Option | Content |
|---|---|---|
| `LICENSE` | `repoKit.license.spdx` (`MIT`, `CC-BY-4.0`, or `null`) | SPDX licence text |
| `.envrc` | `repoKit.envrc.enable` | `.envrc.local` (if present), then `use flake`, then `.env` |
| `.editorconfig` | `repoKit.editorconfig.enable`, `.settings` | one editor baseline; `settings` adds or overrides sections (home-manager's `editorconfig.settings` shape) |
| `.devcontainer/devcontainer.json` | `repoKit.devcontainer.enable` | the fleet's shared, public image (`:1`) |
| `.github/` community files | `repoKit.community.enable` (off by default; set `owner` and `conductContact`) | Code of Conduct (Contributor Covenant 3.0), CONTRIBUTING, SECURITY, SUPPORT, issue forms and `config.yml`, PR template |

Turn `community` on **only in an owner's public `.github` repository**. GitHub serves those
files as defaults to every public repository of that owner that has no copy of its own, so
one text covers the whole owner. A local copy anywhere else would shadow the default.

The option definitions live in [`modules/kit.nix`](../../modules/kit.nix).
