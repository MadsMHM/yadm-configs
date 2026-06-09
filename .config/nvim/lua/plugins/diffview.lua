local function pr_diffview()
  local base = vim.fn.system("gh pr view --json baseRefName --jq .baseRefName 2>/dev/null"):gsub("%s+", "")
  if base == "" then
    vim.notify(
      "Not on a PR branch. Run `gh pr checkout <num>` first, or use :DiffviewOpen <base>...HEAD",
      vim.log.levels.WARN
    )
    return
  end
  vim.fn.system("git fetch origin " .. base .. " 2>/dev/null")
  vim.cmd("DiffviewOpen origin/" .. base .. "...HEAD")
end

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: open" },
    { "<leader>gD", pr_diffview, desc = "Diffview: PR vs base" },
    { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
  },
}
