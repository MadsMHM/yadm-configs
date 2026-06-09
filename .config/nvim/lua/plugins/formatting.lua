-- Prioritize ESLint + Prettier over Biome for formatting/linting
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Helper to check if ESLint config exists in project
      local function has_eslint_config()
        local root = vim.fn.getcwd()
        local eslint_configs = {
          ".eslintrc",
          ".eslintrc.js",
          ".eslintrc.cjs",
          ".eslintrc.json",
          ".eslintrc.yaml",
          ".eslintrc.yml",
          "eslint.config.js",
          "eslint.config.mjs",
          "eslint.config.cjs",
          "eslint.config.ts",
        }
        for _, config in ipairs(eslint_configs) do
          if vim.fn.filereadable(root .. "/" .. config) == 1 then
            return true
          end
        end
        local pkg = root .. "/package.json"
        if vim.fn.filereadable(pkg) == 1 then
          local ok, contents = pcall(vim.fn.readfile, pkg)
          if ok then
            for _, line in ipairs(contents) do
              if line:find('"eslintConfig"', 1, true) then
                return true
              end
            end
          end
        end
        return false
      end

      -- Prettier in Svelte projects (with prettier-plugin-svelte +
      -- prettier-plugin-tailwindcss) routinely needs more than the default
      -- 1000ms on cold start.
      opts.format_on_save = vim.tbl_deep_extend("force", opts.format_on_save or {}, {
        timeout_ms = 5000,
      })
      opts.format_after_save = vim.tbl_deep_extend("force", opts.format_after_save or {}, {
        timeout_ms = 5000,
      })

      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- Svelte: always Prettier — Biome cannot format .svelte templates.
      opts.formatters_by_ft.svelte = { "prettier" }

      -- JS/TS/JSON: Prettier when ESLint config is present, otherwise Biome.
      if has_eslint_config() then
        opts.formatters_by_ft.javascript = { "prettier" }
        opts.formatters_by_ft.javascriptreact = { "prettier" }
        opts.formatters_by_ft.typescript = { "prettier" }
        opts.formatters_by_ft.typescriptreact = { "prettier" }
        opts.formatters_by_ft.json = { "prettier" }
        opts.formatters_by_ft.jsonc = { "prettier" }
      else
        opts.formatters_by_ft.javascript = { "biome" }
        opts.formatters_by_ft.javascriptreact = { "biome" }
        opts.formatters_by_ft.typescript = { "biome" }
        opts.formatters_by_ft.typescriptreact = { "biome" }
        opts.formatters_by_ft.json = { "biome" }
        opts.formatters_by_ft.jsonc = { "biome" }
      end

      return opts
    end,
  },
}
