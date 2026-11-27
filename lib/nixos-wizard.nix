# nixos-wizard's postInstall references pkgs.nixfmt-classic, which nixpkgs
# removed. The wizard is consumed from its own flake, so a host-side alias
# cannot repair it; replace the wrapper with the tool set the wizard needs.
{
  pkgs,
  inputs,
}: let
  system = pkgs.stdenv.hostPlatform.system;
in
  inputs.nixos-wizard.packages.${system}.default.overrideAttrs (_old: {
    postInstall = ''
      wrapProgram $out/bin/nixos-wizard \
        --prefix PATH : ${pkgs.lib.makeBinPath [
        inputs.disko.packages.${system}.disko
        pkgs.bat
        pkgs.nixfmt
        pkgs.util-linux
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.ntfs3g
      ]}
    '';
  })
