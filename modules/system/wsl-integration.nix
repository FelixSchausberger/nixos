{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}: {
  config = lib.mkIf config.modules.system.wsl-integration.enable {
    # Merged systemd configuration
    systemd = {
      # WSL Windows certificate import capability
      services.wsl-cert-setup = {
        description = "WSL Windows certificate integration setup";
        # Disabled at boot - certificates set up via timer instead
        wantedBy = lib.mkForce [];
        path = with pkgs; [openssl coreutils];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };

        script = ''
                            echo "=== WSL Windows Certificate Integration Setup ==="

                            # Only proceed if we're actually in WSL
                            if [ -d "/mnt/c/Windows" ]; then
                              echo "WSL environment detected, setting up Windows certificate integration..."

                              # Ensure /usr/local/bin directory exists
                              mkdir -p /usr/local/bin

                              # Create Windows certificate extraction script
                              cat > /usr/local/bin/import-windows-certs << 'WIN_CERT_EOF'
          #!/bin/bash
          echo "Importing Windows certificate store into WSL..."

          # Create temporary directory for Windows certificates
          TEMP_CERT_DIR=$(mktemp -d)
          WIN_CERT_COUNT=0

          # Extract certificates from Windows certificate store using PowerShell
          POWERSHELL_PATH=""
          for ps_path in "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
                         "/mnt/c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe"; do
            if [ -x "$ps_path" ]; then
              POWERSHELL_PATH="$ps_path"
              break
            fi
          done

          # Also check for powershell.exe in PATH if not found yet
          if [ -z "$POWERSHELL_PATH" ] && command -v powershell.exe >/dev/null 2>&1; then
            POWERSHELL_PATH=$(command -v powershell.exe)
          fi

          if [ -n "$POWERSHELL_PATH" ]; then
            echo "Found PowerShell at: $POWERSHELL_PATH"
            echo "Extracting certificates from Windows certificate store..."

            # Create a more robust PowerShell script file
            WIN_CERT_SCRIPT="/tmp/extract-win-certs.ps1"
            cat > "$WIN_CERT_SCRIPT" << 'PS_SCRIPT'
          \$StoreToDir = "C:\temp\all-certificates"
          \$CertExtension = "pem"
          \$InsertLineBreaks = 1

          # Create output directory
          if (Test-Path \$StoreToDir) {
              Remove-Item \$StoreToDir -Recurse -Force
          }
          New-Item \$StoreToDir -ItemType directory -Force | Out-Null

          Write-Host "Searching for certificates..."
          \$certCount = 0

          # Get certificates from specific stores
          \$stores = @("Root", "CA", "AuthRoot", "TrustedPublisher")
          foreach (\$storeName in \$stores) {
              try {
                  \$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(\$storeName, "LocalMachine")
                  \$store.Open("ReadOnly")

                  foreach (\$cert in \$store.Certificates) {
                      if (\$cert.NotAfter -gt (Get-Date)) {
                          \$name = "\$(\$cert.Thumbprint)--\$(\$storeName)" -replace '[\\W]', '_'
                          if (\$name.Length -gt 150) { \$name = \$name.Substring(0, 150) }

                          \$path = "\$StoreToDir\\\$name.\$CertExtension"
                          if (-not (Test-Path \$path)) {
                              \$oPem = New-Object System.Text.StringBuilder
                              [void]\$oPem.AppendLine("-----BEGIN CERTIFICATE-----")
                              [void]\$oPem.AppendLine([System.Convert]::ToBase64String(\$cert.RawData, \$InsertLineBreaks))
                              [void]\$oPem.AppendLine("-----END CERTIFICATE-----")

                              \$oPem.toString() | Out-File -FilePath \$path -Encoding ASCII
                              \$certCount++
                          }
                      }
                  }
                  \$store.Close()
              } catch {
                  Write-Warning "Failed to process store \$storeName: \$_"
              }
          }

          Write-Host "Extracted \$certCount certificates to \$StoreToDir"
          PS_SCRIPT

            # Execute the PowerShell script
            "$POWERSHELL_PATH" -ExecutionPolicy Bypass -File "$WIN_CERT_SCRIPT" 2>/dev/null || true
            rm -f "$WIN_CERT_SCRIPT"

            # Copy certificates from Windows temp to WSL temp
            if [ -d "/mnt/c/temp/all-certificates" ]; then
              mkdir -p "/tmp/all-certificates"
              cp /mnt/c/temp/all-certificates/*.pem /tmp/all-certificates/ 2>/dev/null || true
              rm -rf "/mnt/c/temp/all-certificates" 2>/dev/null || true
            fi

            # Process extracted PEM certificates
            if [ -d "/tmp/all-certificates" ]; then
              for cert_file in /tmp/all-certificates/*.pem; do
                if [ -f "$cert_file" ] && openssl x509 -in "$cert_file" -inform PEM -noout 2>/dev/null; then
                  cp "$cert_file" "$TEMP_CERT_DIR/" 2>/dev/null
                  WIN_CERT_COUNT=$((WIN_CERT_COUNT + 1))
                fi
              done
              rm -rf "/tmp/all-certificates" 2>/dev/null || true
            fi

            if [ "$WIN_CERT_COUNT" -gt 0 ]; then
              echo "✅ Extracted $WIN_CERT_COUNT certificates from Windows"

              # Create enhanced certificate bundle with Windows certificates
              ENHANCED_CERT_BUNDLE="/etc/ssl/certs/ca-bundle-enhanced.crt"
              mkdir -p /etc/act-certificates

              # Start with NixOS certificates
              cp "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" "$ENHANCED_CERT_BUNDLE"

              # Append Windows certificates
              cat "$TEMP_CERT_DIR"/*.pem >> "$ENHANCED_CERT_BUNDLE" 2>/dev/null || true
              chmod 644 "$ENHANCED_CERT_BUNDLE"

              echo "✅ Windows certificates added to enhanced certificate bundle"
              echo "Enhanced certificate bundle available at: $ENHANCED_CERT_BUNDLE"

              # Also create backup in act-certificates for compatibility
              cp "$ENHANCED_CERT_BUNDLE" "/etc/act-certificates/ca-bundle-with-windows.crt"

              # Update environment to use enhanced bundle
              export SSL_CERT_FILE="$ENHANCED_CERT_BUNDLE"
              export CURL_CA_BUNDLE="$ENHANCED_CERT_BUNDLE"
              export NIX_SSL_CERT_FILE="$ENHANCED_CERT_BUNDLE"
              export GIT_SSL_CAINFO="$ENHANCED_CERT_BUNDLE"
              export NODE_EXTRA_CA_CERTS="$ENHANCED_CERT_BUNDLE"
            else
              echo "⚠️  No valid certificates extracted from Windows"
            fi
          else
            echo "⚠️  PowerShell not available at $POWERSHELL_PATH"
            echo "Available PowerShell locations:"
            find /mnt/c -name "powershell.exe" 2>/dev/null | head -3 || echo "No PowerShell found"
          fi

          rm -rf "$TEMP_CERT_DIR"
          echo "Windows certificate import completed"
          WIN_CERT_EOF
                            chmod +x /usr/local/bin/import-windows-certs

                            echo "✅ Windows certificate import script created at /usr/local/bin/import-windows-certs"
                            echo "Run 'sudo /usr/local/bin/import-windows-certs' to import Windows certificates"
                            else
                              echo "⚠️  Not in WSL environment (/mnt/c/Windows not found)"
                              echo "WSL certificate integration skipped"
                            fi

                            echo "✅ WSL certificate integration setup completed"
        '';
      };

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
          ExecStart = "/usr/local/bin/import-windows-certs";
        };

        # Only run if we're in WSL and have PowerShell
        unitConfig = {
          ConditionPathExists = ["/mnt/c/Windows" "/usr/local/bin/import-windows-certs"];
        };
      };

      # WSL-specific tmpfiles for enhanced certificate bundle
      tmpfiles.rules = [
        # WSL certificate integration directory
        "d /etc/act-certificates 0755 root root - -"
      ];
    };

    # Merged environment configuration
    environment = {
      # WSL-specific environment packages
      systemPackages = with pkgs; [
        # WSL utilities
        wslu # WSL utilities for integration
        powershell # PowerShell for WSL operations
      ];

      # Run certificate import after system activation
      # DISABLED: Causes system rebuild to hang due to PowerShell detection issues
      # system.activationScripts.wsl-cert-import = {
      #   text = ''
      #     # Import Windows certificates after NixOS rebuild
      #     if [ -d "/mnt/c/Windows" ] && [ -x "/usr/local/bin/import-windows-certs" ]; then
      #       echo "Running Windows certificate import after rebuild..."
      #       /usr/local/bin/import-windows-certs || true
      #     fi
      #   '';
      #   deps = ["etc"];
      # };

      # SSL/TLS certificate environment variables are managed by modules.system.ssl
      # Enhanced bundle symlink is created automatically when modules.system.ssl.bundle.useEnhanced = true
    };

    # WSL-specific shell aliases for certificate management
    home-manager.users.${hostConfig.user} = {
      programs.fish.shellAliases = {
        import-win-certs = "sudo /usr/local/bin/import-windows-certs";
        check-win-certs = "ls -la /etc/ssl/certs/ca-bundle* && echo 'Certificate bundle info:' && wc -l /etc/ssl/certs/ca-bundle* 2>/dev/null";
        refresh-certs = "sudo systemctl start wsl-cert-refresh.service";
        cert-status = "systemctl status wsl-cert-refresh.timer wsl-cert-refresh.service";
      };
    };
  };

  options.modules.system.wsl-integration = {
    enable = lib.mkEnableOption "WSL Windows integration features";
  };
}
