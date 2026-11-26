# @NAME@

@DESCRIPTION@

## Development

`nix develop` enters the dev shell (direnv loads it from `.envrc` automatically).
`nix flake check` runs every check, including the drift checks on the files repo-kit
generates (`nix run .#write-files` rewrites them).

## License

See [LICENSE](LICENSE).
