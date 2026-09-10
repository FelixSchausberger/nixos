# Safe deletion for AI tool shells. `rm` is replaced by a shim forwarding to
# rip2, so anything an assistant removes lands in a graveyard and can be
# restored. Interactive shells keep the real rm; rip2 is installed alongside
# so the user can restore from the same graveyard.
{
  pkgs,
  config,
  lib,
  ...
}: let
  # Persistent graveyard shared by AI shells and interactive restores. The
  # default /tmp/graveyard-$USER would be wiped on every reboot.
  graveyard = "${config.xdg.dataHome}/graveyard";

  # rm shim: strips rm-style flags because rip's flag set differs (-d
  # means "permanently delete", not --dir) and forwards the operands
  # non-interactively (-f avoids prompts hanging AI tool calls). Everything
  # after `--` is treated as an operand, matching `rm -- -foo` semantics.
  #
  # rm semantics the shim must not break (verified against rip2 0.9.6):
  #   - `rm -f` on missing paths is a silent no-op (exit 0); rip's -f only
  #     means non-interactive and errors on ENOENT.
  #   - a mix of existing and missing operands removes the existing ones and
  #     exits 1; rip aborts on the first missing operand, which would drop
  #     the deletions entirely, so existing/missing are partitioned here.
  #   - bare `rm` (no operands) is a usage error (exit 1), not rip's
  #     interactive prompt.
  # Broken symlinks count as existing (-L).
  rmShim = pkgs.writeShellScriptBin "rm" ''
    force=0
    operands=()
    seenDoubleDash=0
    for arg in "$@"; do
      if [[ $seenDoubleDash -eq 1 ]]; then
        operands+=("$arg")
      else
        case $arg in
          --) seenDoubleDash=1 ;;
          -*)
            for ((i = 1; i < ''${#arg}; i++)); do
              case ''${arg:i:1} in f|F) force=1 ;; esac
            done
            ;;
          *) operands+=("$arg") ;;
        esac
      fi
    done
    if [ "''${#operands[@]}" -eq 0 ]; then
      echo "rm: missing operand" >&2
      echo "Try 'rm --help' for more information." >&2
      exit 1
    fi
    existing=()
    anyMissing=0
    for p in "''${operands[@]}"; do
      if [ -e "$p" ] || [ -L "$p" ]; then
        existing+=("$p")
      else
        anyMissing=1
        [ "$force" -eq 1 ] || echo "rm: cannot remove '$p': No such file or directory" >&2
      fi
    done
    if [ "''${#existing[@]}" -eq 0 ]; then
      [ "$force" -eq 1 ] && exit 0
      exit 1
    fi
    if ${pkgs.rip2}/bin/rip -f -- "''${existing[@]}"; then
      exit "$anyMissing"
    fi
    exit $?
  '';

  shimPackage = pkgs.symlinkJoin {
    name = "ai-safe-rm";
    paths = [rmShim pkgs.rip2];
  };

  # Wraps an assistant package so its process (and every shell it spawns)
  # resolves `rm` to the rip shim. Prefixed PATH keeps the shim scoped to the
  # wrapped tool; RIP_GRAVEYARD pins the graveyard so deletions made by the
  # assistant are restorable from the user's interactive `rip -u`.
  wrapWithSafeRm = pkg:
    pkgs.symlinkJoin {
      name = "${pkg.name}-safe-rm";
      paths = [pkg];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        for exe in $out/bin/*; do
          wrapProgram "$exe" \
            --prefix PATH : "${shimPackage}/bin" \
            --set RIP_GRAVEYARD "${graveyard}"
        done
      '';
      meta = pkg.meta or {};
    };
in {
  options.ai-assistants.safeRm = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "PATH-prefixable package providing the rip2-backed `rm` shim and `rip`";
    };

    wrap = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
      description = "Function wrapping an assistant package so its spawned shells use the rm shim";
    };
  };

  config = {
    ai-assistants.safeRm = {
      package = shimPackage;
      wrap = wrapWithSafeRm;
    };

    home.packages = [pkgs.rip2];
    home.sessionVariables.RIP_GRAVEYARD = graveyard;
  };
}
