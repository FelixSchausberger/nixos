{
  pkgs,
  inputs,
  ...
}: {
  config = {
    home.packages = with pkgs; [
      inputs.self.packages.${pkgs.system}.vigiland
    ];
  };
}
