-- Yazi as nvim's file manager (floating). Snacks explorer stays on <leader>e for a tree overview.
return {
  "mikavilpas/yazi.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = {
    { "nvim-lua/plenary.nvim", lazy = true },
  },
  keys = {
    { "-", mode = { "n", "v" }, "<cmd>Yazi<cr>", desc = "Yazi (current file)" },
    { "<leader>fy", "<cmd>Yazi cwd<cr>", desc = "Yazi (cwd)" },
  },
  opts = {
    open_for_directories = false,
    keymaps = {
      show_help = "<f1>",
    },
  },
}
