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

  # The fine-grained PAT is exported as GH_UPDATE_TOKEN for the `update` flow
  # only. tools/scripts/update-system.sh dispatches the lock workflow with it
  # because Actions dispatch needs a token the gh keyring OAuth token cannot
  # supply (that token carries `repo`, not `workflow`, scope). Every other gh
  # call uses the keyring: gh prefers GITHUB_TOKEN/GH_TOKEN over hosts.yml, so
  # exporting the PAT under either name shadowed the keyring in every shell
  # and made third-party-repo operations fail with "Resource not accessible
  # by personal access token". The git credential helper, nix access-tokens
  # and the opencode launcher read the secret file directly, not the
  # environment.
  # home.sessionVariables cannot read file contents - it stores the secret path.
  programs.fish.loginShellInit = ''
    if test -f ${config.sops.secrets."github/token".path}
      set -gx GH_UPDATE_TOKEN (cat ${config.sops.secrets."github/token".path})
    end
  '';

  sops.secrets = {
    "ollama/api-key" = {};
    "github/token" = {};
  };
}
