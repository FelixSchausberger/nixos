sessionTarget: {
  inputs,
  pkgs,
  ...
}: {
  config = {
    # Add cthulock package to user environment
    home.packages = [inputs.cthulock.packages.${pkgs.system}.default];

    # Create Slint style configuration
    home.file.".config/cthulock/style.slint".text = ''
      import { HorizontalBox, VerticalBox, Rectangle, Text, Button, LineEdit } from "std-widgets.slint";

      export component MainWindow inherits Window {
          width: 100%;
          height: 100%;
          background: #1e1e2e;

          VerticalBox {
              alignment: center;
              spacing: 20px;

              // Clock display
              Text {
                  text: @tr("{}:{}", hour, minute);
                  font-size: 72px;
                  color: #cdd6f4;
                  font-family: "JetBrainsMono Nerd Font";
                  font-weight: 700;
              }

              // User greeting
              Text {
                  text: @tr("Hi there, {}", user);
                  font-size: 18px;
                  color: #cdd6f4;
                  font-family: "JetBrainsMono Nerd Font";
              }

              // Password input field
              Rectangle {
                  width: 300px;
                  height: 50px;
                  background: #313244;
                  border-radius: 12px;
                  border-width: 2px;
                  border-color: #89b4fa;

                  LineEdit {
                      width: 100%;
                      height: 100%;
                      placeholder-text: "Password...";
                      color: #cdd6f4;
                      font-family: "JetBrainsMono Nerd Font";
                      font-size: 14px;
                      input-type: password;
                  }
              }
          }
      }
    '';

    # Ensure the program is available in the session
    systemd.user.services.cthulock-ready = {
      Unit = {
        Description = "Make cthulock available for session";
        After = [sessionTarget];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/true";
        RemainAfterExit = true;
      };
      Install.WantedBy = [sessionTarget];
    };
  };
}
