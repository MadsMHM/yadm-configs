-- Trimmed LazyVim lualine. Kept from LazyVim: mode | branch | root, diagnostics, path.
-- Right side rebuilt (not filtered) so LazyVim's pending-keys ("gj"), plugin-update
-- count and clock stay gone even if LazyVim reorders its own list.
return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    local icons = LazyVim.config.icons

    opts.sections.lualine_x = {
      -- "recording @q" while a macro records
      -- stylua: ignore
      {
        function() return require("noice").api.status.mode.get() end,
        cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
        color = function() return { fg = Snacks.util.color("Constant") } end,
      },
      -- debugger state, only while a dap session runs
      -- stylua: ignore
      {
        function() return "  " .. require("dap").status() end,
        cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
        color = function() return { fg = Snacks.util.color("Debug") } end,
      },
      -- +added ~changed -removed lines in this file vs git
      {
        "diff",
        symbols = { added = icons.git.added, modified = icons.git.modified, removed = icons.git.removed },
        source = function()
          local gs = vim.b.gitsigns_status_dict
          if gs then
            return { added = gs.added, modified = gs.changed, removed = gs.removed }
          end
        end,
      },
    }
    -- "57% 40": percent through file + line, no column
    opts.sections.lualine_y = { { "%p%% %l", padding = 1 } }
    opts.sections.lualine_z = {}
  end,
}
