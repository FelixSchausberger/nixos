{config, ...}: {
  # Attach a TUI client to the shared server instead of letting bare `opencode`
  # start its own throwaway instance, so the TUI, the web UI and every other
  # client share one session store. The launcher resolves the registered
  # service (URL and password) itself.
  programs.fish.functions.oc = {
    description = "Attach to the shared opencode server (same sessions as the web UI)";
    body = ''
      opencode2 $argv
    '';
  };

  # Exported for gh and the git credential helper; the opencode launcher unsets
  # it for its own process tree, because opencode synthesizes a github-copilot
  # provider from a PAT that the Copilot API rejects (see v2.nix).
  # home.sessionVariables cannot read file contents - it stores the secret path.
  programs.fish.loginShellInit = ''
    if test -f ${config.sops.secrets."github/token".path}
      set -gx GITHUB_TOKEN (cat ${config.sops.secrets."github/token".path})
    end
  '';

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
