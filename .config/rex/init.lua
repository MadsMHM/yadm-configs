-- Rex config, ported from ~/.tmux.conf. Reload: rex config reload
-- Keys follow the Danish layout and are written unshifted: " = shift+2, % = shift+5.

local terminal = "com.superlogical.terminal"
local scripts = os.getenv("HOME") .. "/.config/rex/scripts"

-- Foreground process of the focused pane (name, cwd), or nil.
local function fg()
  local p = rex.block.call(terminal, "process", {})
  return p and p.foreground
end

-- ---- Popups (floating layers, 80%) ----
local POPUP = { 0.1, 0.1, 0.8, 0.8 }

-- One floating block per label per session (scratch shell, each popup tool). Pressing its key:
-- shows it, or hides it if it's showing in this tab; in another tab it moves here.
-- Hiding detaches the block: it keeps running but takes no space (no minimized capsule).
-- make() creates it the first time (and after it exits).
local function toggle_float(ctx, label, make)
  local r, err = rex.call("session.view", { session_id = ctx.session_id })
  if not r then error(err, 0) end
  local here, fw, fl, fb -- current window; the float's window, layer, block
  for _, w in ipairs((r.view or r).windows or {}) do
    for _, l in ipairs(w.layers or {}) do
      for _, b in ipairs(l.blocks or {}) do
        if b.block_id == ctx.block_id then here = w.window_id end
        if b.label == label then fw, fl, fb = w.window_id, l, b.block_id end
      end
    end
  end
  if not fb then -- not in a window: detached (old scratch toggle) or never made
    for _, b in ipairs((rex.session.list_blocks{} or {}).blocks or {}) do
      if b.label == label then fb = b.block_id end
    end
  end
  if fw and fw == here and fl.state ~= "minimized" then
    rex.session.detach_block{ block_id = fb }
    return
  elseif fw and fw == here then -- minimized natively (capsule bar): bring it back
    rex.call("session.set_layer_state", { session_id = ctx.session_id, layer_id = fl.layer_id,
      state = "normal", focus = true })
  elseif fb then
    rex.session.move_block{ block_id = fb, anchor_block_id = ctx.block_id }
    rex.session.float_block{ block_id = fb, bounds = POPUP }
    rex.session.focus_block{ block_id = fb }
  else
    make()
  end
  -- The server now has the float focused, but the app keeps typing in the pane the key came
  -- from; re-selecting the tab makes it pick up the server's focus (Rex bug, as with tabs).
  rex.client.queue("session.select", { session_id = ctx.session_id, window_id = here })
end

local function open_popup(ctx, args)
  local f = fg()
  local cmd = {}
  for i, a in ipairs(args.cmd) do cmd[i] = a == "{block}" and ctx.block_id or a end
  local label = "popup:" .. cmd[1]:match("[^/]+$") -- e.g. popup:lazygit, so its key finds it again
  local layout = rex.layout.block{
    flavor  = "com.superlogical.terminal.shell",
    label   = not args.tab and label or nil,
    options = { command = cmd, cwd = f and f.cwd },
  }
  if args.tab then
    -- The app doesn't follow the server's active tab, and drops a select for a
    -- tab it hasn't heard of yet; the short sleep lets it catch up (Rex bug).
    local w = rex.session.new_window{ layout = layout }
    if w then
      rex.client.queue("session.select", { session_id = ctx.session_id, window_id = w.window_id })
      rex.exec{ "sleep", "0.2" }
    end
  else
    toggle_float(ctx, label, function()
      rex.session.new_layer{ bounds = args.bounds or POPUP, focus = true, layout = layout }
    end)
  end
end

rex.action{
  name  = "popup",
  title = "Open Popup",
  -- tab: open in a new tab instead; bounds: popup size; "{block}" in cmd: the pane it was opened from
  args  = { cmd = "array", tab = "boolean?", bounds = "array?" },
  run   = open_popup,
}

