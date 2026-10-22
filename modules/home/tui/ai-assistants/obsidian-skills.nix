{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  # Terminal tooling follows the vault option, which the DAV-mount host
  # module overrides to its mount point (modules/system/homelab/vault-mount.nix).
  vaultPath = config.modules.home.tui.vault.path;
  claudeSkillsDir = "${vaultPath}/.claude/skills";

  # Extract skills from obsidian-skills flake input
  obsidianSkillsSource = "${inputs.obsidian-skills}/skills";
in {
  config = lib.mkIf config.programs.claude-code.enable {
    # Copy obsidian-skills to vault's .claude directory
    home.activation.installObsidianSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Only reach vault content through a live mount so a plain directory
      # can never silently shadow the WebDAV mount with divergent files.
      # The mount service may still be starting at activation, so give it
      # a bounded settle window instead of failing the first switch.
      for i in $(seq 1 10); do
        if ${pkgs.util-linux}/bin/mountpoint -q "${vaultPath}"; then
          break
        fi
        sleep 1
      done
      if ${pkgs.util-linux}/bin/mountpoint -q "${vaultPath}"; then
        $DRY_RUN_CMD mkdir -p "${claudeSkillsDir}"

        # Copy skills from flake input
        if [ -d "${obsidianSkillsSource}" ]; then
          # Remove old skills to ensure clean state
          $DRY_RUN_CMD rm -rf "${claudeSkillsDir}"/*

          # Copy new skills
          $DRY_RUN_CMD cp -r "${obsidianSkillsSource}"/. "${claudeSkillsDir}/"

          echo "Installed Obsidian skills to ${claudeSkillsDir}"
        else
          echo "Warning: Obsidian skills source not found at ${obsidianSkillsSource}" >&2
        fi
      else
        echo "Warning: Obsidian vault not mounted at ${vaultPath}, skipping skills installation" >&2
      fi
    '';
  };
}
