# Contributing

Thank you for helping. One person maintains these repositories, so a small, focused change is
the fastest one to land.

## Before you start

- **Small fixes** (a typo, a broken link, an obvious bug): open a pull request directly.
- **Anything larger**: open an issue first, so we can agree on the approach before you spend
  time on it.
- **Security problems**: never in a public issue. Follow [SECURITY.md](SECURITY.md).

## Making a change

1. Fork the repository and branch from the default branch.
2. Keep one logical change per pull request.
3. Run the repository's checks before you push. In a repository with a `flake.nix`, that is
   `nix flake check`; `nix develop` gives you every tool it needs. Otherwise the README says
   how to test.
4. Update the documentation when behaviour changes.
5. Open the pull request and fill in the template.

CI runs on every pull request, and a pull request merges only when it is green.

## Licensing

By contributing, you agree that your contribution is licensed under the repository's licence
(its `LICENSE` file).

## Conduct

Everyone taking part agrees to the [Code of Conduct](CODE_OF_CONDUCT.md).
