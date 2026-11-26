# repo-kit

[![ci: build status on main](https://github.com/ismailkattakath/repo-kit/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/ismailkattakath/repo-kit/actions/workflows/ci.yml)
[![template: a new repository from the template passes its checks](https://github.com/ismailkattakath/repo-kit/actions/workflows/template.yml/badge.svg?branch=main&event=push)](https://github.com/ismailkattakath/repo-kit/actions/workflows/template.yml)
[![license: from the repository's LICENSE file](https://img.shields.io/github/license/ismailkattakath/repo-kit)](LICENSE)
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

Start a new repository from the template, in an empty git repository:

```sh
nix run github:ismailkattakath/repo-kit#init -- my-repo 2026 "Your Name" "One line: what it is"
git add -A && nix run .#write-files
```

`init` copies the template (flake, `.gitignore`, the shared CI caller, Dependabot config)
and fills its four required fields. Each is a `throw` in the template, so a plain
`nix flake init -t github:ismailkattakath/repo-kit` fails until you set them by hand.
In the fleet, `kattakath/.github`'s `scripts/new-repo.sh` does all of this plus the
GitHub side.

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

Each generated file (`LICENSE`, `.envrc`, `.editorconfig`, the devcontainer and the
community files) is switched by its own option: see
[docs/reference/generated-files.md](docs/reference/generated-files.md).
Edit the options, never the generated files: `nix flake check` fails when a file differs
from what the kit generates.

## Contributing

Issues and pull requests are welcome. Run `nix flake check` before opening one.

## License

[MIT](LICENSE) © 2026 Ismail Kattakath
