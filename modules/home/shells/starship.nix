{
  lib,
  pkgs,
  hostConfig,
  inputs,
  ...
}: let
  ctp = inputs.self.lib.catppuccinColors.mocha;
in {
  programs.starship = {
    enable = true;

    settings = {
      format = "$hostname$directory$custom$battery$nix_shell$line_break$character";

      command_timeout = 500;

      directory = {
        style = "bold fg:${ctp.blue}";
        format = "[$path]($style) ";
        truncation_length = 2;
        truncation_symbol = "…/";
      };

      character = {
        success_symbol = "[❯](bold fg:${ctp.green})";
        error_symbol = "[❯](bold fg:${ctp.red})";
      };

      nix_shell = {
        format = "via [❄️ $state]($style) ";
        style = "bold fg:${ctp.yellow}";
      };

      battery = {
        disabled = false;
        format = "[$symbol$percentage]($style) ";
        full_symbol = "•";
        charging_symbol = "⚡";
        discharging_symbol = "";
        display = [
          {
            threshold = 20;
            style = "bold fg:${ctp.red}";
          }
        ];
      };

      custom = {
        vcs = {
          when = "${pkgs.jj-starship}/bin/jj-starship detect";
          command = ''
            if ${pkgs.jujutsu}/bin/jj root >/dev/null 2>&1; then
              ${pkgs.jj-starship}/bin/jj-starship \
                --jj-symbol "󱗆 " --git-symbol "" --truncate-name 15
            elif git rev-parse --git-dir >/dev/null 2>&1; then
              ${pkgs.jj-starship}/bin/jj-starship \
                --git-symbol " " --jj-symbol "" --truncate-name 15
            fi
          '';
          shell = ["bash"];
          format = "$output ";
          ignore_timeout = true;
        };

        health = lib.mkIf (!(hostConfig.isGui or false)) {
          when = ''
            curl -sf http://127.0.0.1:8080/score 2>/dev/null \
              | jq -e '.score < 75' > /dev/null 2>&1
          '';
          command = ''
            curl -sf http://127.0.0.1:8080/score 2>/dev/null \
              | jq -r '"❤️‍🩹 \(.score)%"' 2>/dev/null
          '';
          shell = ["bash"];
          style = "bold fg:${ctp.red}";
          format = "[$output]($style) ";
          ignore_timeout = true;
        };
      };
    };
  };
}
