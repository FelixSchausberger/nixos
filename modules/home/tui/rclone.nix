_: {
  programs.rclone.enable = true;

  sops.secrets = {
    "rclone/client-secret" = {};
    "rclone/token" = {};
  };
}
