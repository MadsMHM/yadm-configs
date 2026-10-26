# Neovim → oxlint + oxfmt

One-time upgrade to make oxc work across all services. Written 2026-07-28.

**Starting state:** Neovim v0.12.3 (fine), LazyVim 2025-11-01, nvim-lspconfig 2026-01-08 —
both ~6–9 months stale. `lsp/oxlint.lua` and `lsp/oxfmt.lua` do not exist yet in that pin, so
oxc cannot work until step 2.

**The idea:** replace the biome-vs-prettier config-file detection hack with conform's
`stop_after_first`, which picks the first formatter whose **binary actually resolves**. That was
the real bug — the old hack checked whether a config *file* existed, so biome won on Prettier
projects where biome happened to be installed. Availability-based ordering also carries you
through the mixed week while the biome services move to oxc, and needs no edit afterwards.

---

## 1. Snapshot, so you can roll back

```bash
cp -r ~/.config/nvim ~/.config/nvim.bak-$(date +%F)
cp ~/.config/nvim/lazy-lock.json ~/lazy-lock.json.bak
```

`lazy-lock.json` is the real rollback for plugins — `:Lazy restore` replays it exactly.

---

## 2. Update plugins

```vim
:Lazy sync
```

Then confirm the oxc servers landed:

```bash
ls ~/.local/share/nvim/lazy/nvim-lspconfig/lsp/ | grep ox
# want: oxfmt.lua  oxlint.lua
```

This is a ~9 month LazyVim jump, so skim the breaking changes before moving on:

```vim
:LazyVim news
:checkhealth lazy
```

---

## 3. Drop the two formatter extras

```vim
:LazyExtras
```

Disable **`formatting.prettier`** and **`formatting.biome`** (or delete those two lines from
`~/.config/nvim/lazyvim.json`).

The prettier extra does `table.insert(opts.formatters_by_ft[ft], "prettier")` for every supported
filetype, so it re-adds Prettier regardless of what your own config says. Removing beats
overriding — merge order between extras and `lua/plugins/*.lua` isn't guaranteed, which is part of
why the old hack was unreliable.

**Keep** `linting.eslint` and `lang.svelte`. After the oxc migration, ESLint is the *only* source
of Svelte template diagnostics — oxlint cannot parse templates at all.

Leave prettier/biome installed in Mason. They stay as fallbacks for repos that haven't migrated,
and they can never beat oxfmt because of the ordering in step 4. Prune them once every service is
on oxc.

---

## 4. Replace `lua/plugins/formatting.lua`

```lua
-- Formatter priority: oxfmt > biome > prettier, resolved per project by which
-- binary actually exists. conform skips unavailable formatters and stop_after_first
-- takes the first that resolves, so no config-file sniffing is needed.
--
-- from_node_modules() searches node_modules/.bin upward from the buffer, so each
-- repo gets its own pinned version. Do NOT install oxfmt globally — that would make
-- it "available" everywhere and it would win in repos that haven't migrated yet.
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      for _, ft in ipairs({
        "javascript", "javascriptreact", "typescript", "typescriptreact",
        "svelte", "json", "jsonc", "css", "scss", "less",
        "html", "yaml", "markdown", "graphql",
      }) do
        opts.formatters_by_ft[ft] = {
          "oxfmt",
          "biome",
          "prettier",
          stop_after_first = true,
        }
      end

      return opts
    end,
  },
}
```

The old 5000ms timeout override is gone — it existed for Prettier's cold start with
`prettier-plugin-svelte` + `prettier-plugin-tailwindcss`. oxfmt is native and doesn't need it. Add
it back only if you actually see timeouts.

> **Note on `.svelte`:** routing it through conform is deliberate. The `oxfmt` *LSP* does not list
> `svelte` in its filetypes, so `vim.lsp.enable('oxfmt')` would silently skip Svelte buffers.
> conform's `formatters_by_ft` is filetype-agnostic, so it works. Don't enable the oxfmt LSP.

---

## 5. Add the oxlint LSP

New file `lua/plugins/lsp-oxlint.lua`:

```lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        oxlint = {
          settings = {
            typeAware = true,   -- must be explicit, see below
            fixKind = "all",
          },
        },
      },
    },
  },
}
```

`typeAware` has to be set by hand. `oxlint.lua` only auto-enables it when `tsgolint` is executable
**and** a `.oxlintrc.json` contains the string `"typescript"` — with Vite+ the config lives in
`vite.config.ts`, so that probe fails (safely) and type-aware rules stay off, making the editor
quieter than `vp check`.

Root detection needs nothing: `root_dir` searches `vite.config.ts` for both `vite-plus` and a
`lint:` / `fmt:` field. You also get `:LspOxlintFixAll`.

**Do not enable the LazyVim `lang.typescript.oxc` extra.** It installs oxfmt via Mason — a global
binary that drifts from each project's pinned version — and disables the oxfmt LSP.

---

## 6. Verify

Restart Neovim, open `~/Desktop/dev/iteras-min-side-test`, then in a `.ts` and a `.svelte` buffer:

```vim
:ConformInfo     " expect oxfmt, resolved to <project>/node_modules/.bin/oxfmt
:checkhealth lsp " expect oxlint attached
:LspOxlintFixAll
```

Then the real test — formatting must agree with the hook:

```bash
cd ~/Desktop/dev/iteras-min-side-test
npx vp fmt --check      # clean
# now save a .svelte file in nvim, then re-run:
npx vp fmt --check      # must still be clean
```

If the second run reports changes, the editor and `vp fmt` disagree — check `:ConformInfo` is
showing oxfmt and not falling through to prettier.

**Cross-repo check:** open a repo that is still on biome and confirm `:ConformInfo` shows *biome*
there. That proves the ordering is resolving per project rather than globally.

---

## Rollback

```vim
:Lazy restore    " replays lazy-lock.json
```

```bash
rm -rf ~/.config/nvim && mv ~/.config/nvim.bak-<date> ~/.config/nvim
```

---

## Once every service is on oxc

Collapse step 4's list to `{ "oxfmt" }` and drop prettier/biome from Mason. Not required — the
ordered list is already correct — just less to read.
