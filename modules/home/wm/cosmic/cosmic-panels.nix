{cosmicLib, ...}: {
  wayland.desktopManager.cosmic.panels = [
    {
      anchor = cosmicLib.cosmic.mkRON "enum" "Bottom";
      anchor_gap = true;
      # autohide = cosmicLib.cosmic.mkRON "optional" {
      #   handle_size = 4;
      #   transition_time = 200;
      #   wait_time = 1000;
      # };
      background = cosmicLib.cosmic.mkRON "enum" "Dark";
      expand_to_edges = true;
      margin = 0;
      name = "Panel";
      opacity = 0.8;
      output = cosmicLib.cosmic.mkRON "enum" "All";
      plugins_center = cosmicLib.cosmic.mkRON "optional" [
        "com.system76.CosmicAppletTime"
      ];
      plugins_wings = cosmicLib.cosmic.mkRON "optional" (cosmicLib.cosmic.mkRON "tuple" [
        [
          # "com.system76.CosmicPanelWorkspacesButton"
          # "com.system76.CosmicPanelAppButton"
          "com.system76.CosmicAppletWorkspaces"
        ]
        [
          "com.system76.CosmicAppletInputSources"
          "com.system76.CosmicAppletStatusArea"
          "com.system76.CosmicAppletTiling"
          "com.system76.CosmicAppletAudio"
          "com.system76.CosmicAppletNetwork"
          "com.system76.CosmicAppletBattery"
          "com.system76.CosmicAppletNotifications"
          "com.system76.CosmicAppletBluetooth"
          "com.system76.CosmicAppletPower"
        ]
      ]);
      size = cosmicLib.cosmic.mkRON "enum" "S";
    }
  ];
}
