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
    jjwork-first = {
      content = ''
        CRITICAL: Always rebase the working copy onto main before starting any work.

        Before making any changes, run:
        ```bash
        jjwork
        ```
        This fetches from remote and rebases the working-copy commit onto main@origin. It does not create a new commit.

        This prevents the working copy from diverging into orphan branches that create messy merge histories and lost files. Every session MUST start with `jjwork`.

        If `jjwork` refuses with undescribed working-copy changes, do NOT bypass it with JJWORK_ALLOW_WIP=1. Report the listed files to the user and halt: the previous work was never described and must be described first.
      '';
      enabled = true;
      description = "Rebase onto main with jjwork before starting any work";
      priority = 5; # Above prevent-rebuild: ordering invariant for all sessions
    };

    parallel-agents = {
      content = ''
        Assume several opencode agents share this jj repository in parallel. Never share a working copy: each agent works in its own `ocws` workspace. The primary checkout (/per/etc/nixos) is reserved for the user and the comin reconciler — never edit it, and never run jj mutations there.

        Start of work, always:
        ```bash
        ocws ls
        ```
        This is read-only. Halt and report if the primary or any other workspace shows a described `@` you do not own, or an undescribed non-empty `@` (an unclaimed working copy is a hazard to every session).

        For isolated work, create a workspace with `ocws <task>` (or `ocws tab <task>`). It creates `<base>/nixos-ws-<task>`, claims it with a change description, starts opencode rooted there, and reclaims finished workspaces. The base is `$OCWS_BASE`, else the parent of the current workspace when writable, else `$XDG_DATA_HOME/ocws` (default `~/.local/share/ocws`), else `/tmp/opencode`.

        Claim discipline: start work with `jj new main@origin`, describe immediately, then edit — a described commit at `@` silently absorbs every edit made in its working copy, and the description is the ownership claim. Validate and `jjpush` promptly; the shorter the window an unpushed commit sits at `@`, the smaller the pollution risk from a parallel session. Rebasing never loses commits (recover with `jj op log` / `jj undo`); the loss vectors are undescribed WIP and `jj new`/abandon, which the `jjwork` guard blocks.

        Integration runs from the workspace itself: `jjwork`, then `jjpush`. Nothing pushes background work. After the PR merges, release the workspace:
        ```bash
        ocws done <task>
        ```
        It refuses while unmerged work remains, doubling as a close-out check; `ocws gc` (also run automatically by `ocws <task>`) reclaims finished workspaces idle past `OCWS_GC_AGE`. See the jj-workspaces skill for the full workflow and concurrency hazards.

        `ocws ls` reports the jj claim, not whether a session is live in the directory, so a workspace can silently hold a second agent. Before settling into one, check the session database (`~/.local/share/opencode/opencode.db`, `session_v2.directory`) for a session rooted there, and treat such a workspace as taken even when its `@` is empty; never start or move a session into one. jj snapshots the whole tree, so a file another session wrote rides into your commit unnoticed - if files you did not write appear in your working copy, leave for a fresh workspace, report them, and remove them with `rip` (restorable) rather than committing them.

        Scratch output never reaches a commit: planning and audit files under `.opencode/` are ignored, and `jj diff --stat` before `jjpush` is what proves it.
      '';
      enabled = true;
      description = "Isolate parallel agents in jj workspaces via the ocws launcher";
      priority = 6; # Just after jjwork-first, before starting edits
    };

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
        CRITICAL: AI agents are strictly prohibited from automatically running system rebuild commands.

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
        When changes require a rebuild, the agent must:
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

    safe-deletion = {
      content = ''
        In your shell environment, `rm` is a shim that forwards to `rip` (rip2):
        deletions go to a graveyard and stay restorable.

        - Use `rip` directly: `rip <path>...` (directories need no -r)
        - List what can be restored: `rip -s`
        - Restore: `rip -u` (last deletion), `rip -u <path>`, or `rip -su` (everything deleted from the current directory)
        - The shim strips all rm-style flags; never rely on rm semantics
        - `sudo rm` bypasses the shim and deletes irreversibly — avoid it
        - Permanent deletion is a deliberate act: `rip -d`
      '';
      enabled = true;
      description = "rm is shimmed to rip; deletions restorable from the graveyard";
      priority = 30;
    };

    prefer-gh-cli-for-github = {
      content = ''
        For GitHub data — issues, pull requests, releases, file contents, commit
        history — prefer the `gh` CLI (`gh api`, `gh pr view`, `gh issue view`) or
        raw.githubusercontent.com URLs via Bash instead of webfetch on github.com
        pages. Rendered GitHub pages embed tens of thousands of tokens of
        navigation chrome around the actual content; the CLI and raw endpoints
        return dense text. Use webfetch on github.com only for content `gh`
        cannot retrieve.
      '';
      enabled = true;
      description = "Prefer gh CLI / raw URLs over webfetch for GitHub content";
    };

    additional-context = {
      content = ''
        Unless otherwise specified: DRY, YAGNI, KISS, Pragmatic. Ask questions for clarifications. When doing a plan or research-like request, present your findings and halt for confirmation. Use raggy first to find documentation. Speak the facts, don't sugar coat statements. Your opinion matters. End all responses with an emoji of an animal
      '';
      enabled = true;
      description = "Default development principles and communication guidelines";
      priority = 100; # Lowest priority
    };

    clean-diff-before-push = {
      content = ''
        Before `jj describe`, and again before `jjpush`, run `jj diff --stat` and `jj status` and confirm every path belongs to the concern you are landing. Files you did not touch for that concern - foreign work, editor droppings, scratch notes - are removed with `rip` (restorable via `rip -u`) or split out with `jj split`, never committed because they happened to be present. The push is the last cheap checkpoint: after a squash-merge a stray file is history.
      '';
      enabled = true;
      description = "Verify the diff holds only the stated concern before pushing";
      priority = 10;
    };

    no-orphan-processes = {
      content = ''
        Anything started for a test or verification is cleaned up before you move on. `pkill -f <pattern>` kills the process itself, while `kill $PID` only kills a wrapper such as `nix run` and leaves the real process - and its port - alive; confirm with `ps` and `ss` afterwards. Never test against a port a deployed service uses: a leftover collector test held 127.0.0.1:8888, the deployed OTel collector's default telemetry port, so the unit could not start, hit systemd's start limit, and paged through the ServiceFailed alert. Test servers get a private port and a command line a pattern can match.
      '';
      enabled = true;
      description = "Clean up test processes and keep off deployed ports";
      priority = 20;
    };
  };
}
