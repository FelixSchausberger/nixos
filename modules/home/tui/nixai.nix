{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixai.homeManagerModules.default
  ];

  services.nixai = {
    enable = true;
    mcp = {
      enable = true;
      package = inputs.nixai.packages.${pkgs.system}.nixai;
      aiProvider = "claude";
    };
  };

  home.sessionVariables = {
    "CLAUDE_API_KEY" = config.sops.secrets."claude/default".path;
  };

  sops.secrets = {
    "claude/default" = {};
  };
}
