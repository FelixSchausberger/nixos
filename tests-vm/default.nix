# NixOS VM Integration Tests index
{
  pkgs,
  self,
  inputs,
}: let
  runTest = testFile:
    pkgs.testers.runNixOSTest (
      let
        test = import testFile {inherit pkgs self inputs;};
      in
        test
        // {
          defaults =
            (test.defaults or {})
            // {
              _module.args = {
                inherit inputs;
                inherit (inputs) self;
              };
            };
        }
    );
in {
  m920q-mode-switch = runTest ./m920q-mode-switch.nix;
  caddy-proxy = runTest ./caddy-proxy.nix;
  zfs-backup = runTest ./zfs-backup.nix;
  streaming-services = runTest ./streaming-services.nix;
  deferred-maintenance = runTest ./deferred-maintenance.nix;
}
