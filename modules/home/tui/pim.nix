# Local PIM stack: vdirsyncer pulls the Nextcloud CalDAV/CardDAV collections
# once per host; khal/ikhal, todoman and khard then work offline against the
# synced vdirs. First run per host needs collection discovery (it prompts to
# create the missing local collection directories, answer y):
#   vdirsyncer discover calendar_events calendar_tasks contacts_nextcloud
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
    # todoman globs its lists from accounts.calendar.basePath; point it at
    # the task pair's collections only (khal shows events, not VTODO).
    todoman = {
      enable = true;
      glob = "tasks/*";
    };
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
      # VTODO lists for todoman. khal is events-only, so this account is
      # deliberately not exposed to it.
      tasks =
        caldavAccount
        // {
          vdirsyncer = {
            enable = true;
            collections = [
              "finance"
              "household"
              "materialism"
              "self-case"
              "tasks"
              "tech"
              "to-do"
            ];
            itemTypes = ["VTODO"];
            conflictResolution = "remote wins";
          };
        };
    };
  };

  accounts.contact.accounts.nextcloud = {
    remote = {
      type = "carddav";
      url = "${ncDav}/addressbooks/admin/my-contacts/";
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
