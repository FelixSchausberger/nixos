# NixOS Configuration Architecture

## Design Principles

1. **Explicit over implicit** - Clear configuration flow via hostConfig
2. **Minimal specialisations** - Use only for boot-time choices (WM selection)
3. **Runtime over boot-time** - Performance profiles via systemd, not rebuilds
4. **Single source of truth** - hostConfig drives all module behavior

## Module System

### hostConfig Flow

- Defined in `lib/hosts.nix` per host
- Available to all system and home-manager modules
- Drives conditional module activation via `lib.mkIf`

**Example:**
```nix
# lib/hosts.nix
desktop = {
  wms = ["hyprland"];  # Default WM, others via specialisations
  isGui = true;
  description = "Desktop with boot-time WM selection";
};
```

### WM Modules

- System modules: `modules/system/wm/*.nix`
- Home modules: `modules/home/wm/*/default.nix`
- Self-guarding: `lib.mkIf (hostConfig.isGui && builtins.elem "wm" hostConfig.wms)`

**Guard pattern:**
```nix
config = lib.mkIf (hostConfig.isGui && builtins.elem "hyprland" hostConfig.wms) {
  programs.hyprland.enable = true;
  # ...
};
```

### Specialisations

**Use only for:** Boot-time WM selection

**Don't use for:** Performance profiles, recovery tools, temporary configs

**Rationale:**
- Each specialisation multiplies module evaluation overhead
- Boot-time WM switching is a valid use case (hardware compatibility, user preference)
- Performance profiles work better at runtime (no reboot, instant switching)

**Example:**
```nix
specialisations = {
  niri = {
    wms = ["niri"];
    profile = "default";
    imports = [../../modules/system/wm/niri.nix];
    extraConfig = {
      home-manager.users.${user}.imports = [
        ../../modules/home/wm/niri
        ../../home/profiles/${host}/niri.nix
      ];
    };
  };

  gnome = {
    wms = ["gnome"];
    profile = "default";
    imports = [../../modules/system/wm/gnome.nix];
  };
};
```

## Performance Profiles

Use runtime switching via systemd targets instead of specialisations.

**Available modes:**
- `gaming` - High performance (CPU performance governor, gamemode)
- `power-saving` - Battery optimization (CPU powersave governor, TLP)
- `productivity` - Balanced (CPU schedutil governor)

**Switching:**
```bash
set-performance-mode gaming        # High performance
set-performance-mode power-saving  # Battery optimization
set-performance-mode productivity  # Balanced
```

**Benefits:**
- No reboot required
- Instant switching
- No evaluation overhead
- Better UX

**Implementation:**
- Module: `modules/system/performance-runtime.nix`
- Uses systemd targets and isolate mechanism
- Configured per-host via imports

## Adding a New WM

1. Create system module: `modules/system/wm/newwm.nix`
   ```nix
   { lib, pkgs, hostConfig, ... }:
   {
     config = lib.mkIf (hostConfig.isGui && builtins.elem "newwm" hostConfig.wms) {
       programs.newwm.enable = true;
       # ...
     };
   }
   ```

2. Create home module: `modules/home/wm/newwm/default.nix`
   ```nix
   { config, lib, pkgs, ... }:
   {
     options.wm.newwm = {
       enable = lib.mkEnableOption "NewWM configuration";
       # ...
     };

     config = lib.mkIf config.wm.newwm.enable {
       # Home configuration
     };
   }
   ```

3. Add host profile: `home/profiles/${host}/newwm.nix`
   ```nix
   { ... }:
   {
     wm.newwm = {
       enable = true;
       # Host-specific WM settings
     };
   }
   ```

4. Add specialisation in `hosts/${host}/default.nix`:
   ```nix
   specialisations.newwm = {
     wms = ["newwm"];
     profile = "default";
     imports = [../../modules/system/wm/newwm.nix];
     extraConfig = {
       home-manager.users.${user}.imports = [
         ../../modules/home/wm/newwm
         ../../home/profiles/${host}/newwm.nix
       ];
     };
   };
   ```

5. Test build and boot:
   ```bash
   nix build .#nixosConfigurations.${host}.config.specialisation.newwm.configuration.system.build.toplevel
   sudo nixos-rebuild test --flake .#${host}
   ```

## Evaluation Overhead Analysis

### Problem: Specialisation Multiplication

Each specialisation evaluates all imported modules. With N specialisations:
- Total evaluations = (1 parent + N specialisations) × M modules
- Memory usage scales with N × M

