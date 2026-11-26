# Vendored from nixpkgs master (pkgs/by-name/oc/octoprint) because the
# nixos-unstable channel still carries OctoPrint 1.11.8 while master moved to
# 2.0.1. Drop this directory and use pkgs.octoprint once the channel catches up.
{
  pkgs,
  stdenv,
  callPackage,
  lib,
  fetchFromGitHub,
  python3,
  replaceVars,
  nix-update-script,
  nixosTests,
  # To include additional plugins, pass them here as an overlay.
  packageOverrides ? _self: _super: {},
}: let
  py = python3.override {
    self = py;
    packageOverrides = lib.foldr lib.composeExtensions (_self: _super: {}) [
      # Built-in dependency
      (self: _super: {
        octoprint-filecheck = self.buildPythonPackage rec {
          pname = "OctoPrint-FileCheck";
          version = "2025.7.23";
          format = "setuptools";

          src = fetchFromGitHub {
            owner = "OctoPrint";
            repo = "OctoPrint-FileCheck";
            rev = version;
            hash = "sha256-Y3JVfbe+bZz2t65OqdjvVVqTSa0VUPoCaxvE+zQ+Qts=";
          };
          doCheck = false;
        };
      })

      # Built-in dependency
      (self: _super: {
        octoprint-firmwarecheck = self.buildPythonPackage rec {
          pname = "OctoPrint-FirmwareCheck";
          version = "2025.7.23";
          format = "setuptools";

          src = fetchFromGitHub {
            owner = "OctoPrint";
            repo = "OctoPrint-FirmwareCheck";
            rev = version;
            hash = "sha256-QPchpyeotB5IKbfES74CJlhw3sz8Q1df/+n5dpbrHSs=";
          };
          doCheck = false;
        };
      })

      (self: _super: {
        octoprint-pisupport = self.buildPythonPackage rec {
          pname = "OctoPrint-PiSupport";
          version = "2025.7.23";
          format = "setuptools";

          src = fetchFromGitHub {
            owner = "OctoPrint";
            repo = "OctoPrint-PiSupport";
            rev = version;
            hash = "sha256-bXjRGxIwi+UnVts2HO9viOJqa2AmZ/CL7wuoyzRbAEw=";
          };

          # requires octoprint itself during tests
          doCheck = false;
          postPatch = ''
            substituteInPlace octoprint_pi_support/__init__.py \
              --replace /usr/bin/vcgencmd ${self.pkgs.libraspberrypi}/bin/vcgencmd
          '';
        };
      })

      # OctoPrint 2.0 extracts GCODE thumbnails with this pure-Python tool.
      # Without it the local storage logs an ImportError at every start and
      # the bundled health check reports the tool as unavailable.
      (self: _super: {
        gcode-thumbnail-tool = self.buildPythonPackage rec {
          pname = "gcode-thumbnail-tool";
          version = "0.1.4";
          format = "pyproject";

          src = fetchFromGitHub {
            owner = "OctoPrint";
            repo = "gcode-thumbnail-tool";
            rev = version;
            hash = "sha256-X5b9bvQGRLUQyfaQARKEfFdOteOiVZydCwZQrUhzxTs=";
          };

          nativeBuildInputs = with self; [setuptools];
          propagatedBuildInputs = with self; [pillow];

          doCheck = false;
        };
      })

      (self: super: {
        octoprint = self.buildPythonPackage rec {
          pname = "OctoPrint";
          version = "2.0.1";
          format = "setuptools";

          src = fetchFromGitHub {
            owner = "OctoPrint";
            repo = "OctoPrint";
            rev = version;
            hash = "sha256-VNKc+bsWd5Pjt7s6k1kiWuYPnoxRxKeFIH74mztF+n8=";
          };

          propagatedBuildInputs = with self;
            [
              argon2-cffi
              babel
              blinker
              cachelib
              click
              colorlog
              emoji
              feedparser
              filetype
              flask
              flask-babel
              flask-assets
              flask-login
              flask-limiter
              frozendict
              gcode-thumbnail-tool
              libpass
              limits
              markdown
              markupsafe
              netaddr
              octoprint-filecheck
              octoprint-firmwarecheck
              packaging
              pathvalidate
              pip
              pkginfo
              psutil
              pylru
              pyserial
              pytz
              pyyaml
              regex
              requests
              sarge
              semantic-version
              sentry-sdk
              setuptools
              tornado
              unidecode
              watchdog
              websocket-client
              werkzeug
              wheel
              wrapt
              zeroconf
              zipstream-ng
              pydantic
              html-sanitizer
            ]
            ++ lib.optionals stdenv.hostPlatform.isDarwin [py.pkgs.appdirs]
            ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [octoprint-pisupport];

          nativeCheckInputs = with self; [
            ddt
            mock
            time-machine
            pytestCheckHook
          ];

          patches = [
            # substitute pip and let it find out, that it can't write anywhere
            (replaceVars ./pip-path.patch {
              pip = "${self.pip}/bin/pip";
            })

            # hardcore path to ffmpeg and hide related settings
            (replaceVars ./ffmpeg-path.patch {
              ffmpeg = "${pkgs.ffmpeg-headless}/bin/ffmpeg";
            })
          ];

          postPatch = let
            ignoreVersionConstraints = [
              "Babel"
              "cachelib"
              "Click"
              "colorlog"
              "emoji"
              "limits"
              "markdown"
              "netaddr"
              "psutil"
              "PyYAML"
              "requests"
              "sarge"
              "sentry-sdk"
              "watchdog"
              "websocket-client"
              "wrapt"
              "zeroconf"
              "Flask-Login"
              "werkzeug"
              "flask"
              "Flask-Limiter"
              "blinker"
            ];
          in ''
            sed -r -i \
              ${lib.concatStringsSep "\n" (
              map (e: ''-e 's@${e}[<>=!]+.*@${e}",@g' \'') ignoreVersionConstraints
            )}
              setup.py
          '';

          preCheck = ''
            export HOME=$(mktemp -d)
            rm pytest.ini
          '';

          disabledTests =
            [
              "test_check_setup" # Why should it be able to call pip?
            ]
            ++ lib.optionals stdenv.hostPlatform.isDarwin ["test_set_external_modification"];
          disabledTestPaths = [
            "tests/http_api" # requires a live OctoPrint server; excluded by upstream pytest.ini
            "tests/test_octoprint_setuptools.py" # fails due to distutils and python3.12
          ];

          passthru = {
            inherit (self) python;
            updateScript = nix-update-script {};
            tests = {
              plugins = (callPackage ./plugins.nix {}) super self;
              inherit (nixosTests) octoprint;
            };
          };

          meta = {
            homepage = "https://octoprint.org/";
            description = "Snappy web interface for your 3D printer";
            mainProgram = "octoprint";
            license = lib.licenses.agpl3Only;
            maintainers = with lib.maintainers; [
              WhittlesJr
              gador
            ];
          };
        };
      })
      (callPackage ./plugins.nix {})
      packageOverrides
    ];
  };
in
  with py.pkgs;
    toPythonApplication octoprint