-- Popup tools: each has a prefix key, and Cmd+I lists them all (same args, same behaviour).
local TOOLS = {
  { key = "g",       title = "lazygit",    subtitle = "Git",            icon = "branch",   args = { cmd = { "lazygit" } } },
  { key = "shift+d", title = "lazydocker", subtitle = "Docker",         icon = "package",  args = { cmd = { "lazydocker" } } },
  { key = "y",       title = "yazi",       subtitle = "Files (new tab)", icon = "folder",  args = { cmd = { "yazi" }, tab = true } },
  { key = "b",       title = "btop",       subtitle = "System monitor", icon = "server",   args = { cmd = { "btop" } } },
  { key = "d",       title = "diffnav",    subtitle = "Branch/PR diff (new tab)", icon = "branch",
    args = { cmd = { scripts .. "/diff.sh" }, tab = true } },
  { key = "u",       title = "URLs",       subtitle = "Open a URL from this pane", icon = "link",
    args = { cmd = { scripts .. "/urls.sh", "{block}" }, bounds = { 0.2, 0.35, 0.6, 0.3 } } },
}

-- Cmd+I: every tool plus the scratch shell; 🟢 = already running (shown or minimized),
-- and picking it brings that one back.
local function make_scratch()
  local f = fg()
  rex.session.new_layer{ bounds = POPUP, focus = true, layout = { block = {
    flavor = "com.superlogical.terminal.shell", label = "scratch", options = { cwd = f and f.cwd } } } }
end

rex.action{
  name  = "tools",
  title = "Open Tool…",
  run   = function(ctx)
    local running = {}
    for _, b in ipairs((rex.session.list_blocks{} or {}).blocks or {}) do running[b.label] = true end
    local items = { { id = "scratch", title = "scratch", subtitle = "Scratch shell", icon = "terminal",
      detail = running.scratch and "🟢" or nil } }
    for i, tool in ipairs(TOOLS) do
      local label = "popup:" .. tool.args.cmd[1]:match("[^/]+$")
      items[#items + 1] = { id = tostring(i), title = tool.title, subtitle = tool.subtitle, icon = tool.icon,
        detail = running[label] and "🟢" or nil }
    end
    local pick = rex.ui.pick{ title = "Tools", placeholder = "Filter…", items = items }
    if not pick then return end
    -- the app hands focus back to the old pane as the picker closes; let that finish first
    rex.exec{ "sleep", "0.15" }
    if pick == "scratch" then toggle_float(ctx, "scratch", make_scratch)
    elseif pick then open_popup(ctx, TOOLS[tonumber(pick)].args) end
  end,
}

-- prefix t / cmd+j: a scratch shell per session (xh, one-off commands) floating over the current tab.
rex.action{
  name  = "scratch",
  title = "Toggle Scratch Shell",
  run   = function(ctx)
    toggle_float(ctx, "scratch", make_scratch)
  end,
}

-- cmd+o: native sessionx. Pick a session, a pinned folder or a folder in ~/Desktop/dev;
-- a folder goes to the session named after it, creating it there first.
local home = os.getenv("HOME")
local dev = home .. "/Desktop/dev"
local function lines(r) return ((r and r.stdout) or ""):gmatch("[^\n]+") end

-- Last session (tmux `switch-client -l`). Rex has no event for the app changing session, so the
-- state file holds "current, previous" and is updated by go() and whenever an action looks.
-- ponytail: a switch made elsewhere (sidebar, cmd+k) is only noticed on the next look, so two
-- of those in a row leave "last" one hop stale. Use a select event if Rex ever emits one.
local last_file = home .. "/.local/state/rex-last-session"
local function save_last(cur, prev)
  local f = io.open(last_file, "w")
  if f then f:write(cur, "\n", prev or "", "\n"); f:close() end
end
local function last_session(ctx) -- the session shown before ctx's, or nil
  local cur, prev -- declared apart: a failed io.open also returns its error message
  local f = io.open(last_file)
  if f then cur, prev = f:read("*l"), f:read("*l"); f:close() end
  if cur ~= ctx.session_id then prev = cur; save_last(ctx.session_id, prev) end
  return prev ~= "" and prev or nil
end
local function go(ctx, id, window_id)
  if id ~= ctx.session_id then save_last(id, ctx.session_id) end
  rex.client.queue("session.select", { session_id = id, window_id = window_id })
end
-- one single-pane tab; initial_input is only typed unless it ends in \r
local function tab(dir, input)
  return { layout = { block = { flavor = "com.superlogical.terminal.shell", options = { cwd = dir, initial_input = input } } } }
end
-- new project sessions (zellij-style layout), one tab each: nvim | empty shell | `claude` typed, not run.
-- Tabs keep Rex's default names (the running program).
local function project_windows(dir)
  return { tab(dir, "nvim\r"), tab(dir), tab(dir, "claude") }
