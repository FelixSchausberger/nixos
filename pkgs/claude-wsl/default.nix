{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "claude-wsl";
  version = "1.2.6";

  src = fetchFromGitHub {
    owner = "fullstacktard";
    repo = "claude-wsl";
    rev = "bda7379e4e7010f0cc9e3ae3cdaa99f2623f0bfc"; # Latest commit with v1.2.6
    hash = "sha256-6pCSqkPEHyU4DTyUNVhUAYp8t1T40Gi00bLIHH8usro=";
  };

  npmDepsHash = "sha256-jmyTXJWGKTsayIeT5/tnKvZlM04XkR8yVlon844sJCA=";

  # No build script - package consists of scripts only
  dontNpmBuild = true;

  patches = [
    ./notify-paths.patch
  ];

  # Don't run the postinstall script that modifies .bashrc
  # We'll handle integration declaratively through NixOS modules
  postPatch = ''
        # Remove postinstall script from package.json if it exists
        substituteInPlace package.json \
          --replace-warn '"postinstall":' '"postinstall-disabled":'

        # Patch notify.sh to add fish shell support and enhance notification messages
        substituteInPlace templates/notify/notify.sh \
          --replace-warn 'if [[ "$proc_name" =~ ^(bash|zsh)$ ]]; then' 'if [[ "$proc_name" =~ ^(bash|zsh|fish)$ ]]; then' \
          --replace-warn 'for pid in $(pgrep -u "$USER" "bash|zsh" 2>/dev/null); do' 'for pid in $(pgrep -u "$USER" -E "bash|zsh|fish" 2>/dev/null); do'

        # Enhance notification messages with event types and timestamps
        # Add timestamp variable at the start of notification section
        substituteInPlace templates/notify/notify.sh \
          --replace-warn 'if [ "$HOOK_EVENT" = "Stop" ] || [ "$HOOK_EVENT" = "Notification" ]; then' \
            'TIMESTAMP=$(date +"%H:%M:%S")
    if [ "$HOOK_EVENT" = "Stop" ] || [ "$HOOK_EVENT" = "Notification" ]; then'

        # Enhance title to include event type
        substituteInPlace templates/notify/notify.sh \
          --replace-warn '-Title "$FOLDER_NAME"' \
            '-Title "$FOLDER_NAME [$HOOK_EVENT]"'

        # Enhance notification messages with better context
        substituteInPlace templates/notify/notify.sh \
          --replace-warn 'NOTIFICATION_MESSAGE="Waiting for your input"' \
            'NOTIFICATION_MESSAGE="Claude needs permission • $TIMESTAMP"' \
          --replace-warn 'NOTIFICATION_MESSAGE="Task completed"' \
            'NOTIFICATION_MESSAGE="Claude finished • $TIMESTAMP"'

        # Add timestamp to permission messages
        substituteInPlace templates/notify/notify.sh \
          --replace-warn 'NOTIFICATION_MESSAGE="$HOOK_MESSAGE"' \
            'NOTIFICATION_MESSAGE="$HOOK_MESSAGE • $TIMESTAMP"'

        # Add timestamp to response preview
        substituteInPlace templates/notify/notify.sh \
          --replace-warn 'NOTIFICATION_MESSAGE="$PREVIEW"' \
            'NOTIFICATION_MESSAGE="$PREVIEW • $TIMESTAMP"'

        # Add debug logging for PowerShell variables
        substituteInPlace templates/notify/notify.sh \
          --replace-warn 'log "Calling send-notification.ps1 for $HOOK_EVENT event..."' \
            'log "PowerShell helper variables: WSLPATH=$CLAUDE_WSL_WSLPATH, POWERSHELL=$CLAUDE_WSL_POWERSHELL"
            log "Calling send-notification.ps1 for $HOOK_EVENT event..."'
  '';

  # Install notification scripts to share directory
  # These will be symlinked to ~/.local/share/claude-wsl/ by home-manager
  postInstall = ''
    mkdir -p $out/share/claude-wsl
    cp -r templates/notify/* $out/share/claude-wsl/
    chmod +x $out/share/claude-wsl/*.sh
  '';

  # Package metadata
  meta = with lib; {
    description = "Visual notifications for Claude Code in WSL";
    homepage = "https://github.com/fullstacktard/claude-wsl";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
  };
}
