{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "s3://magazino-nix-binary-cache?endpoint=https://storage.googleapis.com&profile=gcp"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "gcp-bucket:p0OfsD9+oKLrXbcFyk5Mi1sWHjQbTRfE92XOjHdw/Ho="
    ];
  };
}
