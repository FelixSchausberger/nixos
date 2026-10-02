# Audit plan — 2026-10-01 — incremental (user-scoped: nixvim)

- Target: code. Phase 1 only: no code edits, no report, no bookmarks.
- Incremental base: `audit/2026-10-01` exists. `jj diff --from audit/2026-10-01
  --to @` = nixvim `keymaps.nix`/`plugins/default.nix` plus homelab
  caddy/homepage + tests-vm. The homelab delta is outside the requested
  scope; the user scoped this run to the Neovim setup, so the sweep covers
  the whole `modules/home/tui/nixvim/` subtree (full sweep of that subtree).
- Working-copy caveat: `@` is based on a main snapshot from before merged
  PRs #364 (mini.icons), #365 (rustc/cargo/clippy), #366 (overseer
  open_output). Targets below cite the tree as read, with those merged
  deltas accounted for where they change line numbers.
- Files read: `default.nix`, `options.nix`, `autocommands.nix`,
  `keymaps.nix`, `plugins/{default,completion,conform,lsp,opencode,rust,treesitter}.nix`,
  `lua/config/{clipboard,title}.lua`, `lib/treesitter-grammars.nix` (head).
- Signal greps run scoped to the subtree: byte-duplicates (none),
  `vim.fn.system|systemlist|pcall|silent!` (none), state-machine patterns
  (none), provider/clipboard emissions traced through the built
  `home-files` artifact and the nvim wrapper script.

## Candidates

### 1. rustfmt sits outside the rust feature toolset, so `cargo fmt` fails in plain shells

- Target: `modules/home/tui/nixvim/plugins/conform.nix:39-43` and
  `modules/home/profiles/features.nix` rust list (line ~83 as merged by #365)
- Intent question: the code wants the Rust formatter available wherever
  formatting happens. It ships rustfmt only inside nixvim's wrapper PATH
  (`extraPackages`) while the merged #365 set puts `cargo`, `rustc`,
  `clippy` into `home.packages` — `cargo fmt` resolves `cargo-fmt` from
  PATH, which home.path does not contain, so the shell command errors
  ("no such command: fmt") outside nvim. Two homes for one tool, and
  conform.nix's comment ("the Rust toolchain normally comes from
  devShells") is now stale.
- Verification: empirically confirmed — `/nix/store/jpcqlbhkwxwvq507mq0hkacpxbxcdwjj-rustfmt-1.98.1/bin`
  contains `cargo-fmt`; `ls hp-c/bin | grep rustfmt` = absent from
  home.path; post-#365 `hp-d/bin` contains `cargo`, `cargo-clippy`,
  `clippy-driver`, `rustc` but no `cargo-fmt`.
- Fix permission: confirmed-only
- Sketch: add `rustfmt` to the features.nix rust list, drop
  `extraPackages = [pkgs.rustfmt]` from conform.nix (nvim inherits
  home.path), rewrite both comments as single-sourcing.

### 2. `loaded_python_provider = 0` guards a provider nvim no longer has

- Target: `modules/home/tui/nixvim/options.nix:9-13`
- Intent question: the globals block claims to "Disable unused providers"
  (Ruby, Perl, Python 2). Ruby and Perl providers exist and show
  `Disabled (loaded_*=0)` in checkhealth, but there is no "Python 2"
  provider section at all in modern Neovim — the global is consumed by
  nothing and the comment misleads readers into thinking a python2 surface
  still exists.
- Verification: empirically confirmed — `grep -in 'Python 2'` over the
  built checkhealth report returns nothing while the Perl section reports
  the corresponding global as its disable switch; remaining verification at
  execute time: `lua/provider/` in the Neovim runtime ships no python2 file.
- Fix permission: confirmed-only
- Sketch: delete the `loaded_python_provider` line, keep ruby/perl.

### 3. Two icon stacks coexist (nvim-web-devicons + mini.icons)

- Target: `modules/home/tui/nixvim/plugins/default.nix:47-48`
  (`web-devicons.enable`) plus the mini.nvim addition merged in #364
  (`extraPlugins` + `require("mini.icons").setup()`).
- Intent question: both exist to render Nerd Font icons. which-key now
  prefers mini.icons, and fzf-lua auto-detects mini; consumers that
  `require("nvim-web-devicons")` directly (oil, gitsigns, render-markdown,
  …) may not. If every installed consumer accepts mini, web-devicons is a
  second stack for the same primitive; if any hardcodes it, dropping it
  loses glyphs.
- Verification: to do — `rg -l 'nvim-web-devicons'` across the vim pack
  dir store path, check each hit for mini fallback support in its source,
  then an empirical nvim run with web-devicons disabled looking at picker /
  oil / statusline icons.
- Fix permission: report-only (suspected until the consumer list is read)

## Rejected options (verified, not pursuing)

- Expressing the env-aware clipboard purely through nixvim's
  `clipboard.providers`: the Wayland-vs-OSC52 branch depends on runtime
  environment (`WAYLAND_DISPLAY`, `executable("wl-copy")`), which static
  nixvim options cannot evaluate. The current split is load-bearing:
  `providers.wl-copy.enable` injects wl-clipboard into the nvim wrapper PATH
  (hp-c/bin/nvim:5-78), and `lua/config/clipboard.lua` (runs last,
  init.lua:466) sets the explicit `g:clipboard`.
- Replacing `title.lua` with a titlestring template: Neovim's `titlestring`
  does not evaluate `mode()`; the ModeChanged autocmd is the only way to
  expose `nvim [MODE]`, and the niri border rules consume exactly that
  format (`modules/home/wm/niri/default.nix:520`).
- Replacing the conform `format_on_save` function with a table option:
  conform's table form is global; the per-filetype gate that mirrors
  Helix's autoFormat flag requires the function form.
- Curating grammars via `allGrammars`: would rebuild every grammar for
  languages this config never opens; the 33-line list is the cheaper
  constraint.
- Installing fzf-lua's optional media tools (viu/chafa/ueberzugpp):
  previously decided against — zero runtime references, ~820 MB cost.

## Do-not-touch list (re-derived justifications)

- `plugins/lsp.nix` server mapping: derives servers, filetypes, and root
  markers from the shared `editors.*` data so Helix and nvim serve the
  same files from one source; `package = null` prevents a second server
  copy on nvim's PATH. Removing the mapping breaks single-sourcing.
- `lua/config/clipboard.lua` + `options.nix` clipboard pair: justified in
  "Rejected options" above.
- `lua/config/title.lua`: niri border rules match the dynamic title;
  verified at niri/default.nix:520.
- `plugins/default.nix` overseer `component_aliases.default` restatement
  (merged #366): component aliases replace wholesale, so the stock members
  must be restated to add `open_output` — no merge mechanism exists.
- `plugins/rust.nix` `settings.server.cmd` from shared data (merged #362):
  single-sourced store path keeps rustaceanvim health independent of PATH.
- `extraConfigLua` `require("config.*")`: idiomatic runtimepath loading of
  `extraFiles`-shipped Lua; no built-in loads `lua/config/*` implicitly.
- `autocommands.nix` and `keymaps.nix`: declarative, described, match
  nixvim idioms; `<cmd>lua require(...)<cr>` vs `mkRaw` is style-only.
- `smartindent` alongside treesitter indent: coexists without measured
  failure.
- Upstream checkhealth noise with no config lever: blink.cmp's
  unconditional warning, fzf-lua's optional media probe, overseer's
  capability/cwd probes, opencode's store-path git commit.
