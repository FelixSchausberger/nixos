{
  hostName,
  pkgs,
  ...
}: {
  programs.fish = {
    enable = true;
    functions = {
      fish_prompt = {
        description = "Custom fish prompt";
        body = ''
          set -l nix_shell_info ""
          if test -n "$IN_NIX_SHELL"
            set nix_shell_info "<nix-shell> "
          end

          set_color $fish_color_cwd
          echo -n (prompt_pwd)
          set_color normal
          echo -n -s " $nix_shell_info ~> "
        '';
      };

      # https://pastebin.com/fh5V032Z
      nx = {
        description = "NixOS management commands";
        body = ''
          set -l subcommand $argv[1]
          set -l flags $argv[2..-1]

          # Show help if no subcommand provided or help requested
          if test -z "$subcommand" -o "$subcommand" = "--help" -o "$subcommand" = "-h"
            echo ""
            echo "NixOS management commands:"
            echo "  nx config           - Edit NixOS configuration"
            echo "  nx deploy [flags]   - Deploy current NixOS configuration"
            echo "  nx update           - Update NixOS flake"
            echo "  nx clean            - Remove old generations"
            echo "  nx garbage collect  - Run garbage collection"
            echo "  nx doctor           - Run maintenance tasks"
            echo "  nx rollback         - Rollback to previous generation"
            echo "  nx history          - View generation history"
            echo ""
            return 0
          end

          switch $subcommand
            case config
              nx_config
            case deploy
              nx_deploy $flags
            case update
              nx_update $flags
            case clean
              nx_clean $flags
            case gc
              nx_garbage_collect $flags
            case doctor
              nx_maintenance $flags
            case rollback
              nx_rollback $flags
            case history
              nx_history $flags
            case '*'
              echo "Unknown subcommand: $subcommand"
              return 1
          end
        '';
      };

      nx_config = {
        description = "Edit NixOS configuration";
        body = ''
          set -l original_dir $PWD
          cd /per/etc/nixos

          # Use yazi to browse and select files to edit
          ${pkgs.yazi}/bin/yazi

          cd $original_dir
        '';
      };

      nx_deploy = {
        description = "Deploy current NixOS configuration";
        body = ''
          set -l original_dir $PWD
          cd /per/etc/nixos
          sudo nixos-rebuild switch --flake "./#${hostName}" $argv
          cd $original_dir
        '';
        # |& ${pkgs.nix-output-monitor}/bin/nom
        # '';
      };

      nx_update = {
        description = "Update NixOS flake";
        body = ''
          set -l original_dir $PWD
          cd /per/etc/nixos
          nix flake update
          if test $status -eq 0
            nx_deploy
          end
          cd $original_dir
        '';
      };

      nx_clean = {
        description = "Remove old generations";
        body = ''
          sudo nix-collect-garbage -d $argv
        '';
      };

      nx_garbage_collect = {
        description = "Run garbage collection";
        body = ''
          sudo nix store gc $argv
          sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d
        '';
      };

      nx_maintenance = {
        description = "Run maintenance tasks";
        body = ''
          set -l original_dir $PWD
          cd /per/etc/nixos
          echo "Running maintenance tasks..."
          nx_update
          nx_garbage_collect
          nx_clean
          sudo nix store optimise
          cd $original_dir
        '';
      };

      nx_rollback = {
        description = "Rollback to previous generation";
        body = ''
          sudo nixos-rebuild switch --rollback $argv
        '';
      };

      nx_history = {
        description = "View generation history";
        body = ''
          echo "System Generation History:"
          sudo nix-env -p /nix/var/nix/profiles/system --list-generations $argv
        '';
      };
    };

    interactiveShellInit = ''
      # Completions for nx command
      complete -c nx -f -a "config deploy update clean garbage_collect maintenance rollback history" -d "NixOS management subcommands"
      complete -c nx -s h -l help -d "Show help message"
    '';
  };
}
