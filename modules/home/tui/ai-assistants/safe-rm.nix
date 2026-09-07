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

  # rm shim: strips all rm-style flags because rip's flag set differs (-d
  # means "permanently delete", not --dir) and forwards the operands
  # non-interactively (-f avoids prompts hanging AI tool calls). Everything
  # after `--` is treated as an operand, matching `rm -- -foo` semantics.
  rmShim = pkgs.writeShellScriptBin "rm" ''
    operands=()
    seenDoubleDash=0
    for arg in "$@"; do
      if [[ $seenDoubleDash -eq 1 ]]; then
        operands+=("$arg")
      else
        case $arg in
          --) seenDoubleDash=1 ;;
          -*) ;;
          *) operands+=("$arg") ;;
        esac
      fi
    done
    exec ${pkgs.rip2}/bin/rip -f -- "''${operands[@]}"
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
