# Declarative manifest for the Pixel 10a GrapheneOS migration. Every fact has
# one authoritative source here; `pixel-provision` (pkgs/pixel-provision)
# renders it into an adb-driven configure-and-install pass plus printed
# checklists for the lanes Android only offers interactively. Package
# membership is verified at plan time: the F-Droid ids against the fdroidcl
# index, the Obtainium upstreams against their GitHub release assets. This
# file is data only: a pure function returning the manifest attrset; the sole
# consumer applies it with {} (pkgs/pixel-provision).
_: {
  settings =
    # System settings applied via `adb shell settings --user <id> put
    # <namespace> <key> <value>` to every profile the manifest covers. Private
    # DNS stays off: Android's strict DoT cannot work on a Tailscale VPN
    # network, because the split tunnel has no route to the DoT servers, so the
    # resolver is left without any, the private-DNS probe fails and the network
    # never validates ("Private DNS server cannot be accessed"). DNS is the
    # network's resolver, and Tailscale's forwarder while the tunnel is up.
    # Lockdown stays off: with Tailscale as the always-on app, lockdown blocks
    # every non-VPN app while Tailscale is logged out, including the browser
    # that must load the interactive login URL. A private space inherits these
    # rows when it is created, so a lockdown value here would recreate the
    # deadlock there.
    {
      global = [
        ["private_dns_mode" "off"]
      ];
      secure = [
        ["always_on_vpn_app" "com.tailscale.ipn"]
        ["always_on_vpn_lockdown" "0"]
      ];
    };

  lanes = {
    # Verified against the official F-Droid repo index (fdroidcl show).
    # The F-Droid builds are F-Droid-signed: fresh sign-in or re-pairing
    # where the 9a held an upstream-signed build (DAVx5: same id, other key).
    fdroid = [
      "com.termux"
      "com.termux.nix" # nix-on-droid app itself; `nix-on-droid switch` rides it
      "com.termux.widget"
      "at.bitfire.davdroid"
      "at.bitfire.icsdroid"
      "org.fossify.calendar"
      "org.tasks"
      "io.heckel.ntfy"
      "com.beemdevelopment.aegis"
      "org.mozilla.fennec_fdroid" # Firefox engine; replaces org.mozilla.fenix
      "com.github.catfriend1.syncthingfork" # the vault sync; verified: the index carries it, fdroidcl installs it
      # Bootstrap clients the 10a bench proved necessary: fdroidcl installs
      # ids without any client, but the F-Droid client stays for browsing
      # and Aurora's anonymous session serves the whole Aurora lane.
      "org.fdroid.fdroid"
      "com.aurora.store"
    ];

    # Upstream GitHub-release APKs, imported in bulk via Obtainium's
    # `obtainium://apps/` deep link. Ids are matched against the 9a dump;
    # Obtainium's id field is bookkeeping only.
    obtainium = [
      {
        id = "app.alextran.immich";
        name = "Immich";
        author = "immich-app";
        url = "https://github.com/immich-app/immich";
      }
      {
        id = "com.nextcloud.client";
        name = "Nextcloud";
        author = "nextcloud";
        url = "https://github.com/nextcloud/android";
      }
      {
        id = "com.tailscale.ipn";
        name = "Tailscale";
        author = "tailscale";
        url = "https://github.com/tailscale/tailscale-android";
      }
      {
        id = "com.limelight";
        name = "Moonlight";
        author = "moonlight-stream";
        url = "https://github.com/moonlight-stream/moonlight-android";
      }
      {
        # UPM runs ReVanced, Morphe and Reseam patch bundles in one place;
        # its runtimes bundle the Morphe and Reseam engines, so the two
        # dedicated managers stay dropped. Bench-verified id: the APK's
        # applicationId (app/build.gradle.kts) governs, and Obtainium
        # matches imports against it. Pin the arm64-v8a asset in Obtainium
        # (Tensor G5; universal re-picks flavors per update).
        id = "app.universal.patch.manager";
        name = "UPM";
        author = "Jman-Github";
        url = "https://github.com/Jman-Github/Universal-Patch-Manager";
      }
      {
        id = "com.steamcontroller.android";
        name = "SteamController";
        author = "SonicDX12";
        url = "https://github.com/SonicDX12/SteamController-Android";
      }
      {
        id = "eu.darken.porter";
        name = "Porter";
        author = "d4rken-org";
        url = "https://github.com/d4rken-org/porter";
      }
      {
        # OpenCode on the phone: the native Android client against the m920q
        # OpenCode server, replacing the retired Collie PWA bridge. Pairing:
        # `opencode pair --url ...` on the host prints the QR (see manual).
        id = "io.github.beppe2880.opencodemobile";
        name = "OpenCode Mobile";
        author = "beppe2880";
        url = "https://github.com/beppe2880/opencode-mobile";
      }
      {
        # Keyboard of the fleet. Bench-verified id: the 0.1.30 release APK's
        # applicationId governs (no launcher activity, so the launcher audit
        # never sees IMEs). Single universal APK per release: no ABI pinning.
        id = "org.futo.inputmethod.latin";
        name = "FUTO Keyboard";
        author = "futo-org";
        url = "https://github.com/futo-org/android-keyboard";
      }
    ];

    # Play-only proprietary apps, installed through Aurora Store's anonymous
    # session so no Google account or Play signer ever lands on the phone.
    # The Steam Link family stays here; the controller app needs only Porter.
    aurora = [
      # Communication
      "com.whatsapp"
      "org.thoughtcrime.securesms"
      "com.discord"
      "org.telegram.messenger"
      "com.reddit.frontpage"
      "com.instagram.android"
      "fr.vinted"
      "com.ticketswap.ticketswap"

      # Work and remote play (Intune/Outlook/Teams/AnyConnect/Azure
      # authenticator never made the cut: enrollment and push need Play
      # services)
      "com.valvesoftware.steamlink"
      "com.valvesoftware.android.steam.community"

      # Productivity
      "com.x8bit.bitwarden"
      "md.obsidian"
      "com.github.android"
      "com.openai.chatgpt"
      "com.deepl.mobiletranslator"
      "com.chess"

      # Media
      "com.spotify.music"
      "com.soundcloud.android"
      "tv.twitch.android.app"
      "app.symfonik.music.player" # navidrome client against m920q

      # Hardware companions
      "com.philips.lighting.hue2"
      "com.sony.songpal.mdr"
      "com.garmin.connectiq"
      "com.garmin.android.apps.connectmobile"
      "com.harman.ble.jbllink"
      "com.lenbrook.sovi.bluesound"

      # Banks and finance
      "at.spar.app"
      "com.austrianapps.ventocom.hofer"
      "at.wuestenrot.klickmal.android"

      # Government and health
      "at.digitalerimpfpass.app"
      "at.itsv.mobile.meineoegk"
      "at.valida.vorsorgeportal"

      # Travel, mobility, daily life
      "at.wienerlinien.wienmobillab"
      "at.westbahn.app"
      "at.oebb.ts"
      "de.nextbike"
      "com.airbnb.android"
      "com.rentalcars.handset"
      "at.lieferservice.android"
      "com.mcdonalds.mobileapp"
      "com.app.tgtg"
      "at.energieag.fairteiler"
      "at.is24.android"
      "com.greencopper.novarock"
      "com.plannet.milesandmoreapp"
      "de.avm.android.myfritz2"
      "com.limebike"

      # Services and utilities
      "com.shazam.android"
      "com.duckduckgo.mobile.android"
      "com.overlook.android.fing"
      "com.intsig.camscanner"
      "com.keepa.mobile"
      "io.homeassistant.companion.android" # Obtainium candidate at bench
      "com.otp.octopilauncher"
      "ch.protonmail.android"
      "com.veridonia.app"
      "com.tellm.android.app"
      "at.post.app"

      # Splitting and streaming
      "splid.teamturtle.com.splid"
      "com.tribab.tricount.android"
      "com.Splitwise.SplitwiseMobile"

      # Games (paid titles come through the user's own Play entitlement)
      "com.wizards.mtga"
      "com.playdigious.deadcells.mobile"
    ];

    # Steps no manifest row can express: sign-ins, patcher runs, first-boot
    # grants. `pixel-provision` prints this checklist at the end of `apply`.
    manual = [
      "Sideload Obtainium itself from github.com/ImranR98/Obtainium/releases once, then run `pixel-provision links` and import the bulk obtainium://apps/ link it prints."
      "Aurora Store first run: anonymous session, then install the lane list; updates happen on-device from then on."
      "Play-dependent banking, government and travel apps live in the private space; TF Bank is the exception and runs in the Google user (see googleAccount); the owner's Aurora lane keeps only the apps that stay in this profile."
      "Tailscale: sign in and enroll the 10a on the tailnet; with MagicDNS the fleet resolves pixel-10a like the old pixel-9a did. Keep Use Tailscale DNS settings on: without it the VPN carries no resolvers and MagicDNS names such as m920q.tailf2f0ca.ts.net stop resolving. Each Android user is its own node (owner pixel-10a, private space pixel-10a-private, Google user pixel-10a-google) because Android VPNs are per-user."
      "Immich and Nextcloud: sign in against m920q (album/exam challenges happen inside the app)."
      "UPM runs the patch flows (ReVanced, Morphe, Reseam bundles) and strips the Google dependencies from the patched targets, so patched apps run without Play services: the Morphe-built Maps (org.ungoogled.android.apps.maps) and Car2Go are installed and bench-verified on the 10a. Pin the arm64-v8a asset to keep updates on the Tensor G5 flavor."
      "Porter: start once via its wireless-debugbing flow; the service stops on device restart, so reopen it after a reboot before SteamController talks to the controller."
      "Re-add the remaining PWA shortcuts the 9a had under its webapk stubs, from Vanadium; do not resurrect the Collie bridge PWA (OpenCode runs native now)."
      "OpenCode Mobile: run `opencode pair --url https://m920q.tailf2f0ca.ts.net:8444` on m920q and scan the printed QR; approvals, questions and diffs then arrive in the app, with notifications handled natively."
      "Government-app account sign-ins happen in-app on first use; open items recorded on the bench live as comments next to their lane rows."
    ];
  };

  # The private space is the Play/Google-services profile: the owner stays
  # free of sandboxed Play, and most banking/travel apps that need Play run
  # here. The settings above are shared. Main-profile apps come in through
  # Settings > Security & privacy > Private space > Install available apps
  # (Aegis, Spotify, Telegram, FUTO Keyboard); it copies the APK, not the data.
  privateSpace = {
    lanes = {
      fdroid = [
        "org.fdroid.fdroid"
        "com.aurora.store"
        "com.beemdevelopment.aegis"
      ];

      obtainium = [
        {
          id = "com.tailscale.ipn";
          name = "Tailscale";
          author = "tailscale";
          url = "https://github.com/tailscale/tailscale-android";
        }
        {
          id = "org.futo.inputmethod.latin";
          name = "FUTO Keyboard";
          author = "futo-org";
          url = "https://github.com/futo-org/android-keyboard";
        }
      ];

      # Play-only apps that need sandboxed Google Play. Aurora's anonymous
      # session installs them without a Google account; add the account only
      # if an app insists on Play licensing or Gmail.
      aurora = [
        # Banking and finance
        "at.erstebank.george"
        "de.number26.android"
        "de.traderepublic.app"
        "capital.scalable.droid"
        "com.paypal.android.p2pmobile"
        "de.xcom.flatexat"

        # Government
        "at.gv.oe.app"
        "at.gv.oe.awp.eausweise"

        # Travel, mobility and daily life
        "de.hafas.android.oebb"
        "com.austrian.connector.android"
        "com.ubercab"
        "at.sharetoo.sharing.app"
        "at.willhaben"
        "com.car2go"

        # Services and devices
        "com.x8bit.bitwarden"
        "chipolo.net.v3"
        "com.duolingo"
        "com.spotify.music"
        "org.telegram.messenger"
      ];

      manual = [
        "Install sandboxed Google Play services, Play Store and Android Auto from the GrapheneOS App Store inside the private space. No Google account is required; Aurora's anonymous session serves the Play apps. Add fel.schausberger@gmail.com only if an app insists on Play licensing."
        "Use Settings > Security & privacy > Private space > Install available apps to copy main-profile apps into the space (Aegis, Spotify, Telegram, FUTO Keyboard); it copies the APK, not the app data. The flow omits IMEs and some web builds, so the remaining clones come from the migration commands."
        "Grant Play services an unrestricted battery exception in the private space, and unlock the private space after every reboot: push approvals only arrive while it is unlocked."
        "Banking and government apps re-bind the device. Keep the Pixel 9a available until every app is verified; the Google secondary user stays for TF Bank. SMS and call verification happen in the owner profile; the cross-profile clipboard carries codes."
        "Aegis: import the token export from the Google user. The owner and the private space keep separate copies; either can approve banking logins."
        "Spotify, Telegram, FUTO Keyboard and Aegis are also in the private lane; the owner keeps its working copies. Gmail is not installed in the private space: it needs the Google account, and Proton Mail stays in the owner."
        "Tailscale: the private space is a separate node. Rename it to pixel-10a-private in the admin console (node names follow the phone's global device name, so a second login inherits the owner's), disable key expiry for it and keep Use Tailscale DNS settings on for MagicDNS."
        "UPM is not part of the private lane: sandboxed Google Play covers the patched-away dependencies. Remove it from the private space unless patched apps are still wanted."
        "The out-of-repo privacy lane (~/.config/pixel-provision/private-apps.json) is merged into this profile's Aurora list by pixel-provision."
      ];
    };
  };

  # The Google user is a full secondary user kept for TF Bank, which refuses
  # the private space. It needs Tailscale like the other profiles: an Android
  # VPN is per-user and cannot be shared, so this is a third tailnet node.
  # Play apps come from Aurora's anonymous session, as in the private lane.
  googleAccount = {
    lanes = {
      aurora = [
        "se.tfbank.tfbankmobile.at"
      ];

      manual = [
        "Tailscale: sign in once in the Google user, rename its node to pixel-10a-google in the admin console, disable key expiry for it and keep Use Tailscale DNS settings on. pixel-provision apply google sets always-on VPN; a process the system stops (a backup, a user switch) needs the app opened again, because always-on VPN is a start trigger, not a watchdog."
        "TF Bank: install from the Aurora lane above and enroll in-app. It is the reason this user exists; the private space cannot run it."
      ];
    };
  };

  # Dropped by decision (9a audit plus user sign-off), kept as documentation
  # so a later manifest pass does not silently resurrect them.
  dropped = [
    "app.morphe.android.youtube" # patched YouTube: not reinstated on the 10a
    "app.revanced.android.gms" # microG shim: unused; patched targets strip GMS directly
    "com.abdurazaaqmohammed.AntiSplit" # never reinstalled on the 10a; UPM covers the patch flows
    "app.revanced.manager"
    "app.revanced.manager.flutter"
    "com.cisco.anyconnect.vpn.android.avf"
    "com.azure.authenticator"
    "net.marinits.android.droidotp"
    "com.microsoft.windowsintune.companyportal"
    "com.microsoft.emmx"
    "com.microsoft.office.outlook"
    "com.microsoft.teams"
    "com.mobillium.airalo"
    "gov.dhs.cbp.pspd.mpc"
    "gov.dhs.cbp.esta"
    "com.anthropic.claude"
    "com.lexa.fakegps"
    "org.cromite.cromite" # third Chromium: Vanadium covers the engine natively
    "org.mozilla.fenix" # Play build; F-Droid's fennec fork replaces it
    "com.maxmpz.audioplayer"
    "com.maxmpz.audioplayer.unlock" # no Subsonic streaming; Symfonik is the client
    "moe.shizuku.privileged.api" # superseded by Porter (maintained Shizuku fork)
    "network.loki.messenger" # Session; user sign-off, not in use
    "app.morphe.manager" # dedicated Morphe manager: UPM bundles the Morphe runtime
    "app.reseam.manager" # dedicated Reseam manager: UPM bundles Reseam's runtime; reseam's 0.39.1 separately fixes the Too-many-sessions install failure

    # The privacy lane lives outside this repo: the manifest never carries
    # those ids; pixel-provision merges
    # ~/.config/pixel-provision/private-apps.json (ignored by the repo,
    # user-managed) into the private space's Aurora list at runtime.
  ];
}
