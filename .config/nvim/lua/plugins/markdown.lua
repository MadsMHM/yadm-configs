-- No markdown linting anywhere (LazyVim's lang.markdown extra adds markdownlint-cli2).
return {
  "mfussenegger/nvim-lint",
  opts = function(_, opts)
    opts.linters_by_ft.markdown = {}
  end,
}
