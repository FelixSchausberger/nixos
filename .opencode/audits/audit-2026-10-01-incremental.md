# Audit report — 2026-10-01 — incremental (user-scoped: nixvim)

- **Mode**: incremental, scoped by the user to the Neovim setup; plan (with
  verification sources, rejected options, do-not-touch derivations) in
  `plan-2026-10-01-incremental.md` (restored alongside this report — it was
  approved for execution but did not survive in the tree).
- **Scope**: full sweep of `modules/home/tui/nixvim/` plus the rust toolchain
  in `home/profiles/features.nix`; homelab deltas since the base were out of
  the requested scope.
- **Fixes applied** (Phase 2, confirmed-only): findings 1 and 2 in PR #369
  and PR #372, both merged. Suspected finding 3 stays report-only.
- **Out of audit scope**: (a) the completion workflow change (PR #374) was a
  direct user request after the audit — `super-tab` preset replaced with
  `default` so suggestions only hint until `<C-y>` is pressed; (b) a live
  `E5113 module 'mini.icons' not found` report was investigated and shown to
  be a transient generation skew (nvim opened mid-activation: the new
  `init.lua` had landed while the profile still pointed at the pre-#364 pack
  dir); the current pack dir ships `mini.nvim` and the require succeeds.

Ranked by likelihood-of-production-breakage x complexity-cost:

## 1. rustfmt sits outside the rust feature toolset, so `cargo fmt` fails in plain shells

- Location: `modules/home/tui/nixvim/plugins/conform.nix:39-43` and
  `modules/home/profiles/features.nix` (rust list)
- Current approach: rustfmt was shipped only inside nixvim's wrapper PATH
  (`extraPackages`) while #365 puts `cargo`, `rustc`, `clippy` into
  `home.packages`. `cargo fmt` resolves `cargo-fmt` from PATH, which
  home.path did not contain, so formatting errored with "no such command:
  fmt" everywhere outside nvim. Two homes for one tool, and conform's
  comment about devShells being the toolchain source was stale.
- Why it's the hard way: a tool whose home is chosen per-consumer drifts the
  moment a second consumer (the shell) appears; nothing fails until someone
  runs `cargo fmt`.
- Established alternative: single-home the tool with the rest of the Rust
  toolchain in `features.nix` — home.path feeds both shells and the nvim
  wrapper. Verified: the rustfmt store output contains `cargo-fmt`;
  `hp-c/bin` lacked it, post-fix `hp-fixa/bin` has `rustfmt` + `cargo-fmt`
  and conform health reports `rustfmt ready`.
- Migration: applied — `rustfmt` added to the features rust list,
  `extraPackages` dropped from conform.nix, both comments rewritten as
  single-sourcing. | Risk: low
- Verdict: confirmed

## 2. `loaded_python_provider = 0` guards a provider nvim no longer has

- Location: `modules/home/tui/nixvim/options.nix:9-13`
- Current approach: the globals block claims to disable unused providers
  (Ruby, Perl, Python 2). Ruby and Perl exist — their checkhealth sections
  report the corresponding global as the disable switch — but modern
  Neovim has no Python 2 provider section at all: no checkhealth target
  consumes the global, and the comment advertises a surface that is gone.
- Why it's the hard way: a dead knob documents itself as live; the next
  reader tunes it and believes Python 2 was considered.
- Established alternative: delete the line, keep ruby/perl. Verified: the
  built checkhealth report has no "Python 2" section while Perl's section
  shows its global; the built `init.lua` post-fix has zero occurrences.
- Migration: applied — line deleted, remaining globals untouched. | Risk:
  low
- Verdict: confirmed

## 3. Two icon stacks coexist (nvim-web-devicons + mini.icons)

- Location: `modules/home/tui/nixvim/plugins/default.nix:47-48`
  (`web-devicons.enable`) plus the mini.nvim addition merged in #364
  (`extraPlugins` + `require("mini.icons").setup()`)
- Current approach: both stacks render Nerd Font icons for the same
  primitive. which-key prefers mini.icons and fzf-lua auto-detects it, but
  consumers that `require("nvim-web-devicons")` directly (oil, gitsigns,
  render-markdown, …) may not. Keeping both doubles maintenance for one
  job; dropping web-devicons risks silent glyph loss if any consumer
  hardcodes it.
- Why it's the hard way: duplicate primitives diverge — settings applied to
  one stack silently miss the other.
- Established alternative: mini.icons as the single stack, but only if every
  installed consumer falls back; that consumer list has not been read.
- Migration: TBD verification — `rg -l 'nvim-web-devicons'` over the vim
  pack dir, read each hit for mini fallback support, then an empirical run
  with `web-devicons.enable = false` checking picker, oil, and statusline
  glyphs; drop the flag only if clean. | Risk: med
- Verdict: suspected

## Rejected options (verified, not pursuing)

- Expressing the env-aware clipboard purely through nixvim's
  `clipboard.providers`: the Wayland-vs-OSC52 branch depends on runtime
  environment (`WAYLAND_DISPLAY`, `executable("wl-copy")`), which static
  nixvim options cannot evaluate. The current split is load-bearing:
  `providers.wl-copy.enable` injects wl-clipboard into the nvim wrapper
  PATH, and `lua/config/clipboard.lua` (runs last) sets the explicit
  `g:clipboard`.
- Replacing `title.lua` with a titlestring template: `titlestring` does not
  evaluate `mode()`; the ModeChanged autocmd is the only way to expose
  `nvim [MODE]`, and the niri border rules consume exactly that format
  (`modules/home/wm/niri/default.nix:520`).
- Replacing the conform `format_on_save` function with a table option:
  conform's table form is global; the per-filetype gate mirroring Helix's
  autoFormat flag requires the function form.
- Curating grammars via `allGrammars`: would rebuild every grammar for
  languages this config never opens; the explicit list is the cheaper
  constraint.
- Installing fzf-lua's optional media tools (viu/chafa/ueberzugpp): zero
  runtime references, ~820 MB cost.

## Do-not-touch list (re-derived justifications)

- `plugins/lsp.nix` server mapping: derives servers, filetypes, and root
  markers from the shared `editors.*` data so Helix and nvim serve the
  same files from one source; `package = null` prevents a second server
  copy on nvim's PATH.
- `lua/config/clipboard.lua` + `options.nix` clipboard pair: the
  env-aware branch cannot be expressed as static nixvim options (see
  rejected options).
- `lua/config/title.lua`: niri border rules match the dynamic title format
  (`niri/default.nix:520`).
- `plugins/default.nix` overseer `component_aliases.default` restatement:
  component aliases replace wholesale, so stock members must be restated
  to add `open_output` — no merge mechanism exists.
- `plugins/rust.nix` `settings.server.cmd` from shared data: single-sourced
  store path keeps rustaceanvim health independent of PATH.
- `extraConfigLua` `require("config.*")`: idiomatic runtimepath loading of
  `extraFiles`-shipped Lua; nothing loads `lua/config/*` implicitly.
- `autocommands.nix` and `keymaps.nix`: declarative, described, match
  nixvim idioms; `<cmd>lua require(...)<cr>` vs `mkRaw` is style-only.
- `smartindent` alongside treesitter indent: coexists without measured
  failure.
- Upstream checkhealth noise with no config lever: blink.cmp's
  unconditional warning, fzf-lua's optional media probes, overseer's
  capability/cwd probes, opencode's store-path git commit line.

Baseline for the next incremental run: the `audit/2026-10-01` bookmark
exists at `main`; run `jjwork` first so the diff base sees it.
