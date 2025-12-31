{...}: {
  imports = [
    ./ghostty.nix # Fast, feature-rich, and cross-platform terminal emulator
    # ./wezterm.nix # GPU-accelerated cross-platform terminal emulator and multiplexer
  ];

  # home.packages = with pkgs; [
  #   warp-terminal # Rust-based terminal with AI
  # ];
}
