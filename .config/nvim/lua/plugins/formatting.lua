-- Formatter priority: vp fmt > oxfmt > biome > prettier, resolved per project.
--
-- vp_fmt: in Vite+ repos ONLY the `vp` wrapper applies the fmt block in
-- vite.config.ts — raw oxfmt silently ignores it (vite-plus#930), so oxfmt/biome/
-- prettier must never win there. Gated by require_cwd (a vite.config.ts upward)
-- plus a condition that the config actually imports vite-plus, so plain-Vite
-- repos (e.g. aragorn) fall through to the rest of the chain.
--
-- ...UNLESS an oxfmt config mirroring that fmt block exists, in which case raw oxfmt
-- reads the same rules and we skip vp entirely. `vp fmt` is a Node CLI that reloads the
-- whole vite-plus pipeline per invocation: measured 1.7-2.5s per single file even on an
-- idle machine, against LazyVim's *synchronous* 3000ms format-on-save. conform's oxfmt
-- builtin does the same job over --stdin-filepath in ~125ms (.ts) / ~640ms (.svelte),
-- byte-identical output (verified against `vp fmt` across 527 files).
--
-- To opt a repo in, drop an .oxfmtrc.json at its root mirroring the fmt block. Commit it
-- (which also fixes VS Code for teammates) or keep it private by adding it to that clone's
-- .git/info/exclude — untracked, invisible to `git status`, and it leaves .gitignore alone.
-- It cannot live outside the repo: see has_oxfmt_config below.
--
-- Why a config file is unavoidable: oxfmt only discovers .oxfmtrc.json(c),
-- oxfmt.config.ts/.mts, vite.config.ts and .editorconfig. vite.config.ts is the one file
-- that already exists, and oxfmt cannot load it — a Vite config's default export contains
-- plugin functions, so it dies with "JS functions cannot be represented as a
-- serde_json::Value" (still true in oxfmt 0.64.0, the latest). .editorconfig carries only
-- line-ending/charset keys, and there is no package.json key and no per-option CLI flag.
-- Without a config oxfmt silently emits ZERO edits on .svelte (the `svelte` option is
-- opt-in and off by default) and ignores ignorePatterns.
--
-- biome requires a biome.json (require_cwd): Mason's biome is always on PATH, so
-- without this it beats prettier in every Prettier repo — the old hack's bug.
--
-- from_node_modules() searches node_modules/.bin upward from the buffer, so each
-- repo gets its own pinned version. Do NOT install oxfmt globally — that would make
-- it "available" everywhere and it would win in repos that haven't migrated yet.
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      local util = require("conform.util")

      -- True when `root` has an oxfmt config, so plain oxfmt formats exactly like `vp fmt`.
      -- It must sit at the repo root: oxfmt resolves ignorePatterns relative to the config
      -- file's own directory, so a config kept outside the repo (e.g. ~/.config/oxfmt/)
      -- silently formats the ignored dirs. Absolute and glob patterns do not fix that.
      -- To keep it out of the repo, gitignore it per-clone via .git/info/exclude instead.
      local function has_oxfmt_config(root)
        if not root then
          return false
        end
        for _, rc in ipairs({ ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts", "oxfmt.config.mts" }) do
          if vim.uv.fs_stat(root .. "/" .. rc) then
            return true
          end
        end
        return false
      end

      opts.formatters = opts.formatters or {}

      opts.formatters.vp_fmt = {
        command = util.from_node_modules("vp"),
        args = { "fmt", "$FILENAME" },
        stdin = false, -- vp formats the file in place; conform hands it a temp copy
        cwd = util.root_file({ "vite.config.ts" }),
        require_cwd = true,
        condition = function(self, ctx)
          local root = self:cwd(ctx)
          if not root then
            return false
          end
          -- An oxfmt config mirrors the fmt block, so plain oxfmt (next in the chain) is
          -- correct here and much faster — don't pay for the vp wrapper.
          if has_oxfmt_config(root) then
            return false
          end
          local f = io.open(root .. "/vite.config.ts", "r")
          if not f then
            return false
          end
          local content = f:read(4096) or ""
          f:close()
          return content:find("vite%-plus") ~= nil
        end,
      }

      opts.formatters.biome = {
        require_cwd = true,
        -- A stray ~/Desktop/dev/biome.json satisfies the upward config search from
        -- every repo, so require_cwd alone can't stop Mason's biome from beating
        -- prettier in Prettier repos. Only run biome where the repo depends on it.
        condition = function(_, ctx)
          local pkg = vim.fs.find("package.json", { path = ctx.dirname, upward = true })[1]
          if not pkg then
            return false
          end
          local f = io.open(pkg, "r")
          if not f then
            return false
          end
          local content = f:read("*a") or ""
          f:close()
          return content:find("@biomejs/biome", 1, true) ~= nil
        end,
      }

      opts.formatters_by_ft = opts.formatters_by_ft or {}
      for _, ft in ipairs({
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "svelte",
        "json",
        "jsonc",
        "css",
        "scss",
        "less",
        "html",
        "yaml",
        "markdown",
        "graphql",
      }) do
        opts.formatters_by_ft[ft] = {
          "vp_fmt",
          "oxfmt",
          "biome",
          "prettier",
          stop_after_first = true,
        }
      end

      -- vp fmt is ~1s warm on a single file; conform's default 1000ms cuts it close.
      opts.default_format_opts = vim.tbl_deep_extend("force", opts.default_format_opts or {}, {
        timeout_ms = 3000,
      })

      return opts
    end,
  },
}
