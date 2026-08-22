{
  pkgs,
  hosts,
}: let
  hostList = builtins.concatStringsSep "\n  - " hosts;
  example = builtins.head hosts;
in {
  type = "app";
  program = "${pkgs.writeShellScript "nixos-anywhere-helper" ''
    echo "Usage: nix run github:nix-community/nixos-anywhere -- --flake .#HOSTNAME root@IP"
    echo ""
    echo "Available hosts:"
    echo "  - ${hostList}"
    echo ""
    echo "Example:"
    echo "  nix run github:nix-community/nixos-anywhere -- \\"
    echo "    --flake .#${example} \\"
    echo "    root@192.168.1.100"
    echo ""
    echo "Note: Disk device is configured in hosts/HOSTNAME/disko/disko.nix"
    echo "      Default is /dev/sda - update if your system uses a different device"
    echo ""
    echo "For automated installation with sops key and repo cloning:"
    echo "  nix run .#install-remote ${example} 192.168.1.100"
  ''}";
  meta.description = "Helper for deploying NixOS hosts with nixos-anywhere";
}
