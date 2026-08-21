# NixOS VM Integration Test: M920q Manual Mode Switching
#
# Uses the shared modules/system/m920q.nix module (same code as the real host).
# Script logic is NOT duplicated here — any behavioral change in the module
# is automatically tested. The module is manual-only (matching production):
# the desired mode is written to /run/m920q-desired-mode and the service is
# started explicitly.
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

      # Use the shared m920q module with a short timeout for fast test execution
      modules.system.m920q = {
        enable = true;
        user = "schausberger";
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

    # 1. Check initial state (headless) and base-toplevel content
    base_toplevel = machine.succeed("cat /run/m920q-base-toplevel").strip()
    assert base_toplevel, "base-toplevel should not be empty"
    machine.fail("systemctl is-active greetd.service")

    # 2. Trigger Niri mode switch via the documented manual invocation
    machine.succeed("echo niri > /run/m920q-desired-mode")
    machine.succeed("systemctl start m920q-mode-switch.service")

    # Verify mode is updated to niri and greetd is active
    machine.wait_for_unit("greetd.service")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'niri'")

    # 3. Idempotency: triggering same mode again should be a no-op
    machine.succeed("systemctl start m920q-mode-switch.service")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'niri'")

    # 4. Trigger Headless mode switch
    machine.succeed("echo headless > /run/m920q-desired-mode")
    machine.succeed("systemctl start m920q-mode-switch.service")

    # Verify mode is updated back to headless and greetd is stopped
    machine.wait_for_unit("multi-user.target")
    machine.fail("systemctl is-active greetd.service")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'headless'")

    # 5. Verify base-toplevel is preserved across mode switches
    base_toplevel_after = machine.succeed("cat /run/m920q-base-toplevel").strip()
    assert base_toplevel == base_toplevel_after, \
        f"base-toplevel changed across switches: {base_toplevel} -> {base_toplevel_after}"

    # 6. Verify manual-only wiring: no debounce timer exists (production runs
    #    without automatic hotplug switching)
    machine.fail("systemctl cat m920q-mode-switch.timer")

    # 7. Resync mode: simulate stale current-mode marker after "deploy".
    #    The VM has no HDMI connectors, so the resync reconciles to headless.
    machine.succeed("echo niri > /run/m920q-current-mode")
    machine.succeed("bash -c 'if [[ -f /run/m920q-current-mode ]]; then /run/current-system/activate 2>&1 || true; fi'")
    machine.succeed("test $(cat /run/m920q-current-mode) = 'headless'")
  '';
}
