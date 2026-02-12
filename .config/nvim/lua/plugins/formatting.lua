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
        }
        for _, config in ipairs(eslint_configs) do
          if vim.fn.filereadable(root .. "/" .. config) == 1 then
            return true
          end
        end
        return false
      end

      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- If ESLint config exists, use Prettier for formatting + eslint_d for lint fixes
      -- Otherwise use Biome for both
      if has_eslint_config() then
        opts.formatters_by_ft.javascript = { "prettier", "eslint_d" }
        opts.formatters_by_ft.javascriptreact = { "prettier", "eslint_d" }
        opts.formatters_by_ft.typescript = { "prettier", "eslint_d" }
        opts.formatters_by_ft.typescriptreact = { "prettier", "eslint_d" }
        opts.formatters_by_ft.svelte = { "prettier", "eslint_d" }
        opts.formatters_by_ft.json = { "prettier" }
        opts.formatters_by_ft.jsonc = { "prettier" }
      else
        opts.formatters_by_ft.javascript = { "biome" }
        opts.formatters_by_ft.javascriptreact = { "biome" }
        opts.formatters_by_ft.typescript = { "biome" }
        opts.formatters_by_ft.typescriptreact = { "biome" }
        opts.formatters_by_ft.svelte = { "biome" }
        opts.formatters_by_ft.json = { "biome" }
        opts.formatters_by_ft.jsonc = { "biome" }
      end

      return opts
    end,
  },
}