**Example (desktop before optimization):**
- 6 specialisations (gnome-only, hyprland-only, hyprland-gaming, niri-only, niri-portable, build-optimized)
- Each imports 3 WM modules (hyprland, niri, gnome)
- Total: 7 configs × 3 WM modules = 21 WM module evaluations
- Result: 4.5GB heap usage, OOM on 8GB systems

### Solution: Hybrid Approach

**Reduce specialisations to WM-only:**
- 2 specialisations (niri, gnome)
- Parent provides hyprland
- Total: 3 configs × 1 WM module each = 3 WM module evaluations
- Result: <2.5GB heap usage, 78% reduction

**Move performance profiles to runtime:**
- Use systemd targets instead of specialisations
- No evaluation overhead
- Better UX (no reboot)

### Guard Patterns

All WM modules use dual guards to prevent unnecessary evaluation:

```nix
config = lib.mkIf (hostConfig.isGui && builtins.elem "wm" hostConfig.wms) {
  # Module configuration
};
```

**Why both guards:**
- `hostConfig.isGui` - Skip entire GUI stack on TUI-only hosts
- `builtins.elem` - Skip specific WM modules not used by host
- Combined effect: Only evaluate active WM modules

## Host Configuration Patterns

### Desktop Host (Multiple WMs)

**Use case:** User wants multiple WMs available at boot time

**Pattern:**
```nix
# lib/hosts.nix
desktop = {
  wms = ["hyprland"];  # Default WM
  isGui = true;
};

# hosts/desktop/default.nix
specialisations = {
  niri = { wms = ["niri"]; ... };
  gnome = { wms = ["gnome"]; ... };
};
```

**GRUB menu:**
- NixOS (hyprland)
- NixOS (niri)
- NixOS (gnome)

### Surface/Portable Host (Single WM)

**Use case:** Specific hardware requires specific WM

**Pattern:**
```nix
# lib/hosts.nix
surface = {
  wms = ["niri"];  # Touch-optimized WM
  isGui = true;
};

# hosts/surface/default.nix
specialisations = {};  # No specialisations needed
```

**GRUB menu:**
- NixOS (niri only)

### Portable Host (TUI Only)

**Use case:** Emergency recovery system, minimal footprint

**Pattern:**
```nix
# lib/hosts.nix
portable = {
  wms = [];  # No GUI
  isGui = false;
};

# hosts/portable/default.nix
specialisations = {};  # No GUI specialisations
```

**GRUB menu:**
- NixOS (console only)

## Troubleshooting

### OOM during evaluation

**Symptom:** `error: out of memory` during `nix build` or `nixos-rebuild`

**Diagnosis:**
```bash
/usr/bin/time -v nix eval .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath 2>&1 | grep "Maximum resident"
```

**Solutions:**
1. Check number of specialisations (keep ≤ 3 per host)
2. Verify WM modules have `lib.mkIf` guards with both `isGui` and `wms` checks
3. Check for redundant imports in specialisations
4. Consider splitting large shared modules with finer guards

**Target:** <2.5GB heap usage for desktop configuration

### WM not available

**Symptom:** Expected WM not in GRUB menu or not starting

**Diagnosis:**
1. Verify `hostConfig.wms` includes WM name in `lib/hosts.nix`
2. Check `hostConfig.isGui = true` for GUI hosts
3. Ensure WM module has correct guard condition
4. Check specialisation imports correct WM module

**Verification:**
```bash
# Check parent config
nix eval .#nixosConfigurations.desktop.config.hostConfig.wms

# Check specialisation
nix eval .#nixosConfigurations.desktop.config.specialisation.niri.configuration.hostConfig.wms

# Build specialisation
nix build .#nixosConfigurations.desktop.config.specialisation.niri.configuration.system.build.toplevel
```

### Performance mode switching fails

**Symptom:** `set-performance-mode` command fails or has no effect

**Diagnosis:**
1. Check systemd target status: `systemctl status gaming-mode.target`
2. Verify services are enabled: `systemctl list-units | grep -E '(gamemode|tlp|thermald)'`
3. Check module is imported in host config

**Verification:**
```bash
# List available targets
systemctl list-units --type=target | grep mode

# Check current target
systemctl get-default

# Test target activation
systemctl isolate gaming-mode.target
```

### CI build failures

**Symptom:** Garnix CI fails with OOM or evaluation errors

