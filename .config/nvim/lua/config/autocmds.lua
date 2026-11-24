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

-- Copy the fenced code block under the cursor (contents only, no ``` fences) to the
-- system clipboard, like the copy button in the Obsidian app.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("md_copy_codeblock", { clear = true }),
  pattern = "markdown",
  callback = function(ev)
    vim.keymap.set("n", "<leader>oc", function()
      -- ignore_injections: get the markdown node, not the bash/json tree injected inside the block
      local node = vim.treesitter.get_node({ ignore_injections = true })
      while node and node:type() ~= "fenced_code_block" do
        node = node:parent()
      end
      for child in (node and node:iter_children() or function() end) do
        if child:type() == "code_fence_content" then
          -- trailing newline stripped so pasting into a shell doesn't run it
          vim.fn.setreg("+", (vim.treesitter.get_node_text(child, ev.buf):gsub("\n+$", "")))
          return vim.notify("Copied code block")
        end
      end
      vim.notify("Not in a code block", vim.log.levels.WARN)
    end, { buffer = ev.buf, desc = "Copy code block" })
  end,
})
