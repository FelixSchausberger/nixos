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

  # Render in priority order (lower first), with the attribute name as the
  # tie-breaker so the output is deterministic. Iterating the attrset directly
  # would sort alphabetically and silently ignore the priority option.
  orderedBehaviors =
    builtins.sort (
      a: b:
        a.priority
        < b.priority
        || (a.priority == b.priority && a.name < b.name)
    ) (lib.mapAttrsToList (name: behavior: {
        inherit name;
        inherit (behavior) priority content description;
      })
      (lib.filterAttrs (_n: v: v.enabled) sharedBehaviors));

  combinedRules = lib.concatStringsSep "\n\n---\n\n" (
    map (behavior: "# ${behavior.description}\n\n${behavior.content}") orderedBehaviors
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

  # OpenCode Go subscription model for both primary agents: DeepSeek V4.1
  # Flash 1017 at the max reasoning variant. Planning uses the same model
  # because agentic traffic is ~96% cache reads and GLM's cache-read price is
  # 87x higher, making a heavy GLM session cost 26x more. The root default is
  # the same model without a variant because the V2 catalog default cannot
  # retain one; the primary agents below select theirs explicitly. Hidden
  # maintenance agents and subagents inherit the session model.
  model = "opencode-go/deepseek-v4.1-flash";
  agents = {
    build.model = "${model}#max";
    plan.model = "${model}#max";
  };

  # Port of the shared OpenCode server: the ai-assistants.opencode managed
  # service (modules/home/tui/ai-assistants/opencode/opencode.nix). It binds loopback
  # only; Tailscale Serve terminates TLS in front of it. Consumers: the `oc`
  # function, the zellij-web seed pane, the nixvim integration and the homepage
  # card monitor.
  webPort = 4096;

  # Absolute store paths so formatting does not depend on the agent PATH.
  # Alejandra is the repository formatter (treefmt.toml); nixfmt is not
  # installed and would fight it. Typst formatting is omitted: typstyle is not
  # part of the harness, and an empty custom entry cannot run.
  formatters = {
    alejandra = {
      command = ["${pkgs.alejandra}/bin/alejandra" "$FILE"];
      extensions = [".nix"];
    };
    rustfmt = {
      command = ["${pkgs.rustfmt}/bin/rustfmt" "$FILE"];
      extensions = [".rs"];
    };
    taplo = {
      command = ["${pkgs.taplo}/bin/taplo" "fmt" "$FILE"];
      extensions = [".toml"];
    };
  };

  # Quota policy, rendered as <config-root>/opencode-quota/settings.jsonc (the
  # path the v6 plugin reads). The provider list is not shared with this
  # source: it is host- and registry-specific, so opencode.nix pins it to the
  # Go subscription. The plugin's settings tabs save into this file, so the
  # read-only store symlink rejects their writes: change the policy here.
  quotaSettings = {
    version = 6;
    # One line under the message box and at the bottom of home. v6 keeps
    # session tokens in the sidebar and toasts, not on this line.
    sidebar.show = false;
    sidebar.sessionTokens = true;
    statusLine = {
      show = true;
      home = true;
      withSidebar = true;
    };
    toast = {
      show = true;
      resetNotice = "weekly";
      sessionTokens = true;
    };
    words = {
      percent = "left";
      detail = "summary";
      sessionTokens = "current";
    };
  };

  # Canonical ordered permission rules in the native V2 shape. V1 derives its
  # grouped `permission` map from the shell rules; V2 consumes the array as-is.
  # The trailing edit rule denies the primary checkout: rules resolve by last
  # match, so it overrides the wildcard allow only for /per/etc/nixos paths.
  # Empirically (scratch-config probes, 2026-09-21) the edit resource is the
  # literal path string the model supplies: absolute paths match this rule,
  # location-relative paths bypass it and stay allowed - but a session whose cwd
  # is an `ocws` workspace resolves relative paths there, not in the primary.
  # The rule is defence in depth, not a boundary; working in a workspace is the
  # real boundary. V1 cannot express path-scoped edit rules (its permission
  # schema is a per-tool map), so the guard is V2-only there.
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
    # Permanent system changes. The global behavior states the same rule; this
    # is the enforcement layer, so a model slip cannot switch a host. Patterns
    # use whole-value wildcards and tolerate options before the subcommand;
    # `nixos-rebuild test` and `nh os test` remain allowed.
    {
      action = "shell";
      resource = "nixos-rebuild *switch*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "sudo nixos-rebuild *switch*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "nixos-rebuild *boot*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "sudo nixos-rebuild *boot*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "nh os *switch*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "sudo nh os *switch*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "nh os *boot*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "sudo nh os *boot*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "home-manager *switch*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "sudo home-manager *switch*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "deploy*";
      effect = "deny";
    }
    {
      action = "shell";
      resource = "sudo deploy*";
      effect = "deny";
    }
    {
      action = "edit";
      resource = "*";
      effect = "allow";
    }
    {
      action = "edit";
      resource = "/per/etc/nixos/*";
      effect = "deny";
    }
    # The LSP MCP server exposes write-capable tools whose permission action
    # is `nix-language-server_<tool>`, not `edit`, so the guard above does not
    # cover them. Deny the writes and keep the read/navigation tools
    # (definition, references, hover, diagnostics).
    {
      action = "nix-language-server_edit_file";
      resource = "*";
      effect = "deny";
    }
    {
      action = "nix-language-server_rename_symbol";
      resource = "*";
      effect = "deny";
    }
  ];

  # The permissions array appends the primary-checkout edit deny after this
  # agent's own edit allow: agent rules are appended after global rules and the
  # last match wins, so without it the subagent's allow would bypass the global
  # guard (see permissionRules above).
  codeSimplifierBody = ''
    You are a code simplification specialist.

    Simplify recently modified code for clarity, consistency, and maintainability while preserving exact functionality.

    Rules:
    - Never change behavior, side effects, or outputs.
    - Prefer explicit readable code over compact clever code.
    - Reduce avoidable nesting and duplicated logic.
    - Prefer if/else or switch over nested ternaries.
    - Keep useful abstractions; do not collapse structure just to reduce line count.
    - Remove debug artifacts: unconditional console.log/debugger, bare print(), and
      commented-out code. Keep logs behind a debug guard, levelled logger calls, and
      console.error/warn.

    Language guidelines:
    - JavaScript/TypeScript: ES modules; `function` over arrow functions; explicit
      return types on top-level functions; avoid try/catch when it adds nothing.
    - Python: PEP 8; type hints; list comprehensions when they read more clearly;
      context managers for resources.

    Scope:
    - Focus on files touched in the current change unless the user asks for broader refactoring.
    - Skip when the user wants the exact structure preserved, or the code is already clean.

    Workflow:
    1. Identify touched code paths.
    2. Apply small, behavior-preserving simplifications.
    3. Keep naming consistent with repository conventions.
    4. Validate that semantics are unchanged.
    5. Report meaningful simplifications only.
  '';

  codeSimplifierAgent = ''
    ---
    description: Simplifies recently modified code while preserving exact behavior
    mode: subagent
    model: ${model}
    permissions:
      - action: edit
        resource: "*"
        effect: allow
      - action: shell
        resource: "*"
        effect: deny
      - action: edit
        resource: "/per/etc/nixos/*"
        effect: deny
    ---

    ${codeSimplifierBody}
  '';
in {
  inherit
    combinedRules
    sharedSkills
    agents
    model
    webPort
    formatters
    quotaSettings
    permissionRules
    codeSimplifierAgent
    ;
}
