{lib}: let
  inherit (builtins) attrNames filter map pathExists readDir sort;

  importDir = dir:
    if pathExists dir
    then let
      entries = attrNames (readDir dir);
      nixFiles = filter (name: lib.hasSuffix ".nix" name && !lib.hasSuffix ".nixd" name) entries;
      sorted = sort (a: b: a < b) nixFiles;
    in
      map (name: dir + "/${name}") sorted
    else [];

  importDefaultAnd = {
    defaultDir,
    specificDir,
  }:
    importDir defaultDir ++ importDir specificDir;
in {
  inherit importDir importDefaultAnd;

  importHost = hostName:
    importDefaultAnd {
      defaultDir = ./../hosts/default;
      specificDir = ./../hosts/${hostName};
    };

  importProfile = profileName:
    importDefaultAnd {
      defaultDir = ./../home/profiles/default;
      specificDir = ./../home/profiles/${profileName};
    };
}
