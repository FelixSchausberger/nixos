{
  hostName,
  pkgs,
  ...
}: {
  programs.fish.functions = {
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
          echo "  🔧 Core Commands:"
          echo "    nx config           - Edit NixOS configuration"
          echo "    nx deploy [remote]  - Deploy NixOS configuration (includes Home Manager)"
          echo "    nx home             - Deploy Home Manager only (standalone)"
          echo "    nx update           - Update NixOS flake"
          echo ""
          echo "  🧹 Maintenance:"
          echo "    nx clean            - Remove old generations"
          echo "    nx garbage collect  - Run garbage collection"
          echo "    nx doctor           - Run maintenance tasks"
          echo "    nx maintain         - Comprehensive maintenance"
          echo ""
          echo "  📊 Status & Info:"
          echo "    nx status           - Show system status"
          echo "    nx history          - View generation history"
          echo "    nx bench            - Performance benchmarking"
          echo ""
          echo "  ⚡ Quick Actions:"
          echo "    nx quick            - Quick status & deploy"
          echo "    nx edit             - Edit config with deploy option"
          echo ""
          echo "  🔄 Recovery:"
          echo "    nx rollback         - Rollback to previous generation"
          echo ""
          return 0
        end

        switch $subcommand
          case config
            nx_config
          case status
            nx_status
          case maintain
            nx_maintain
          case quick
            nx_quick
          case edit
            nx_edit
          case deploy
            nx_deploy $flags
          case home
            nx_home $flags
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
          case bench
            nx_bench $flags
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
      description = "Deploy current NixOS configuration and Home Manager";
      body = ''
        set -l original_dir $PWD
        cd /per/etc/nixos

        # Check if remote deployment is requested
        if test "$argv[1]" = "remote"
          set -e argv[1]  # Remove 'remote' from args

          if test "$argv[1]" = "--dry"
            ${pkgs.deploy-rs}/bin/deploy --dry-run .
          else if test -n "$argv[1]"
            ${pkgs.deploy-rs}/bin/deploy ".#$argv[1]"
          else
            ${pkgs.deploy-rs}/bin/deploy ".#${hostName}"
          end
        else
          # Use nom for the entire rebuild process if available
          if command -v nom >/dev/null 2>&1
            sudo nom nixos-rebuild switch --flake "./#${hostName}" $argv
          else
            sudo nixos-rebuild switch --flake "./#${hostName}" $argv
          end

          if test $status -eq 0
            # Reload fish functions for current session
            if test "$SHELL" = /run/current-system/sw/bin/fish -o "$SHELL" = /usr/bin/fish -o (basename "$SHELL") = fish
              # Check if home-manager created the update marker
              if test -f ~/.config/fish/.functions_updated
                rm -f ~/.config/fish/.functions_updated
                echo "  ↳ Home-manager activation detected"
              end

              # Force reload all function files
              for func_file in ~/.config/fish/functions/*.fish
                if test -f "$func_file"
                  source "$func_file"
                end
              end
              echo "  ↳ Reloaded fish functions"

              # Reload completions
              if test -f ~/.config/fish/config.fish
                source ~/.config/fish/config.fish
                echo "  ↳ Reloaded fish configuration"
              end

              # Clear fish function cache
              if type -q funcsave
                # Fish functions are cached, clear and reload
                echo "  ↳ Cleared function cache"
              end
            end

            # Reload Hyprland if running
            if pgrep -x Hyprland >/dev/null 2>&1
              hyprctl reload >/dev/null 2>&1
              echo "  ↳ Reloaded Hyprland configuration"
            end
          else
            return 1
          end
        end

        cd $original_dir
      '';
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

    nx_home = {
      description = "Deploy Home Manager configuration standalone";
      body = ''
        set -l original_dir $PWD
        cd /per/etc/nixos

        # Determine the home configuration name (user_hostname pattern)
        set -l home_config "schausberger_${hostName}"

        echo "🏠 Deploying Home Manager configuration: $home_config"

        # Use nom if available for better output
        if command -v nom >/dev/null 2>&1
          nom home-manager switch --flake ".#$home_config" $argv
        else
          home-manager switch --flake ".#$home_config" $argv
        end

        if test $status -eq 0
          # Reload fish functions for current session
          if test "$SHELL" = /run/current-system/sw/bin/fish -o "$SHELL" = /usr/bin/fish -o (basename "$SHELL") = fish
            echo "🐠 Reloading shell configuration..."

            # Force reload all function files
            for func_file in ~/.config/fish/functions/*.fish
              if test -f "$func_file"
                source "$func_file"
              end
            end
            echo "  ↳ Reloaded fish functions"

            # Reload completions
            if test -f ~/.config/fish/config.fish
              source ~/.config/fish/config.fish
              echo "  ↳ Reloaded fish configuration"
            end
          end

          echo ""
        else
          return 1
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

    nx_bench = {
      description = "Quick performance benchmarking and system analysis";
      body = ''
        echo "🚀 NixOS Performance Benchmark"
        echo "================================"
        echo ""

        # System Information
        echo "📊 System Information:"
        fastfetch --structure Title:Separator:OS:Kernel:Uptime:Memory:Disk:CPU:GPU:Colors
        echo ""

        # ZFS Performance Check
        if command -v zpool >/dev/null 2>&1
          echo "🏊 ZFS Pool Status:"
          zpool status -v
          echo ""

          echo "📈 ZFS I/O Statistics (5 samples):"
          zpool iostat -v 1 5
          echo ""

          echo "🧠 ZFS ARC Statistics:"
          cat /proc/spl/kstat/zfs/arcstats | grep -E "(hits|miss|size)" | head -10
          echo ""
        end

        # File System Performance
        echo "💾 Disk Performance Test (temporary file):"
        set -l temp_file (mktemp)
        echo "Write test (1GB):"
        if command -v hyperfine >/dev/null 2>&1
          hyperfine --warmup 1 "dd if=/dev/zero of=$temp_file bs=1M count=1024 conv=sync 2>/dev/null"
          echo "Read test (1GB):"
          hyperfine --warmup 1 "dd if=$temp_file of=/dev/null bs=1M 2>/dev/null"
        else
          echo "📝 Write: "
          dd if=/dev/zero of=$temp_file bs=1M count=1024 conv=sync 2>&1 | tail -1
          echo "📖 Read: "
          dd if=$temp_file of=/dev/null bs=1M 2>&1 | tail -1
        end
        rm -f $temp_file
        echo ""

        # Network Performance
        echo "🌐 Network Connectivity:"
        if command -v gping >/dev/null 2>&1
          echo "Testing connectivity (5 pings each):"
          echo "  • DNS (1.1.1.1):"
          gping -c 5 1.1.1.1 2>/dev/null || ping -c 5 1.1.1.1
          echo "  • GitHub (github.com):"
          gping -c 5 github.com 2>/dev/null || ping -c 5 github.com
        else
          echo "Testing with ping (5 pings each):"
          echo "  • DNS: " && ping -c 5 1.1.1.1
          echo "  • GitHub: " && ping -c 5 github.com
        end
        echo ""

        # Build Performance Test
        echo "🏗️  Nix Build Performance:"
        if command -v hyperfine >/dev/null 2>&1
          echo "Testing build time for 'hello' package:"
          hyperfine --warmup 1 "nix build nixpkgs#hello --no-link --quiet"
        else
          echo "Building 'hello' package (timed):"
          time nix build nixpkgs#hello --no-link --quiet
        end
        echo ""

        # Memory and Process Info
        echo "🔍 Current Resource Usage:"
        if command -v btm >/dev/null 2>&1
          echo "Resource usage (5s sample):"
          timeout 5s btm --basic -t 1000 2>/dev/null || echo "System monitor not available"
        else
          echo "Memory usage:"
          free -h
          echo "CPU usage:"
          top -bn1 | head -10
        end
        echo ""

        echo "✅ Benchmark Complete!"
        echo "💡 Tip: Use 'btm' for detailed real-time monitoring"
      '';
    };

    # Enhanced Quality of Life functions
    nx_status = {
      description = "Show comprehensive system status";
      body = ''
        echo "🔍 NixOS System Status Report"
        echo "=============================="
        echo ""

        echo "📋 System Info:"
        echo "  • NixOS Version: $(nixos-version)"
        echo "  • Hostname: $(hostname)"
        echo "  • Uptime: $(uptime | awk '{print $3, $4}' | sed 's/,//')"
        echo "  • Current Generation: $(sudo nix-env -p /nix/var/nix/profiles/system --list-generations | tail -1 | awk '{print $1}')"
        echo ""

        echo "💾 Storage Status:"
        df -h / /nix | tail -2
        echo ""

        echo "🗑️  Nix Store Status:"
        # Use timeout for potentially slow commands and faster alternatives
        set -l store_size (timeout 3s sh -c "df -h /nix | tail -1 | awk '{print \$3}'" 2>/dev/null || echo "N/A")
        echo "  • Store size: $store_size (used space)"
        echo "  • Generations: $(sudo nix-env -p /nix/var/nix/profiles/system --list-generations | wc -l) total"
        # Show available space instead of slow GC dry-run
        set -l available_space (timeout 2s sh -c "df -h /nix | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "N/A")
        echo "  • Available space: $available_space"
        echo ""

        echo "🏗️  Build Cache:"
        set -l build_count (ls /tmp/ 2>/dev/null | grep "^nix-build" | wc -l)
        if test $build_count -gt 0
          echo "  • Active builds: $build_count"
        else
          echo "  • No active builds"
        end

        echo "🌡️  System Health:"
        # Check for common issues
        if systemctl --failed --quiet
          echo "  ⚠️  Failed services detected: $(systemctl --failed --no-legend | wc -l)"
          systemctl --failed --no-legend | head -3
        else
          echo "  ✅ All services running normally"
        end

        echo ""
        echo "💡 Use 'nx doctor' for maintenance tasks"
      '';
    };

    nx_maintain = {
      description = "Comprehensive maintenance with user confirmation";
      body = ''
        echo "🧹 NixOS Comprehensive Maintenance"
        echo "================================="
        echo ""
        echo "This will:"
        echo "  1. Update flake inputs"
        echo "  2. Clean old generations (keep last 5)"
        echo "  3. Run garbage collection"
        echo "  4. Optimize Nix store"
        echo "  5. Verify system health"
        echo ""

        read -P "Continue with maintenance? [y/N]: " -n 1 confirm
        echo ""

        if test "$confirm" = "y" -o "$confirm" = "Y"
          set -l start_time (date +%s)

          echo "🔄 Step 1/5: Updating flake inputs..."
          nx_update

          echo "🧽 Step 2/5: Cleaning old generations..."
          nx_clean

          echo "🗑️  Step 3/5: Running garbage collection..."
          nx_garbage_collect

          echo "⚡ Step 4/5: Optimizing Nix store..."
          sudo nix store optimise

          echo "🔍 Step 5/5: Health check..."
          nx_status

          set -l end_time (date +%s)
          set -l duration (math $end_time - $start_time)

          echo ""
          echo "✅ Maintenance completed in {$duration}s!"
          echo "💾 Storage space freed: $(df -h / | tail -1 | awk '{print $4}') available"
        else
          echo "Maintenance cancelled."
        end
      '';
    };

    nx_quick = {
      description = "Quick status check and deploy";
      body = ''
        echo "⚡ Quick NixOS Status & Deploy"
        echo "=============================="

        # Quick status
        echo "📊 Quick Status:"
        echo "  • Generation: $(sudo nix-env -p /nix/var/nix/profiles/system --list-generations | tail -1 | awk '{print $1}')"
        echo "  • Disk usage: $(df -h / | tail -1 | awk '{print $5}')"
        echo "  • Store size: $(du -sh /nix/store 2>/dev/null | cut -f1 || echo 'N/A')"
        echo ""

        # Check for changes
        set -l original_dir $PWD
        cd /per/etc/nixos

        if git status --porcelain | grep -q .
          echo "📝 Uncommitted changes detected:"
          git status --short | head -5
          echo ""

          read -P "Deploy with current changes? [y/N]: " -n 1 deploy_confirm
          echo ""

          if test "$deploy_confirm" = "y" -o "$deploy_confirm" = "Y"
            nx_deploy
          else
            echo "Deploy cancelled. Use 'git add .' and 'git commit' to save changes first."
          end
        else
          echo "✅ Configuration up to date - deploying..."
          nx_deploy
        end

        cd $original_dir
      '';
    };

    nx_edit = {
      description = "Edit configuration and optionally deploy";
      body = ''
        set -l original_dir $PWD
        cd /per/etc/nixos
        yazi .

        # Check if any files were changed
        if git status --porcelain | grep -q .
          echo ""
          echo "📄 Changes detected:"
          git status --short | head -10
          echo ""

          read -P "Review changes and deploy? [y/N]: " -n 1 review_confirm
          echo ""

          if test "$review_confirm" = "y" -o "$review_confirm" = "Y"
            echo "👀 Reviewing changes:"
            git diff --stat
            echo ""

            read -P "Deploy these changes? [y/N]: " -n 1 deploy_confirm
            echo ""

            if test "$deploy_confirm" = "y" -o "$deploy_confirm" = "Y"
              nx_deploy
            else
              echo "Changes saved but not deployed. Use 'nx deploy' when ready."
            end
          end
        else
          echo "No changes made."
        end

        cd $original_dir
      '';
    };
  };

  programs.fish.interactiveShellInit = ''
    # Completions for nx command
    complete -c nx -f -a "config deploy home update clean garbage_collect maintenance rollback history bench status maintain quick edit" -d "NixOS management subcommands"
    complete -c nx -s h -l help -d "Show help message"
  '';
}
