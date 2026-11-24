-- Inside Rex (no tmux): move between nvim windows, and at nvim's edge hand off
-- to the Rex pane beyond it. Rex's init.lua sends ctrl+hjkl to nvim when it's focused.
local function rex_navigate(wincmd, direction)
  return function()
    local win = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(wincmd)
    if vim.api.nvim_get_current_win() == win then
      vim.system({ "rex", "focus", direction })
    end
  end
end

local in_rex = vim.env.REX_SESSION and not vim.env.TMUX

return {
  "christoomey/vim-tmux-navigator",
  init = function()
    vim.g.tmux_navigator_no_mappings = 1 -- its own maps would replace the keys below on load
  end,
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  keys = in_rex and {
    { "<c-h>", rex_navigate("h", "left") },
    { "<c-j>", rex_navigate("j", "down") },
    { "<c-k>", rex_navigate("k", "up") },
    { "<c-l>", rex_navigate("l", "right") },
    { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
  } or {
    { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
    { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
  },
}
