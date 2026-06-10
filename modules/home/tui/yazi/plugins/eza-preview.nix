{inputs, ...}: {
  home.file.".config/yazi/plugins/eza-preview" = {
    source = inputs.yazi-eza-preview;
    recursive = true;
  };
}
