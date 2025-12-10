{
  writeShellScriptBin,
  nix,
  jq,
  coreutils,
}:
writeShellScriptBin "repl" ''
  set -euo pipefail

  # Show help message
  if [[ "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
    cat <<EOF
  Usage: repl [PATH]

  Interactive Nix REPL with automatic flake detection and enhanced scope.

  Arguments:
    PATH    Optional path to a flake directory or flake.nix file
            If not provided, auto-detects system flake

  Auto-detection priority:
    1. /etc/nix/registry.json (system registry)
    2. /per/etc/nixos (fallback default)

  REPL Scope:
    - flake: The flake itself
    - inputs: All flake inputs
    - outputs: All flake outputs
    - nixosConfigurations: All NixOS configurations
    - packages: Packages for current system
    - pkgs: nixpkgs for current system
    - lib: nixpkgs.lib
    - host: Current host's NixOS configuration

  Examples:
    repl                    # Auto-load system flake
    repl .                  # Load flake from current directory
    repl /path/to/flake.nix # Load specific flake

  EOF
    exit 0
  fi

  # Detect flake path
  if [[ -n "''${1:-}" ]]; then
    # User provided a path
    FLAKE_PATH="$1"
    if [[ -d "$FLAKE_PATH" ]]; then
      # Directory provided, assume flake.nix inside
      FLAKE_PATH="$FLAKE_PATH"
    elif [[ -f "$FLAKE_PATH" ]]; then
      # File provided, use parent directory
      FLAKE_PATH="$(dirname "$FLAKE_PATH")"
    fi
  else
    # Auto-detect flake path
    if [[ -f /etc/nix/registry.json ]]; then
      # Try to get system flake from registry
      FLAKE_PATH=$(${jq}/bin/jq -r '.flakes[] | select(.from.id == "system") | .to.path // empty' /etc/nix/registry.json 2>/dev/null || echo "")
    fi

    # Fallback to default location
    if [[ -z "''${FLAKE_PATH:-}" ]]; then
      FLAKE_PATH="/per/etc/nixos"
    fi
  fi

  # Validate flake path exists
  if [[ ! -d "$FLAKE_PATH" ]]; then
    echo "Error: Flake directory not found: $FLAKE_PATH" >&2
    exit 1
  fi

  # Detect hostname
  CURRENT_HOSTNAME="$(${coreutils}/bin/cat /etc/hostname 2>/dev/null || echo "unknown")"

  # Detect system architecture
  SYSTEM="$(${nix}/bin/nix eval --impure --raw --expr 'builtins.currentSystem')"

  echo "Loading flake from: $FLAKE_PATH"
  echo "Hostname: $CURRENT_HOSTNAME"
  echo "System: $SYSTEM"
  echo ""

  # Launch REPL with enhanced scope
  ${nix}/bin/nix repl --expr "
    let
      flake = builtins.getFlake \"$FLAKE_PATH\";
      system = \"$SYSTEM\";
      currentHostname = \"$CURRENT_HOSTNAME\";
    in
    flake // {
      inherit flake system;
      hostname = currentHostname;
      inherit (flake) inputs outputs;
      inherit (flake.outputs) nixosConfigurations packages;
      pkgs = import flake.inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      lib = flake.inputs.nixpkgs.lib;
      host = if builtins.hasAttr currentHostname flake.outputs.nixosConfigurations
             then flake.outputs.nixosConfigurations.''${currentHostname}
             else null;
    }
  "
''
