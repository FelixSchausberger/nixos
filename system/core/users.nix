{
  users = {
    mutableUsers = false;
    users = {
      root = {
        # Enable root account for emergency access
        hashedPassword = "$6$NCvaiR40U202pKeY$4MpPXCDHvMksfQ.V.O3fNR5L/UqtWBMxrbtGCuYjY/nDSqQOu8BqwCmZmp7f/5NMFnkvwqE34aSoPpE2SwqPw/";
      };

      "schausberger" = {
        isNormalUser = true;
        description = "Felix Schausberger";
        extraGroups = ["fuse" "networkmanager" "input" "video" "wheel" "dialout"];
        hashedPassword = "$6$NCvaiR40U202pKeY$4MpPXCDHvMksfQ.V.O3fNR5L/UqtWBMxrbtGCuYjY/nDSqQOu8BqwCmZmp7f/5NMFnkvwqE34aSoPpE2SwqPw/";
      };
    };
  };
}
