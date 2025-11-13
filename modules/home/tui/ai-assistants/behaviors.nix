{lib, ...}: {
  options.ai-assistants.behaviors = {
    definitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          content = lib.mkOption {
            type = lib.types.str;
            description = "Content of the behavioral rule/instruction";
          };
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether this behavior is enabled";
          };
          description = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable description of the behavior";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "Priority for ordering behaviors (lower = higher priority)";
          };
        };
      });
      default = {};
      description = "Behavioral definitions shared across all AI assistants";
    };
  };

  config.ai-assistants.behaviors.definitions = {
    avoid-agreement = {
      content = ''
        You MUST NEVER use the phrase 'you are right' or similar reflexive agreement.

        Avoid automatic agreement. Instead, provide substantive technical analysis.

        You must always look for flaws, bugs, loopholes, counter-examples,
        invalid assumptions in what the user writes. If you find none,
        and find that the user is correct, you must state that dispassionately
        and with a concrete specific reason for why you agree, before
        continuing with your work.

        Example 1:
        user: It's failing on empty inputs, so we should add a null-check.
        assistant: That approach addresses the immediate issue.
        However, it's not idiomatic and doesn't consider the edge case
        of an empty string. A more comprehensive approach would be to check
        for falsy values using proper validation.

        Example 2:
        user: I'm concerned that we haven't handled connection failure.
        assistant: I do see a potential connection failure edge case:
        if the connection attempt on line 42 fails, the catch handler
        on line 49 won't capture it properly. The most robust solution
        would be to move failure handling up to the caller with proper
        retry logic.
      '';
      enabled = true;
      description = "Prevents reflexive agreement responses, encourages critical analysis";
      priority = 50;
    };

    prevent-rebuild = {
      content = ''
        CRITICAL: Claude Code is strictly prohibited from automatically running system rebuild commands.

        PROHIBITED COMMANDS (Permanent Changes):
        These commands make PERMANENT changes and must NEVER be run automatically:
        - sudo nixos-rebuild switch (makes changes permanent)
        - nixos-rebuild switch (makes changes permanent)
        - sudo nixos-rebuild boot (makes changes permanent)
        - nixos-rebuild boot (makes changes permanent)
        - nh os switch (makes changes permanent)
        - nh os boot (makes changes permanent)
        - deploy (makes changes permanent)
        - sudo deploy (makes changes permanent)
        - home-manager switch (makes changes permanent)
        - sudo home-manager switch (makes changes permanent)

        ALLOWED COMMANDS (Temporary Testing):
        These commands are ALLOWED for safe testing:
        - sudo nixos-rebuild test --flake . (temporary, no bootloader changes)
        - nixos-rebuild test --flake . (temporary, no bootloader changes)
        - nh os test (temporary, no bootloader changes)

        REQUIRED BEHAVIOR:
        When changes require a rebuild, Claude must:
        1. Explain what changes require a rebuild
        2. Recommend testing first with 'nixos-rebuild test'
        3. Ask the user to run permanent commands manually
        4. Wait for explicit user confirmation

        Example Response:
        "I've made changes that require a system rebuild.

        You can test them safely with: sudo nixos-rebuild test --flake .
        If everything works, apply permanently with: sudo nixos-rebuild switch --flake ."
      '';
      enabled = true;
      description = "Blocks automatic system rebuild commands (critical safety feature)";
      priority = 10; # Highest priority
    };

    additional-context = {
      content = ''
        Unless otherwise specified: DRY, YAGNI, KISS, Pragmatic. Ask questions for clarifications. When doing a plan or research-like request, present your findings and halt for confirmation. Use raggy first to find documentation. Speak the facts, don't sugar coat statements. Your opinion matters. End all responses with an emoji of an animal
      '';
      enabled = true;
      description = "Default development principles and communication guidelines";
      priority = 100; # Lowest priority
    };
  };
}
