# Test: development module provides expected tools on all hosts
{flake, ...}: let
  configs = flake.nixosConfigurations;

  # Check that key development packages are present by matching derivation name prefix
  hasPkg = prefix: builtins.any (pkg: builtins.match "${prefix}-.*" (pkg.name or "") != null || (pkg.name or "") == prefix);

  testDev = hostName: config: {
    inherit hostName;

    # C toolchain
    has_gcc = hasPkg "gcc-wrapper" config.environment.systemPackages;
    has_gnumake = hasPkg "gnumake" config.environment.systemPackages;

    # Node.js
    has_nodejs = hasPkg "nodejs" config.environment.systemPackages;

    # Python
    has_python3 = hasPkg "python3" config.environment.systemPackages;
    has_jq = hasPkg "jq" config.environment.systemPackages;

    # Language servers
    has_nixd = hasPkg "nixd" config.environment.systemPackages;
    has_bash_ls = hasPkg "bash-language-server" config.environment.systemPackages;
  };
in {
  desktop = testDev "desktop" configs.desktop.config;
  portable = testDev "portable" configs.portable.config;
  surface = testDev "surface" configs.surface.config;
  hp-probook-vmware = testDev "hp-probook-vmware" configs.hp-probook-vmware.config;
  hp-probook-wsl = testDev "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = testDev "m920q" configs.m920q.config;
}
