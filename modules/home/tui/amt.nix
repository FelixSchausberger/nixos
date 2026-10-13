{
  config,
  lib,
  pkgs,
  ...
}: let
  # The ME negotiates TLS 1.2 and demands renegotiation without RFC 5746, which
  # OpenSSL 3 refuses by default. amtterm enables it internally; curl needs this
  # config or the handshake to the ME's TLS port fails.
  amtLegacyTls = pkgs.writeText "amt-legacy-tls.cnf" ''
    openssl_conf = openssl_init
    [openssl_init]
    ssl_conf = ssl_sect
    [ssl_sect]
    system_default = system_default_sect
    [system_default_sect]
    Options = UnsafeLegacyRenegotiation
  '';

  # WS-Man Get for AMT_SetupAndConfigurationService: firmware version and
  # provisioning state. amttool speaks the SOAP protocol Intel removed in AMT 9,
  # so it is unreliable here; WS-Man is the supported interface. The ME accepts
  # the relative To header.
  amtInfoRequest = pkgs.writeText "amt-info.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd">
    <s:Header>
    <a:To>/wsman</a:To>
    <w:ResourceURI s:mustUnderstand="true">http://intel.com/wbem/wscim/1/amt-schema/1/AMT_SetupAndConfigurationService</w:ResourceURI>
    <a:ReplyTo><a:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address></a:ReplyTo>
    <a:Action s:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/09/transfer/Get</a:Action>
    <w:MaxEnvelopeSize>65536</w:MaxEnvelopeSize>
    <a:MessageID>uuid:11111111-2222-3333-4444-555555555555</a:MessageID>
    <w:Locale xml:lang="en-US"/>
    <w:OperationTimeout>PT30S</w:OperationTimeout>
    </s:Header>
    <s:Body/>
    </s:Envelope>
  '';

  pwPath = config.sops.secrets."amt/password".path;
  caPath = config.sops.secrets."amt/tls_ca_crt".path;
in {
  home.packages = with pkgs; [
    amtterm
  ];

  sops.secrets."amt/password" = {};
  # The AMT CA certificate (public) verifies the ME's TLS certificate. The ME
  # serves WS-Man and SOL only over TLS (16993 and 16995); its unencrypted
  # listeners answer the host's LMS relay alone, so every client session runs
  # over TLS.
  sops.secrets."amt/tls_ca_crt" = {};

  # Both helpers target the ME at 192.168.178.10 over TLS with the CA. The
  # password never reaches argv: amtterm takes it from AMT_PASSWORD, curl from
  # its stdin config.
  programs.fish.functions = {
    amtinfo = {
      description = "AMT status from m920q over TLS (reads password and CA from sops)";
      body = ''
        if not test -f ${pwPath}
            echo "AMT password not found at ${pwPath}" >&2
            echo "Add it with: sops edit secrets/secrets.yaml  # amt.password" >&2
            return 1
        end
        if not test -f ${caPath}
            echo "AMT CA certificate not found at ${caPath}" >&2
            return 1
        end
        printf 'user = "admin:%s"\n' (cat ${pwPath}) \
          | env OPENSSL_CONF=${amtLegacyTls} ${pkgs.curl}/bin/curl -s -K - \
              --cacert ${caPath} --tls-max 1.2 --ciphers 'DEFAULT@SECLEVEL=1' \
              --digest --data-binary @${amtInfoRequest} \
              -H 'Content-Type: application/soap+xml;charset=UTF-8' \
              https://192.168.178.10:16993/wsman $argv \
          | ${pkgs.gnused}/bin/sed 's/></>\n</g'
      '';
    };
    amtterm-m920q = {
      description = "AMT SOL to m920q over TLS (reads password and CA from sops)";
      body = ''
        if not test -f ${pwPath}
            echo "AMT password not found at ${pwPath}" >&2
            return 1
        end
        if not test -f ${caPath}
            echo "AMT CA certificate not found at ${caPath}" >&2
            return 1
        end
        env AMT_PASSWORD=(cat ${pwPath}) \
          ${pkgs.amtterm}/bin/amtterm -C ${caPath} -u admin 192.168.178.10 $argv
      '';
    };
  };

  programs.bash.initExtra = lib.mkAfter ''
    amtinfo() {
      local pw_file="${pwPath}"
      local ca_file="${caPath}"
      if [[ ! -f "$pw_file" ]]; then
        echo "AMT password not found at $pw_file" >&2
        echo "Add it with: sops edit secrets/secrets.yaml  # amt.password" >&2
        return 1
      fi
      if [[ ! -f "$ca_file" ]]; then
        echo "AMT CA certificate not found at $ca_file" >&2
        return 1
      fi
      printf 'user = "admin:%s"\n' "$(cat "$pw_file")" \
        | OPENSSL_CONF=${amtLegacyTls} ${pkgs.curl}/bin/curl -s -K - \
            --cacert "$ca_file" --tls-max 1.2 --ciphers 'DEFAULT@SECLEVEL=1' \
            --digest --data-binary @${amtInfoRequest} \
            -H 'Content-Type: application/soap+xml;charset=UTF-8' \
            https://192.168.178.10:16993/wsman "$@" \
        | ${pkgs.gnused}/bin/sed 's/></>\n</g'
    }
    amtterm-m920q() {
      local pw_file="${pwPath}"
      local ca_file="${caPath}"
      if [[ ! -f "$pw_file" ]]; then
        echo "AMT password not found at $pw_file" >&2
        return 1
      fi
      if [[ ! -f "$ca_file" ]]; then
        echo "AMT CA certificate not found at $ca_file" >&2
        return 1
      fi
      AMT_PASSWORD="$(cat "$pw_file")" ${pkgs.amtterm}/bin/amtterm -C "$ca_file" -u admin 192.168.178.10 "$@"
    }
  '';
}
