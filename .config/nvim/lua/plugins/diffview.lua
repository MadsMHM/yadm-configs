-- Diff the current branch against its base: the PR's base branch if there is a PR,
-- otherwise the repo's default branch (origin/HEAD, e.g. main).
local function pr_diffview()
  local base = vim.fn.system("gh pr view --json baseRefName --jq .baseRefName 2>/dev/null"):gsub("%s+", "")
  if base == "" then
    base = vim.fn.system("git rev-parse --abbrev-ref origin/HEAD 2>/dev/null"):gsub("%s+", ""):gsub("^origin/", "")
  end
  if base == "" or base == "HEAD" then
    vim.notify("No base found. Run `git remote set-head origin -a`, or :DiffviewOpen <base>...HEAD", vim.log.levels.WARN)
    return
  end
  vim.fn.system("git fetch origin " .. base .. " 2>/dev/null")
  vim.cmd("DiffviewOpen origin/" .. base .. "...HEAD")
end

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  keys = {
    -- gv/gV, not gd/gD: LazyVim's own <leader>gd/gD (Snacks git diff) override those
    { "<leader>gv", pr_diffview, desc = "Diffview: branch vs base (PR base or main)" },
    { "<leader>gV", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
    { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
  },
}
