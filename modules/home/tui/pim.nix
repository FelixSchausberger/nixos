# Local contact stack for the homelab session: vdirsyncer pulls the Nextcloud
# CardDAV address book once per host; khard then works offline against the
# synced vdir. Events are handled by chroncal (modules/home/tui/chroncal.nix)
# and tasks by cfait (modules/home/tui/cfait.nix), both directly over CalDAV.
# First run per host needs address-book discovery (it prompts to create the
# missing local collection directory, answer y):
#   vdirsyncer discover contacts_nextcloud
# Until then the vdirsyncer timer fails with "Please run vdirsyncer discover".
{
  config,
  pkgs,
  ...
}: let
  ncDav = "https://m920q.tailf2f0ca.ts.net/nextcloud/remote.php/dav";
  # The app password never enters the nix store: the generated vdirsyncer
  # config only carries the command that reads the decrypted secret at
  # runtime via cat.
  passwordCommand = [
    "${pkgs.coreutils}/bin/cat"
    config.sops.secrets."nextcloud/calendar-app-password".path
  ];
in {
  sops.secrets."nextcloud/calendar-app-password" = {};

  programs = {
    vdirsyncer.enable = true;
    khard.enable = true;
  };

  services.vdirsyncer.enable = true;

  accounts.contact.accounts.nextcloud = {
    remote = {
      type = "carddav";
      # CardDAV nests the uid under users/; addressbooks/<uid>/<book>/
      # answers 404 on Nextcloud 30+.
      url = "${ncDav}/addressbooks/users/admin/my-contacts/";
      userName = "admin";
      inherit passwordCommand;
    };
    vdirsyncer = {
      enable = true;
      conflictResolution = "remote wins";
    };
    khard.enable = true;
  };
}
