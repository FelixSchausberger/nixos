# NixOS Tools Templates

This directory contains templates for creating new tools in the NixOS configuration.

## Available Templates

### Rust Tool Template (`rust/`)

For CLI tools, system utilities, and performance-critical applications.

### Nix Tool Template (`nix/`)

For configuration generators, deployment scripts, and Nix-specific utilities.

## Usage

### Creating a New Rust Tool

```bash
# Copy the template
cp -r tools/templates/rust tools/my-new-tool

# Update the tool
cd tools/my-new-tool
# Edit Cargo.toml - change name, version, dependencies
# Edit flake.nix - update package name and description
# Write your code in src/main.rs or src/bin/*.rs

# Test the tool
nix develop  # Enter development shell
cargo run    # Run during development
nix build    # Build with Nix
```

### Creating a New Nix Tool

```bash
# Copy the template
cp -r tools/templates/nix tools/my-nix-tool

# Update the tool
cd tools/my-nix-tool
# Edit flake.nix - change package name, description, dependencies
# Edit your Nix code in default.nix or src/

# Test the tool
nix build    # Build the tool
nix run      # Run the tool
```

### Integration with Main Flake

Add your new tool to the main flake's `packages` section:

```nix
# In /per/etc/nixos/flake.nix
packages = {
  # ... existing packages ...
  my-new-tool = pkgs.callPackage ./tools/my-new-tool {};
};
```

## Template Features

Both templates include:

- Flake-based configuration
- Development shells with all required tools
- Automatic formatting (treefmt)
- Pre-commit hooks support
- Consistent structure and conventions
- Documentation templates

## Guidelines

### When to Use Rust

- CLI tools with complex logic
- System utilities requiring performance
- Tools that need to interact with low-level APIs
- Network services and daemons

### When to Use Nix

- Configuration generators
- Deployment automation
- Package builders and wrappers
- System administration scripts
- Integration with Nix ecosystem

## Examples

Existing tools using these patterns:

- `tools/scripts/` - System operation scripts and utilities
