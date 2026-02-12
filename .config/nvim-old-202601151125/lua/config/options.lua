-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- This sets the terminal title when Neovim starts
vim.opt.title = true

-- Capitalize first letter
local function capitalize(str)
  return (str:gsub("^%l", string.upper))
end

-- Set terminal title
local function set_title()
  local cwd = vim.fn.getcwd()
  local project = cwd:match(".*/(.*)$") or cwd
  local icon = "💚" -- You can replace this with any emoji you like
  local title = string.format("%s - %s", icon, capitalize(project))
  vim.opt.titlestring = title
end

-- Run once and on directory change
set_title()
vim.api.nvim_create_autocmd("DirChanged", {
  callback = set_title,
})
