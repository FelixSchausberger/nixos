# NixOS VM Integration Test: M920q Headless <-> Niri Mode Switching State Machine
#
# Uses the shared modules/system/m920q.nix module (same code as the real host).
# Script logic is NOT duplicated here — any behavioral change in the module
# is automatically tested.
_: {
  name = "m920q-mode-switch";

  nodes.machine = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      ../modules/system/specialisations.nix
      ../modules/system/m920q.nix
    ];

    options.hostConfig = lib.mkOption {
      type = lib.types.submodule {
        options = {
          hostName = lib.mkOption {
            type = lib.types.str;
            default = "m920q";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = "schausberger";
          };
          wms = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          isGui = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          performanceProfile = lib.mkOption {
            type = lib.types.str;
            default = "server-efficiency";
          };
          specialisations = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  wms = lib.mkOption {
                    type = lib.types.nullOr (lib.types.listOf lib.types.str);
                    default = null;
                  };
                  profile = lib.mkOption {
                    type = lib.types.str;
                    default = "default";
                  };
                  extraConfig = lib.mkOption {
                    type = lib.types.deferredModule;
                    default = {};
                  };
                };
              }
            );
            default = {};
          };
        };
      };
      default = {};
    };

    config = {
      users.users.schausberger = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = ["wheel" "video"];
      };

      systemd.services."home-manager-schausberger" = {
        description = "Mock Home Manager Service";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/true";
          RemainAfterExit = true;
        };
        wantedBy = ["multi-user.target"];
      };

      # greetd is defined in the base config (not the specialisation) so
      # the unit is always resolvable by systemd.  The mode-switch script
      # manages start/stop — no automatic wantedBy.
      systemd.services.greetd = {
        description = "Mock greetd for testing";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/true";
          RemainAfterExit = true;
        };
      };

      hostConfig = {
        hostName = "m920q";
        isGui = false;
        wms = ["niri"];
        performanceProfile = "server-efficiency";

        specialisations = {
          niri = {
            wms = ["niri"];
            profile = "default";
            extraConfig = {lib, ...}: {
              hostConfig.isGui = lib.mkForce true;
            };
          };
        };
      };

      # Use the shared m920q module with short timeouts for fast test execution
      modules.system.m920q = {
        enable = true;
        user = "schausberger";
        timerDelaySec = 1;
        modeSwitchTimeoutSec = 30;
      };

      # switch-to-configuration detects changed units between base and specialisation
      # configs and tries to reload them. In QEMU VMs, dbus-broker.service reload
      # hangs indefinitely because the broker doesn't handle SIGHUP in this environment.
      # Override ExecReload to a no-op so the reload succeeds instantly.
      systemd.services.dbus-broker.serviceConfig.ExecReload = lib.mkForce "${pkgs.coreutils}/bin/true";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Mock HDMI sysfs so the mode-switch script's hardware re-verification
    # sees the expected state. Without this, the script falls back to
    # headless because /sys/class/drm/*-HDMI-A-*/status doesn't exist in VMs.
    # Uses bind mount over /sys/class/drm since sysfs dirs can't be created directly.
    def mock_hdmi(status):
        """Bind-mount a mock sysfs tree over /sys/class/drm."""
        if status == "connected":
            machine.succeed(
                "mkdir -p /tmp/mock-drm/card0-HDMI-A-1",
                "echo connected > /tmp/mock-drm/card0-HDMI-A-1/status",
                "mount --bind /tmp/mock-drm /sys/class/drm",
            )
        else:
            machine.succeed("umount /sys/class/drm 2>/dev/null || true")
            machine.succeed("rm -rf /tmp/mock-drm")

    # 1. Check initial state (headless) and base-toplevel content
    base_toplevel = machine.succeed("cat /run/m920q-base-toplevel").strip()
    assert base_toplevel, "base-toplevel should not be empty"
    machine.fail("systemctl is-active greetd.service")

    # 2. Mock HDMI connected, then trigger Niri mode switch
    mock_hdmi("connected")
    machine.succeed("echo niri > /run/m920q-hdmi-state")
    machine.succeed("systemctl start m920q-mode-switch.service")

    # Verify mode is updated to niri and greetd is active
    machine.wait_for_unit("greetd.service")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'niri'")

    # 3. Idempotency: triggering same mode again should be a no-op
    machine.succeed("systemctl start m920q-mode-switch.service")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'niri'")

    # 4. Mock HDMI disconnected, then trigger Headless mode switch
    mock_hdmi("disconnected")
    machine.succeed("echo headless > /run/m920q-hdmi-state")
    machine.succeed("systemctl start m920q-mode-switch.service")

    # Verify mode is updated back to headless and greetd is stopped
    machine.wait_for_unit("multi-user.target")
    machine.fail("systemctl is-active greetd.service")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'headless'")

    # 5. Verify base-toplevel is preserved across mode switches
    base_toplevel_after = machine.succeed("cat /run/m920q-base-toplevel").strip()
    assert base_toplevel == base_toplevel_after, \
        f"base-toplevel changed across switches: {base_toplevel} -> {base_toplevel_after}"

    # 6. Verify timer exists for debounced mode switching
    machine.succeed("systemctl list-timers m920q-mode-switch.timer --no-legend | grep -q m920q-mode-switch")

    # 7. Resync mode: simulate stale current-mode marker after "deploy"
    mock_hdmi("disconnected")
    machine.succeed("echo niri > /run/m920q-current-mode")
    # Run resync activation script — with HDMI disconnected, should resync to headless
    machine.succeed("bash -c 'if [[ -f /run/m920q-current-mode ]]; then /run/current-system/activate 2>&1 || true; fi'")
    # The resync script should have reconciled to headless
    machine.succeed("test $(cat /run/m920q-current-mode) = 'headless'")
  '';
}
