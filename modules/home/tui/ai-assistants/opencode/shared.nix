{
  config,
  lib,
  pkgs,
  ...
}: let
  # Values both the V1 (opencode) and V2 (opencode2) configs need. Rendering them
  # from one place keeps the two harnesses from drifting; the V2 module renders
  # the isolated config from the same attrs this returns.
  sharedBehaviors = config.ai-assistants.behaviors.definitions;

  combinedRules = lib.concatStringsSep "\n\n---\n\n" (
    lib.mapAttrsToList (_name: behavior: "# ${behavior.description}\n\n${behavior.content}") (
      lib.filterAttrs (_n: v: v.enabled) sharedBehaviors
    )
  );

  # Typst authoring skills (local docs mirrors for typst + touying).
  # Upstream: https://github.com/apcamargo/typst-skills
  typstSkillsSrc = pkgs.fetchFromGitHub {
    owner = "apcamargo";
    repo = "typst-skills";
    rev = "93978422d58d4e5c21efe4bfa9f3e6dd9940cf96";
    hash = "sha256-Tmf8xoKNF0wxNvS+av3sOp6Pe0j2MwfeaxrUvlD9VFU=";
  };

  # Merge repo-local skills with the vendored typst skills; the V1 skills
  # option maps attr names to skill directory names, V2 takes the same
  # directories as an ordered path list.
  sharedSkills =
    lib.mapAttrs (name: _: ../skills + "/${name}") (builtins.readDir ../skills)
    // {
      typst-author = "${typstSkillsSrc}/typst-author";
      touying-author = "${typstSkillsSrc}/touying-author";
    };

  model = "github-copilot/gpt-5-mini";

  formatters = {
    nixfmt = {};
    rustfmt = {};
    typstyle = {};
    taplo = {
      command = [
        "taplo"
        "fmt"
        "$FILE"
      ];
      extensions = [".toml"];
    };
  };

  # Canonical ordered permission rules in the native V2 shape. V1 derives its
  # grouped `permission` map from the shell rules; V2 consumes the array as-is.
  permissionRules = [
    {
      action = "shell";
      resource = "git reset*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "git push --force*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "git push -f *";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "git rebase*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "git commit*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "git stash*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "git checkout * -- *";
      effect = "deny";
    }
    {
      action = "edit";
      resource = "*";
      effect = "allow";
    }
  ];

  codeSimplifierAgent = ''
    ---
    description: Simplifies recently modified code while preserving exact behavior
    mode: subagent
    model: ${model}
    permission:
      edit: allow
      bash: deny
    ---

    You are a code simplification specialist.

    Simplify recently modified code for clarity, consistency, and maintainability while preserving exact functionality.

    Rules:
    - Never change behavior, side effects, or outputs.
    - Prefer explicit readable code over compact clever code.
    - Reduce avoidable nesting and duplicated logic.
    - Remove obvious comments and stale debug artifacts.
    - Prefer if/else or switch over nested ternaries.
    - Keep useful abstractions; do not collapse structure just to reduce line count.

    Scope:
    - Focus on files touched in the current change unless the user asks for broader refactoring.

    Workflow:
    1. Identify touched code paths.
    2. Apply small, behavior-preserving simplifications.
    3. Keep naming consistent with repository conventions.
    4. Validate that semantics are unchanged.
    5. Report meaningful simplifications only.
  '';
in {
  inherit
    combinedRules
    sharedSkills
    model
    formatters
    permissionRules
    codeSimplifierAgent
    ;
}
