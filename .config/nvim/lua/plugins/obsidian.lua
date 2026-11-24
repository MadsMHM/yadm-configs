-- Obsidian vault editing. Settings mirror the app's .obsidian/ config so notes stay
-- interchangeable: no frontmatter rewriting, title = filename, app's daily/attachment folders.
-- Completion, gd (follow link), gr (backlinks) and <leader>cr (rename + update links)
-- come from obsidian.nvim's built-in LSP.
local vault = vim.fn.expand("~/Desktop/obsidian/vault")

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  -- Only load for notes inside the vault, not every markdown file
  event = { "BufReadPre " .. vault .. "/*.md", "BufNewFile " .. vault .. "/*.md" },
  cmd = "Obsidian",
  keys = {
    { "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Find note" },
    { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search vault" },
    { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note (Inbox)" },
    { "<leader>ot", "<cmd>Obsidian today<cr>", desc = "Today's daily note" },
    { "<leader>oy", "<cmd>Obsidian yesterday<cr>", desc = "Yesterday's daily note" },
    { "<leader>od", "<cmd>Obsidian dailies<cr>", desc = "Pick daily note" },
    { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
    { "<leader>o#", "<cmd>Obsidian tags<cr>", desc = "Tags" },
    { "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Paste image" },
    { "<leader>oa", "<cmd>Obsidian open<cr>", desc = "Open in Obsidian app" },
    { "<leader>oe", ":Obsidian extract_note<cr>", mode = "v", desc = "Extract to new note" },
    { "<leader>ol", ":Obsidian link<cr>", mode = "v", desc = "Link selection to note" },
  },
  opts = {
    legacy_commands = false,
    workspaces = { { name = "vault", path = vault } },

    -- New notes land in the Inbox, named by their title like the app does
    notes_subdir = "00 Inbox",
    new_notes_location = "notes_subdir",
    note_id_func = function(title)
      if not title or vim.trim(title) == "" then
        return require("obsidian.builtin").zettel_id()
      end
      return (title:gsub("[\\/:]", "-")) -- characters Obsidian forbids in filenames
    end,
    -- Never rewrite notes on save (the app + Sync own properties); also skips the default id/aliases/tags template
    frontmatter = { enabled = false },

    link = { auto_update = true }, -- renaming a note updates every [[link]] to it

    daily_notes = {
      folder = "01 Work/Daily notes",
      date_format = "YYYY/MM/DD-MM-YYYY", -- year/month subfolders; must match .obsidian/daily-notes.json
      default_tags = {},
      workdays_only = false,
    },
    attachments = { folder = "./Vedhæftninger" },

    picker = { name = "snacks.picker" },
    checkbox = { order = { " ", "x" } }, -- the app only understands these two
    ui = { enable = false }, -- render-markdown.nvim (lang.markdown extra) handles rendering
  },
}
