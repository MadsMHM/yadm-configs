-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- nvim gets SIGKILLed often here (crash, terminal closed) and leaves swap files behind.
-- If the swap's owner is gone and it holds no unsaved changes there is nothing to
-- recover, so delete it and just open the file. Anything recoverable still prompts.
vim.api.nvim_create_autocmd("SwapExists", {
  group = vim.api.nvim_create_augroup("stale_swap", { clear = true }),
  callback = function()
    local info = vim.fn.swapinfo(vim.v.swapname)
    if info.error or info.dirty == 1 or info.host ~= vim.uv.os_gethostname() then
      return
    end
    -- ponytail: PIDs get recycled, so "process exists" lies -- check it is really nvim
    if vim.fn.system({ "ps", "-p", tostring(info.pid), "-o", "comm=" }):match("vim%s*$") then
      return
    end
    vim.v.swapchoice = "d"
  end,
})
