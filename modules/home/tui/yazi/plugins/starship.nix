{inputs, ...}: {
  programs.yazi.plugins.starship = {
    package = "${inputs.yazi-starship}";
    setup = true;
  };
}