end
local vault = home .. "/Desktop/obsidian/vault"
-- folders that get their own session name and tabs instead of the defaults
local ghdash = home .. "/.config/gh-dash"
local special = {
  [vault] = { label = "obsidian", windows = { tab(vault, "nvim '+Obsidian quick_switch'\r"), tab(vault, "claude") } },
  -- the central PR inbox; Rex's icon set has no GitHub logo
  [ghdash] = { label = "GitHub PRs", icon = "globe", windows = { tab(ghdash, "gh dash\r") } },
}
local pinned = { ghdash, home .. "/.config", vault } -- always listed, above the dev folders
-- session name for a folder: basename, leading dot dropped, dots as _ (sessionx/tmux style)
local function label_of(dir)
  if special[dir] then return special[dir].label end
  return ((dir:match("[^/]+$"):gsub("^%.", "")):gsub("%.", "_"))
end

-- The session for a folder: the open one with its name (any case: gh-dash and the folder
-- may differ), or a new one with the folder's tabs.
local function project_session(dir)
  local label = label_of(dir)
  local sessions = (rex.call("session.list", {}) or {}).sessions or {}
  local found
  for _, s in ipairs(sessions) do
    if s.label:lower() == label:lower() then found = s.session_id end
  end
  -- renamed sessions (gandalf = iteras-min-side-test): any pane working in the folder
  for _, s in ipairs(found and {} or sessions) do
    rex.call("session.attach", { session_id = s.session_id }) -- `rex do` can't read it otherwise
    local r = rex.call("session.list_blocks", { session_id = s.session_id }) or {}
    for _, b in ipairs(r.blocks or {}) do
      local p = rex.block.call(terminal, "process", { block_id = b.block_id, session_id = s.session_id })
      local cwd = p and p.foreground and p.foreground.cwd or ""
      if cwd:lower() == dir:lower() or cwd:lower():sub(1, #dir + 1) == dir:lower() .. "/" then found = s.session_id end
    end
    if found then break end
  end
  if found then
    -- run from `rex do` (gh-dash D), changes need the stream attached to the session
    rex.call("session.attach", { session_id = found })
    return found
  end
  local s, err = rex.call("session.create", { label = label, initial_windows = special[dir] and special[dir].windows or project_windows(dir) })
  if not s then error(err or "session.create failed", 0) end
  rex.call("session.attach", { session_id = s.session_id })
  -- the last tab created is active; start on the first (nvim) tab instead
  rex.call("session.focus_window", { session_id = s.session_id, window_id = s.initial_windows[1].window_id })
  rex.exec{ "sleep", "0.3" } -- let the app learn about the session before selecting it
  return s.session_id
end

rex.action{
  name  = "sessionx",
  title = "Sessionx: Switch or Open Project",
  run   = function(ctx)
    local r, err = rex.call("session.list", {})
    if not r then error(err, 0) end -- an empty list here would create duplicate sessions
    local sessions = r.sessions or {}
    local items, seen, icons = {}, {}, {}
    for _, sp in pairs(special) do icons[sp.label] = sp.icon end
    for _, s in ipairs(sessions) do
      seen[s.label] = true -- a folder whose session is open is already listed as that session
      local item = { id = "session:" .. s.session_id, title = s.label, icon = icons[s.label] or "terminal", detail = "🟢" }
      if s.session_id == ctx.session_id then -- current session: first, starred, labelled
        item.icon, item.subtitle = "star", "current session"
        table.insert(items, 1, item)
      else
        items[#items + 1] = item
      end
    end
    local last = "session:" .. tostring(last_session(ctx))
    for i, item in ipairs(items) do -- last session on top: cmd+o, enter goes back to it
      if item.id == last then
        item.subtitle = "last session"
        table.insert(items, 1, table.remove(items, i))
        break
      end
    end
    local dirs = {}
    for dir in lines(rex.exec{ "find", dev, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-not", "-name", ".*" }) do
      dirs[#dirs + 1] = dir
    end
    table.sort(dirs, function(a, b) return a:lower() < b:lower() end)
    for i, dir in ipairs(pinned) do table.insert(dirs, i, dir) end
    for _, dir in ipairs(dirs) do
      if not seen[label_of(dir)] then
        local title = special[dir] and special[dir].label or dir:match("[^/]+$")
        items[#items + 1] = { id = dir, title = title, subtitle = dir:gsub("^" .. home, "~"), icon = icons[title] or "folder" }
      end
    end

    local pick = rex.ui.pick{ title = "Sessions & projects", placeholder = "Filter…", items = items }
    if not pick then return end

    go(ctx, pick:match("^session:(.+)") or project_session(pick))
  end,
}

-- cmd+shift+k / prefix L: straight back to the last session
rex.action{
  name  = "session_last",
  title = "Sessionx: Last Session",
  run   = function(ctx)
    local last = last_session(ctx)
    for _, s in ipairs((rex.call("session.list", {}) or {}).sessions or {}) do
      if s.session_id == last then return go(ctx, last) end
    end
    error("no last session", 0)
  end,
}

-- gh-dash D (scripts/review.sh, after it checked out the PR): a "#<pr>" tab running diffnav
-- in the repo's session, then show it. Quitting diffnav closes the tab.
rex.action{
  name  = "review_tab",
  title = "Review PR in Repo Session",
  args  = { dir = "string", pr = "string" },
  run   = function(_, args)
    local id = project_session(args.dir)
    local w, err = rex.call("session.new_window", { session_id = id, window_label = "#" .. args.pr,
      layout = { block = { flavor = "com.superlogical.terminal.shell",
        options = { command = { scripts .. "/diff.sh" }, cwd = args.dir } } } })
    if not w then error(err or "session.new_window failed", 0) end
    rex.exec{ "sleep", "0.2" } -- the app drops a select for a tab it hasn't heard of yet
    go(ctx, id, w.window_id)
  end,
}

-- pane.close from a key binding is broken in current betas (the key leaks to the
-- terminal); closing the block through the server works.
rex.action{
  name  = "close_pane",
  title = "Close Pane (server)",
  run   = function(ctx)
    local _, err = rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id })
    if err then error(err, 0) end
  end,
}

-- ---- vim-tmux-navigator (Rex half) ----
-- ctrl+hjkl moves between Rex panes, but goes to nvim when nvim is focused.
-- From a floating window it hides (detaches) the window first (fzf keeps the keys for its list).
-- Leaving nvim at its edge needs the nvim side too; until then use prefix+arrows.
rex.action{
  name  = "navigate",
  title = "Navigate Pane or Vim Split",
  args  = { direction = "string", key = "string" },
  run   = function(ctx, args)
    -- ctx.block_id is the tiled pane even when a floating window has focus, so ask the
    -- session which block the active window has focused, and which layer it's in.
    local v = rex.call("session.view", { session_id = ctx.session_id }) or {}
    v = v.view or v
    local floating, focused
    for _, w in ipairs(v.windows or {}) do
      if w.window_id == v.active_window_id then
        for _, l in ipairs(w.layers or {}) do
          for _, b in ipairs(l.blocks or {}) do
            if b.block_id == w.focused_block_id then
              focused = b.block_id
              floating = l.kind == "floating"
            end
          end
        end
      end
    end
    local p = focused and rex.block.call(terminal, "process", { block_id = focused, session_id = ctx.session_id })
    local f = p and p.foreground
    if floating and not (f and f.name == "fzf") then
      rex.session.detach_block{ block_id = focused }
      rex.client.queue("pane.focus", { direction = args.direction })
    elseif f and (f.name == "nvim" or f.name == "vim" or f.name == "fzf") then
      rex.client.queue("pane.send_key", { key = args.key })
    else
      rex.client.queue("pane.focus", { direction = args.direction })
    end
  end,
}
for key, dir in pairs{ h = "left", j = "down", k = "up", l = "right" } do
  rex.bind("ctrl+" .. key, "navigate", { direction = dir, key = "ctrl+" .. key })
end

-- Cmd+B types a backslash (Danish layout), as in Ghostty
rex.bind("cmd+b", function()
  rex.block.call(terminal, "write", { data = "\\" })
  return true
end)

-- cmd+shift+o: tick sessions to kill (the current one isn't offered)
rex.action{
  name  = "sessionx_kill",
  title = "Sessionx: Kill Sessions",
  run   = function(ctx)
    local r, err = rex.call("session.list", {})
    if not r then error(err, 0) end
    local items = {}
    for _, s in ipairs(r.sessions or {}) do
      if s.session_id ~= ctx.session_id then
        items[#items + 1] = { id = s.session_id, title = s.label, icon = "terminal" }
      end
    end
    if #items == 0 then return end
    local ids = rex.ui.pick{ title = "Kill sessions", placeholder = "Filter…", confirm = "Kill", multiple = true, items = items }
    for _, id in ipairs(ids or {}) do
      local _, kerr = rex.call("session.destroy", { session_id = id })
      if kerr then error(kerr, 0) end
    end
  end,
}

-- Cmd+O opens sessionx without the prefix, Cmd+Shift+O kills sessions
rex.bind("cmd+o", "sessionx")
rex.bind("cmd+shift+o", "sessionx_kill")
rex.bind("cmd+shift+k", "session_last") -- toggle between two sessions
rex.bind("cmd+shift+w", "session.close") -- close the current session
rex.bind("cmd+i", "tools") -- pick a popup tool
rex.bind("cmd+j", "scratch") -- toggle the scratch shell (like VS Code's terminal panel)

-- Previous/next tab, beside ctrl+hjkl for panes
rex.bind("cmd+shift+h", "client.tab.previous")
rex.bind("cmd+shift+l", "client.tab.next")

-- ---- Prefix bindings (ctrl+space, ctrl+b as prefix2) ----
for _, prefix in ipairs{ "ctrl+space", "ctrl+b" } do
  local function bind(key, action, args)
    rex.bind(prefix .. ">" .. key, action, args)
  end

  bind(prefix, "pane.send_key", { key = prefix }) -- press twice to send it through

  -- windows -> tabs
  bind("c", "client.tab.new")
  bind("n", "client.tab.next")
  bind("p", "client.tab.previous")
  bind(",", "client.tab.rename")
  bind("shift+6", "client.tab.close") -- &
  for i = 1, 9 do
    bind(tostring(i), "client.tab.goto", { index = i })
  end

  -- panes
  bind("x", "close_pane")
  bind("space", "pane.balance")
  bind("shift+r", "client.mode.enter", { name = "resize" }) -- resize mode, esc leaves
  for _, dir in ipairs{ "left", "right", "up", "down" } do
    bind(dir, "pane.focus", { direction = dir })
    bind("ctrl+" .. dir, "pane.resize", { direction = dir })
  end

  -- sessions: s = Rex's own picker (sessionx is on cmd+o)
  bind("s", "session.switch")
  bind("shift+8", "session.previous") -- (
  bind("shift+9", "session.next")     -- )
  bind("shift+l", "session_last")     -- L, as in tmux

  bind("r", "client.config.reload")

  -- popups (the TOOLS list above) and the scratch shell
  for _, tool in ipairs(TOOLS) do bind(tool.key, "popup", tool.args) end
  bind("t", "scratch")
end

-- ---- Resize mode (prefix R): arrows/hjkl resize, shift = big step, space balances ----
rex.mode("resize", { exclusive = true })
for key, dir in pairs{ h = "left", j = "down", k = "up", l = "right",
                       left = "left", down = "down", up = "up", right = "right" } do
  rex.bind("resize/" .. key, "pane.resize", { direction = dir })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = dir, amount = 15 })
end
rex.bind("resize/space", "pane.balance")

-- ---- Session restore (resurrect.lua; autosave is a launchd agent) ----
local rex_bin = os.getenv("HOME")
  .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
local resurrect = os.getenv("HOME") .. "/.config/rex/resurrect.lua"
local function resurrect_cmd(cmd)
  return { rex_bin, "--autostart=false", "do", resurrect, "cmd=" .. cmd }
end

-- Runs on every config load; auto-restore only acts once per server start.
-- Retries while the freshly started server isn't accepting connections yet.
rex.exec.start({ "/bin/sh", "-c",
  'for i in 1 2 3 4 5; do sleep 2; "$@" && break; done',
  "sh", unpack(resurrect_cmd("auto-restore")),
}, { detach = true, stdout = false, stderr = false })

for cmd, title in pairs{ save = "Save Sessions", restore = "Restore Sessions" } do
  rex.action{
    name  = "sessions_" .. cmd,
    title = title,
    run   = function() return rex.exec(resurrect_cmd(cmd)).stdout end,
  }
end
-- prefix ctrl+s / ctrl+r, as tmux-resurrect
for _, prefix in ipairs{ "ctrl+space", "ctrl+b" } do
  rex.bind(prefix .. ">ctrl+s", "sessions_save")
  rex.bind(prefix .. ">ctrl+r", "sessions_restore")
end
