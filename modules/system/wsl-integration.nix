{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}: let
  # Build import-windows-certs as a proper nix-store derivation.
  # The script extracts certificates from the Windows certificate store via
  # PowerShell and merges them into a NixOS-managed bundle.
  importWindowsCerts = pkgs.writeShellScript "import-windows-certs" ''
    set -euo pipefail

    TEMP_CERT_DIR=$(mktemp -d)
    WIN_CERT_COUNT=0

    # Locate powershell.exe via well-known paths or PATH
    POWERSHELL_PATH=""
    for ps_path in "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
                   "/mnt/c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe"; do
      if [ -x "$ps_path" ]; then
        POWERSHELL_PATH="$ps_path"
        break
      fi
    done
    if [ -z "$POWERSHELL_PATH" ] && command -v powershell.exe >/dev/null 2>&1; then
      POWERSHELL_PATH=$(command -v powershell.exe)
    fi

    if [ -z "$POWERSHELL_PATH" ]; then
      echo "powershell.exe not found; skipping Windows certificate import" >&2
      exit 0
    fi

    WIN_CERT_SCRIPT=$(mktemp --suffix=.ps1)
    cat > "$WIN_CERT_SCRIPT" << 'PS_SCRIPT'
    $StoreToDir = "C:\temp\all-certificates"
    $CertExtension = "pem"
    $InsertLineBreaks = 1

    if (Test-Path $StoreToDir) {
        Remove-Item $StoreToDir -Recurse -Force
    }
    New-Item $StoreToDir -ItemType directory -Force | Out-Null

    $certCount = 0
    $stores = @("Root", "CA", "AuthRoot", "TrustedPublisher")
    foreach ($storeName in $stores) {
        try {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, "LocalMachine")
            $store.Open("ReadOnly")

            foreach ($cert in $store.Certificates) {
                if ($cert.NotAfter -gt (Get-Date)) {
                    $name = "$($cert.Thumbprint)--$($storeName)" -replace '[\W]', '_'
                    if ($name.Length -gt 150) { $name = $name.Substring(0, 150) }

                    $path = "$StoreToDir\$name.$CertExtension"
                    if (-not (Test-Path $path)) {
                        $oPem = New-Object System.Text.StringBuilder
                        [void]$oPem.AppendLine("-----BEGIN CERTIFICATE-----")
                        [void]$oPem.AppendLine([System.Convert]::ToBase64String($cert.RawData, $InsertLineBreaks))
                        [void]$oPem.AppendLine("-----END CERTIFICATE-----")
                        $oPem.toString() | Out-File -FilePath $path -Encoding ASCII
                        $certCount++
                    }
                }
            }
            $store.Close()
        } catch {
            Write-Warning "Failed to process store $storeName: $_"
        }
    }

    Write-Host "Extracted $certCount certificates to $StoreToDir"
    PS_SCRIPT

    "$POWERSHELL_PATH" -ExecutionPolicy Bypass -File "$WIN_CERT_SCRIPT" 2>/dev/null || true
    rm -f "$WIN_CERT_SCRIPT"

    if [ -d "/mnt/c/temp/all-certificates" ]; then
      mkdir -p "/tmp/all-certificates"
      cp /mnt/c/temp/all-certificates/*.pem /tmp/all-certificates/ 2>/dev/null || true
      rm -rf "/mnt/c/temp/all-certificates" 2>/dev/null || true
    fi

    if [ -d "/tmp/all-certificates" ]; then
      for cert_file in /tmp/all-certificates/*.pem; do
        if [ -f "$cert_file" ] && ${pkgs.openssl}/bin/openssl x509 -in "$cert_file" -inform PEM -noout 2>/dev/null; then
          cp "$cert_file" "$TEMP_CERT_DIR/"
          WIN_CERT_COUNT=$((WIN_CERT_COUNT + 1))
        fi
      done
      rm -rf "/tmp/all-certificates" 2>/dev/null || true
    fi

    if [ "$WIN_CERT_COUNT" -gt 0 ]; then
      ENHANCED_CERT_BUNDLE="/etc/ssl/certs/ca-bundle-enhanced.crt"
      mkdir -p /etc/act-certificates

      cp "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" "$ENHANCED_CERT_BUNDLE"
      cat "$TEMP_CERT_DIR"/*.pem >> "$ENHANCED_CERT_BUNDLE" 2>/dev/null || true
      chmod 644 "$ENHANCED_CERT_BUNDLE"

      cp "$ENHANCED_CERT_BUNDLE" "/etc/act-certificates/ca-bundle-with-windows.crt"
    fi

    rm -rf "$TEMP_CERT_DIR"
  '';
in {
  options.modules.system.wsl-integration = {
    enable = lib.mkEnableOption "WSL Windows integration features";
  };

  config = lib.mkIf config.modules.system.wsl-integration.enable {
    systemd = {
      # Automatic certificate refresh timer
      timers.wsl-cert-refresh = {
        description = "Automatic Windows certificate refresh for WSL";
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
          Unit = "wsl-cert-refresh.service";
        };
        wantedBy = ["timers.target"];
        after = ["network.target"];
      };

      services.wsl-cert-refresh = {
        description = "Refresh Windows certificates in WSL";
        after = ["network.target"];
        path = with pkgs; [openssl coreutils];

        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = "${importWindowsCerts}";
        };

        unitConfig = {
          ConditionPathExists = "/mnt/c/Windows";
        };
      };

      tmpfiles.rules = [
        "d /etc/act-certificates 0755 root root - -"
      ];
    };

    environment.systemPackages = with pkgs; [
    ];

    home-manager.users.${hostConfig.user} = {
      programs.fish.shellAliases = {
        import-win-certs = "sudo ${importWindowsCerts}";
        refresh-certs = "sudo systemctl start wsl-cert-refresh.service";
        cert-status = "systemctl status wsl-cert-refresh.timer wsl-cert-refresh.service";
      };
    };
  };
}
