{lib}: rec {
  # Convert a single hex character to its decimal value
  hexCharToDec = c: let
    lowerC = lib.toLower c;
    hexChars = lib.stringToCharacters "0123456789abcdef";
    findIndex = ch: list: let
      len = builtins.length list;
      go = idx:
        if idx >= len
        then null
        else if builtins.elemAt list idx == ch
        then idx
        else go (idx + 1);
    in
      go 0;
  in
    findIndex lowerC hexChars;

  # Convert a two-character hex string to decimal (0-255)
  hexToDec = hex: let
    chars = lib.stringToCharacters (lib.toLower hex);
    high = hexCharToDec (builtins.elemAt chars 0);
    low = hexCharToDec (builtins.elemAt chars 1);
  in
    if high == null || low == null
    then throw "Invalid hex string: ${hex}"
    else high * 16 + low;

  # Add # prefix to hex color
  x = v: "#${v}";

  # Convert hex color to CSS rgba with opacity
  # hex: 6-character hex string (without #)
  # opacity: float between 0.0 and 1.0
  rgba = hex: opacity: let
    # Remove # if present
    cleanHex = lib.removePrefix "#" hex;
    # Extract RGB components
    r = hexToDec (lib.substring 0 2 cleanHex);
    g = hexToDec (lib.substring 2 2 cleanHex);
    b = hexToDec (lib.substring 4 2 cleanHex);
  in "rgba(${toString r}, ${toString g}, ${toString b}, ${toString opacity})";

  # Recursively apply x function to all values in an attribute set
  xcolors = colors: lib.mapAttrsRecursive (_path: x) colors;

  # Recursively apply rgba function to all values in an attribute set
  # opacity defaults to 1.0
  rgbaColors = colors: opacity:
    lib.mapAttrsRecursive (_path: v: rgba v opacity) colors;

  # Generate multiple color format variants from a base color set
  # Input: { primary = "1e1e2e"; accent = "cba6f7"; ... }
  # Output: { hex = { primary = "#1e1e2e"; ... }; rgba = { primary = "rgba(...)" }; ... }
  colorVariants = colors: {
    # Original values without modification
    raw = colors;
    # With # prefix
    hex = xcolors colors;
    # As CSS rgba with full opacity
    rgba = rgbaColors colors 1.0;
    # As CSS rgba with 90% opacity
    rgba90 = rgbaColors colors 0.9;
    # As CSS rgba with 80% opacity
    rgba80 = rgbaColors colors 0.8;
    # As CSS rgba with 50% opacity (half transparent)
    rgba50 = rgbaColors colors 0.5;
    # As CSS rgba with 20% opacity (very transparent)
    rgba20 = rgbaColors colors 0.2;
  };
}
