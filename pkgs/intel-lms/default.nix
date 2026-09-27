# Intel LMS (Local Manageability Service): proxies /dev/mei0 to loopback
# HTTP 16992 / TLS 16993 so the AMT stack can reach the ME from the host
# (see the AMT block in hosts/m920q). Upstream ships an Ubuntu-jammy deb only
# (rgl/lms-binaries), so the deb is unpacked and wrapped in an FHS
# environment supplying its library closure - the native replacement for the
# docker image the AMT relay used before it moved to a systemd service.
{
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
  buildFHSEnv,
  ace,
  xercesc,
}: let
  version = "2550.0.0";

  # LMS was built against Debian's exact library versions. Two of its C++
  # dependencies are ABI-incompatible with the nixpkgs versions (xerces-c
  # 3.3 renamed the versioned xercesc_3_2 namespace, ACE versions its
  # symbols per release), so both are rebuilt at the exact versions Debian
  # ships - their nixpkgs recipes carry no patches, only src/version change.
  ace706 = ace.overrideAttrs (_old: {
    version = "7.0.6";
    src = fetchurl {
      url = "https://download.dre.vanderbilt.edu/previous_versions/ACE-7.0.6.tar.bz2";
      hash = "sha256-SgzX2khR92n9388z9mPrpK+tgk7+/59Z8TTEZA7oAhY=";
    };
  });

  xerces32 = xercesc.overrideAttrs (_old: {
    version = "3.2.4";
    src = fetchurl {
      # archive.apache.org, not mirror://apache: mirrors only carry the
      # current release.
      url = "https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.2.4.tar.gz";
      hash = "sha256-PY7Bx/lOOP7g5Mpa0eHZ2yPL86ELumJva0r6Le2v5as=";
    };
  });

  # Remaining NEEDED drift is soname-only, where the ABI is stable:
  # Debian's libACE-7.0.6.so is upstream 7.0.6 under Debian's dash naming,
  # and libxml2.so.2 vs nixpkgs' libxml2.so.16 keeps the classic API LMS
  # calls. The m920q converge probe exercises both end to end.
  deb = stdenv.mkDerivation {
    pname = "intel-lms-deb";
    inherit version;
    src = fetchurl {
      url = "https://github.com/rgl/lms-binaries/releases/download/v0.0.20251226/lms-2550.0.0-ubuntu-22.04.deb";
      hash = "sha256-RkqxxJnVBklzVsudBXMYzxQW4w86yWdLUgTaMx0CAKE=";
    };
    dontUnpack = true;
    nativeBuildInputs = [dpkg patchelf];
    installPhase = ''
      runHook preInstall
      dpkg-deb -x $src deb
      # Debian layout (usr/bin) does not match what buildEnv links into the
      # FHS root (top-level bin/): keep the binary and the D-Bus policy, drop
      # the Debian systemd unit and udev rules (the NixOS unit and the host
      # udev own those, /dev/mei0 exists without help) and the logrotate/
      # rsyslog snippets (journald service).
      install -Dm755 deb/usr/bin/lms $out/bin/lms
      install -Dm644 deb/etc/dbus-1/system.d/com.intel.amt.lms.conf \
        $out/etc/dbus-1/system.d/com.intel.amt.lms.conf
      patchelf \
        --replace-needed libACE-7.0.6.so libACE.so.7.0.6 \
        --replace-needed libxml2.so.2 libxml2.so.16 \
        $out/bin/lms
      runHook postInstall
    '';
  };
in
  buildFHSEnv {
    pname = "intel-lms";
    inherit version;
    # Full NEEDED list (objdump): libACE, libnl-3, libnl-route-3,
    # glib/gio/gobject, xerces-c, libcurl, libxml2, libidn2, libstdc++,
    # libgcc_s, libc. The last two and the toolchain basics come from the
    # FHS base; includeClosures pulls each listed library's own transitive
    # deps (zlib under libxml2, openssl under curl, pcre under glib, ...) so
    # no .so is missed.
    targetPkgs = pkgs: [
      deb
      ace706
      xerces32
      pkgs.libnl
      pkgs.glib
      pkgs.curl
      pkgs.libxml2
      pkgs.libidn2
    ];
    includeClosures = true;
    runScript = "lms";
  }
