# A template Rust project with fully functional and no-frills Nix support

> [!NOTE]  
> If you are looking for the original template based on
> [this blog post](https://srid.ca/rust-nix)'s use of `crate2nix`,
> browse from [this tag](https://github.com/srid/rust-nix-template/tree/crate2nix).
> The evolution of this template can be gleaned from [releases](https://github.com/srid/rust-nix-template/releases).

## Adapting this template

- Run `nix develop` to have a working shell ready before name change.
- Change `name` in Cargo.toml.
- Run `cargo generate-lockfile` in the nix shell

## Development (Flakes)

This repo uses [Flakes](https://nixos.wiki/wiki/Flakes) from the get-go.

```bash
# Dev shell
nix develop

# or run via cargo
nix develop -c cargo run

# build
nix build
```