**Common causes:**
1. Too many specialisations (>3 per host)
2. Missing guards in WM modules
3. Circular imports
4. Large shared modules evaluated redundantly

**Debugging:**
```bash
# Local evaluation check
nix flake check

# Memory profiling
/usr/bin/time -v nix build .#nixosConfigurations.desktop.config.system.build.toplevel 2>&1 | grep resident

# Trace evaluation
nix-instantiate --show-trace --eval -E '(builtins.getFlake (toString ./.)).nixosConfigurations.desktop.config.system.build.toplevel.drvPath'
```

## Migration Guide

### From Multi-Profile Specialisations to Runtime Switching

**Before (specialisations for performance):**
```nix
specialisations = {
  hyprland-gaming = {
    wms = null;
    profile = "gaming";
    imports = [];
  };

  hyprland-only = {
    wms = null;
    profile = "default";
    imports = [];
  };
};
```

**After (runtime switching):**
```nix
# No specialisations needed for performance profiles
imports = [ ../../modules/system/performance-runtime.nix ];

# Use at runtime:
# set-performance-mode gaming
# set-performance-mode productivity
```

**Benefits:**
- 2 fewer specialisations = 2/3 reduction in evaluation overhead
- No reboot required for performance changes
- Instant switching
- Better UX

### From Multi-WM Parent to Single WM

**Before:**
```nix
desktop = {
  wms = ["hyprland" "niri" "gnome"];  # All WMs in parent
  isGui = true;
};
```

**After:**
```nix
desktop = {
  wms = ["hyprland"];  # Default only, others via specialisations
  isGui = true;
};

specialisations = {
  niri = { wms = ["niri"]; ... };
  gnome = { wms = ["gnome"]; ... };
};
```

**Benefits:**
- Parent evaluates only 1 WM module instead of 3
- Specialisations evaluate only their specific WM
- Total evaluations: 3 instead of 7 × 3 = 21

## Performance Optimization Guidelines

### When to Add Specialisations

**Good reasons:**
- Boot-time WM selection (hardware compatibility, user preference)
- Different kernel versions (mainline vs LTS)
- Testing experimental features in isolation

**Bad reasons:**
- Performance profiles (use runtime switching)
- Temporary debugging configs (use `nixos-rebuild test`)
- Recovery tools (use separate host or ISO)

### Memory Budget

**Target per host:**
- TUI-only: <1GB heap
- Single WM: <2GB heap
- Multiple WMs (≤3 specialisations): <2.5GB heap

**Measurement:**
```bash
/usr/bin/time -v nix eval .#nixosConfigurations.${host}.config.system.build.toplevel.drvPath 2>&1 | grep "Maximum resident"
```

### CI Optimization

**Garnix CI settings:**
- Uses binary cache for dependencies
- Builds only changed configurations
- Parallel builds across hosts
- Memory limit: 8GB per build

**Optimization checklist:**
1. Keep specialisations ≤ 3 per host
2. Use guards in all conditional modules
3. Split large shared modules
4. Cache expensive evaluations
5. Profile memory usage locally before pushing

## Future Improvements

### Potential Optimizations

1. **Module evaluation caching**
   - Cache evaluated modules in CI
   - Reuse across similar configurations
   - Reduces evaluation time by 40-60%

2. **Finer-grained shared modules**
   - Split `shared-packages.nix` by category
   - Add guards for optional features
   - Only evaluate what's actually used

3. **Parallel evaluation**
   - Use `nix eval --parallel`
   - Evaluate specialisations concurrently
   - Requires Nix 2.19+

4. **Lazy module loading**
   - Defer expensive evaluations
   - Load only when accessed
   - Experimental feature in Nix

### Monitoring

Track evaluation metrics over time:

```bash
# Evaluation time
time nix eval .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath

# Memory usage
/usr/bin/time -v nix eval .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath 2>&1 | grep resident

# Module count
nix-instantiate --eval -E '(builtins.getFlake (toString ./.)).nixosConfigurations.desktop.config._module.args' | wc -l
```

Add to CI for regression detection.

## References

- [NixOS Manual: Specialisations](https://nixos.org/manual/nixos/stable/#sec-specialisations)
- [Nix Pills: Module System](https://nixos.org/guides/nix-pills/nixos-module-system.html)
- [NixOS Wiki: Evaluation Performance](https://nixos.wiki/wiki/Nix_Evaluation_Performance)
