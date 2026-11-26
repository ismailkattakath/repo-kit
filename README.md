# repo-kit

[![ci: build status on main](https://github.com/ismailkattakath/repo-kit/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/ismailkattakath/repo-kit/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![built with Nix](https://img.shields.io/badge/built%20with-Nix-5277C3?logo=nixos&logoColor=white)](https://nixos.org)

One repository shape for a Nix fleet: a shared devShell, formatting and checks, plus generated files that cannot drift.

Instead of copying the same `flake.nix` into every repository and watching the copies drift,
each repository imports this kit as a flake input. An update is a lock bump, not a copy.

## Background

A fleet of repositories tends to grow the same `flake.nix` by hand: a system list, one package
list for the dev shell, a formatter, a check that the tools resolve. Copies drift: different
nixpkgs revisions, different formatters. `repo-kit` keeps that logic in one place and builds it
from established community parts:

- [flake-parts](https://github.com/hercules-ci/flake-parts), the module system;
- [treefmt-nix](https://github.com/numtide/treefmt-nix), for `nix fmt` and its check;
- [mightyiam/files](https://github.com/mightyiam/files), for generated files with a drift check each.

The design decision, with the alternatives that lost, is
[ADR-016](https://github.com/kattakath/nix-config/blob/main/docs/fleet-repo-shape-adr.md).

## Install

Start a new repository from the template:

```sh
nix flake init -t github:ismailkattakath/repo-kit
nix run .#write-files
```

Or add it to an existing flake-parts flake:

```nix
{
  inputs = {
    repo-kit.url = "github:ismailkattakath/repo-kit";
    nixpkgs.follows = "repo-kit/nixpkgs";
    flake-parts.follows = "repo-kit/flake-parts";
  };
  outputs = inputs@{ flake-parts, repo-kit, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ repo-kit.flakeModules.default ];
      repoKit.name = "my-repo";
      # ...
    };
}
```

Keep both `follows` lines: they are what gives the whole fleet one nixpkgs and one
flake-parts. The kit does not force its own nixpkgs on a consumer.

## Usage

| Command | What it does |
|---|---|
| `nix develop` | enter the dev shell built from `repoKit.devPackages` |
| `nix fmt` | format the repository (treefmt; nixfmt on by default) |
| `nix run .#write-files` | write every generated file to its path |
| `nix flake check` | `toolchain-complete`, `treefmt`, and one `files:<path>` check per generated file |

Generated files, each switched by an option:

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

Edit the options, never the generated files: `nix flake check` fails when a file differs
from what the kit generates.

## Contributing

Issues and pull requests are welcome. Run `nix flake check` before opening one.

## License

[MIT](LICENSE) © 2026 Ismail Kattakath
