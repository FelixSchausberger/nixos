{
  lib,
  pkgs,
  hostConfig,
  inputs,
  ...
}: let
  catppuccin = inputs.self.lib.catppuccinColors.mocha;

  # Segment background colors
  bgVcs = catppuccin.sapphire;
  bgLang = catppuccin.surface2;
  bgTime = catppuccin.surface0;
  # Separator styles (not used)
in {
  programs.bash = {
    enable = true;

    bashrcExtra = ''
      if ! emergency-mode-check >/dev/null 2>&1; then
        if [[ $- == *i* ]] && [[ "$TERM" != "dumb" ]]; then
          if command -v starship >/dev/null 2>&1; then
            if starship --help >/dev/null 2>&1; then
              eval "$(starship init bash)"
            else
              echo "starship found but not working properly - using fallback prompt" >&2
              PS1='\u@\h:\w\$ '
            fi
          else
            echo "starship not found - using fallback prompt" >&2
            PS1='\u@\h:\w\$ '
          fi
        fi
      else
        echo "Emergency mode active - starship disabled" >&2
        PS1='[EMERGENCY] \u@\h:\w\$ '
      fi
    '';
  };

  programs.starship = {
    enable = true;

    settings = {
      # https://starship.rs/config/#prompt
      format = "$username in $hostname in $directory via $nix_shell $custom$line_break$character";
      command_timeout = 3000;

      # Nix shell indicator
      nix_shell = {
        format = "[❄️ $state( \\($name\\))]($style) ";
        style = "bold yellow";
      };

      # Username segment (see simplified username below)

      # Directory segment is defined later with simplified settings

      # Time display
      time = {
        disabled = false;
        time_format = "%R";
        style = "fg:${catppuccin.subtext0} bg:${bgTime}";
        format = "[ 󰥔 $time ]($style)";
      };

      # Prompt symbol (customized below)

      # Language modules with shared segment background
      nodejs = {
        symbol = "";
        style = "fg:${catppuccin.yellow} bg:${bgLang}";
        format = "[ $symbol ($version) ]($style)";
      };
      rust = {
        symbol = "";
        style = "fg:${catppuccin.yellow} bg:${bgLang}";
        format = "[ $symbol ($version) ]($style)";
      };
      golang = {
        symbol = "";
        style = "fg:${catppuccin.yellow} bg:${bgLang}";
        format = "[ $symbol ($version) ]($style)";
      };
      python = {
        symbol = "";
        style = "fg:${catppuccin.pink} bg:${bgLang}";
        format = "[ $symbol ($version) ]($style)";
      };

      cmd_duration = {
        min_time = 500;
        style = "bold dimmed fg:${catppuccin.overlay0}";
        format = "[⏱ $duration]($style) ";
        show_milliseconds = true;
      };

      hostname = {
        disabled = false;
        format = "[🌐 $hostname](bold dimmed)";
        ssh_only = false;
      };

      directory = {
        style = "bold cyan";
        format = "[$path]($style)";
        truncation_length = 1;
        truncation_symbol = "…/";
      };

      character = {
        success_symbol = "[❯](bold green)";
      };

      custom = {
        # Unified VCS status - dispatches to jj-starship or git modules
        vcs_status = {
          when = true;
          command = ''
            if ${pkgs.jj-starship}/bin/jj-starship detect >/dev/null 2>&1; then
              ${pkgs.jj-starship}/bin/jj-starship prompt
            else
              if git rev-parse --git-dir >/dev/null 2>&1; then
                starship module git_branch 2>/dev/null
                starship module git_status 2>/dev/null
              fi
            fi
          '';
          shell = ["bash"];
          ignore_timeout = true;
          description = "Show VCS status (jj or git)";
          format = "[ $output ](bg:${bgVcs} fg:${catppuccin.base})";
        };

        vitals = lib.mkIf (!(hostConfig.isGui or false)) {
          when = "curl -sf http://127.0.0.1:8080/ > /dev/null 2>&1";
          shell = ["bash"];
          style = "bold green";
          format = "[$output]($style)";
          command = ''
            curl -sf http://127.0.0.1:8080/score 2>/dev/null | jq -r '[.score, .delta_1h] | @tsv' 2>/dev/null | while IFS=$'\t' read -r score delta; do score=$(printf '%.1f' "$score"); if [ -n "$delta" ] && [ "$delta" != "null" ] && [ "$delta" != "0" ]; then sign=$(echo "$delta" | jq -r 'if . > 0 then "↑" else "↓" end'); mag=$(printf '%.1f' "$(echo "$delta" | jq -r 'abs')"); echo "$score $sign$mag"; else echo "$score"; fi; done
          '';
        };
      };
    };
  };
}
