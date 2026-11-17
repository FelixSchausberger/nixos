# Local PIM stack for events and contacts: vdirsyncer pulls the Nextcloud
# CalDAV/CardDAV collections once per host; khal/ikhal and khard then work
# offline against the synced vdirs. Tasks are not synced here: cfait talks to
# the Nextcloud VTODO collections directly (modules/home/tui/cfait.nix).
# First run per host needs collection discovery (it prompts to create the
# missing local collection directories, answer y):
#   vdirsyncer discover calendar_events contacts_nextcloud
# Until then the vdirsyncer timer fails with "Please run vdirsyncer discover"
# and khal/ikhal refuse to start (missing default calendar).
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
  caldavAccount = {
    remote = {
      type = "caldav";
      url = "${ncDav}/calendars/admin/";
      userName = "admin";
      inherit passwordCommand;
    };
  };
in {
  sops.secrets."nextcloud/calendar-app-password" = {};

  programs = {
    vdirsyncer.enable = true;
    khal.enable = true;
    khard.enable = true;
  };

  services.vdirsyncer.enable = true;

  accounts.calendar = {
    basePath = ".local/share/calendars";
    accounts = {
      # Event calendars. khal discovers every collection synced beneath the
      # account directory, so new calendars only need a vdirsyncer entry.
      events =
        caldavAccount
        // {
          primary = true;
          primaryCollection = "personal";
          vdirsyncer = {
            enable = true;
            collections = ["personal"];
            itemTypes = ["VEVENT"];
            # Nextcloud is the canonical store (Planify, Thunderbird, DAVx5
            # write server-side). Without a resolver a sync conflict fails
            # the unattended timer for good - vdirsyncer has no interactive
            # fallback - so let the server win the rare same-item race.
            conflictResolution = "remote wins";
          };
          khal = {
            enable = true;
            type = "discover";
          };
        };
    };
  };

  accounts.contact.accounts.nextcloud = {
    remote = {
      type = "carddav";
      # CardDAV nests the uid under users/, unlike the calendars/ tree above;
      # addressbooks/<uid>/<book>/ answers 404 on Nextcloud 30+.
      url = "${ncDav}/addressbooks/users/admin/my-contacts/";
      userName = "admin";
      inherit passwordCommand;
    };
    vdirsyncer = {
      enable = true;
      conflictResolution = "remote wins";
    };
    khard.enable = true;
    # Birthdays show up in khal from the contacts' BDAY fields, so the
    # server-generated contact_birthdays calendar stays out of the sync:
    # editing it locally would fight Nextcloud's regeneration on every
    # contact change.
    khal.enable = true;
  };
}
