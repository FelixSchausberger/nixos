{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  vaultPath = defaults.paths.obsidianVault;
  claudeSkillsDir = "${vaultPath}/.claude/skills";

  # Extract skills from obsidian-skills flake input
  obsidianSkillsSource = "${inputs.obsidian-skills}/skills";
in {
  config = lib.mkIf config.programs.claude-code.enable {
    # Copy obsidian-skills to vault's .claude directory
    home.activation.installObsidianSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Only install if vault is mounted
      if [ -d "${vaultPath}" ]; then
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
