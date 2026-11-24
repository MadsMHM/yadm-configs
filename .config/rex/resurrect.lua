-- tmux-resurrect for Rex, after rexurrect (github.com/cemcatik/rexurrect).
--
--   rex do ~/.config/rex/resurrect.lua cmd=save          snapshot every session
--   rex do ~/.config/rex/resurrect.lua cmd=restore       recreate saved sessions that aren't live
--   rex do ~/.config/rex/resurrect.lua cmd=auto-restore  same, but once per server start (init.lua)
--   rex do ~/.config/rex/resurrect.lua cmd=list          list snapshots
--
-- Saves windows, splits, ratios, labels you set, and each pane's folder and program.
-- Restore types each pane's program at its prompt and never runs it.
-- ponytail: no scrollback and no zsh last-command recorder; add if the typed program isn't enough.

local HOME = os.getenv("HOME")
local STATE = HOME .. "/.local/state/rex-resurrect"
local SNAPS = STATE .. "/snapshots"
local CLAUDE = STATE .. "/claude" -- block uuid -> conversation id, written by a Claude SessionStart hook
local KEEP = 10
local TERMINAL = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"
local SHELLS = { zsh = true, bash = true, sh = true, fish = true, login = true }
local NVIM = [[nvim -c 'lua require("persistence").load()']]
local current -- session being saved; block calls need it

local function sh(argv)
  local r = rex.exec(argv)
  return r and r.ok and (r.stdout:gsub("%s+$", "")) or nil
end

local function read(path)
  local f = io.open(path)
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write(path, s)
  local f = assert(io.open(path .. ".tmp", "w"))
  f:write(s)
  f:close()
  assert(os.rename(path .. ".tmp", path))
end

local function log(msg)
  local f = io.open(STATE .. "/log", "a")
  if f then
    f:write(os.date("!%Y-%m-%dT%H:%M:%SZ "), msg, "\n")
    f:close()
  end
  rex.log("warn", msg)
end

local function list_dir(dir)
  local out = sh{ "ls", dir }
  local names = {}
  for name in (out or ""):gmatch("[^\n]+") do names[#names + 1] = name end
  return names
end

local function call(fn, args)
  local r, err = fn(args)
  if not r then error(err, 0) end
  return r
end

local function instance()
  return call(function(a) return rex.call("server.status", a) end, {}).instance_id
end

local function latest()
  local names = list_dir(SNAPS) -- timestamped, so sorted oldest first
  local name = names[#names]
  return name and rex.json.decode(read(SNAPS .. "/" .. name)), name
end

-- ---- Save ----

-- What to type at a pane's prompt on restore, or nil for a plain shell.
local function command_for(block_id, fg)
  if not fg or SHELLS[(fg.argv0 or fg.name):gsub("^%-", "")] then return nil end
  local prog = (fg.argv0 or fg.name):match("[^/]+$")
  if prog == "nvim" then return NVIM end
  if prog == "claude" then
    local id = read(CLAUDE .. "/" .. block_id:gsub("^block:", ""))
    id = id and id:match("^%s*([%w%-_.:]+)%s*$")
    return id and ("claude --resume " .. id) or "claude --continue"
  end
  local cmd = sh{ "ps", "-o", "command=", "-p", tostring(fg.pid) }
  return cmd and not cmd:find("\n") and cmd or prog
end

local function save_layout(node, blocks, live)
  if node.split then
    local s = node.split
    return { split = {
      direction = s.direction, ratio = s.ratio,
      before = save_layout(s.before, blocks, live),
      after = save_layout(s.after, blocks, live),
    } }
  end
  local b = blocks[node.block_id] or {}
  live[node.block_id] = true
  local pane = { label = b.label ~= "shell" and b.label or nil }
  if b.creator_name == TERMINAL then
    local p = rex.block.call(TERMINAL, "process", { block_id = node.block_id, session_id = current })
    local fg = p and p.foreground
    pane.cwd = fg and fg.cwd
    pane.cmd = command_for(node.block_id, fg)
  end
  return { block = pane }
end

-- One window holding one shell in ~ with default labels: nothing worth restoring.
local function untouched(s)
  if #s.windows ~= 1 or s.windows[1].label then return false end
  local b = s.windows[1].layout.block
  return b ~= nil and not b.cmd and not b.label and (b.cwd == nil or b.cwd == HOME)
end

local restore -- forward declaration

local function save()
  -- After a server restart, restore before saving, so an autosave on a fresh
  -- server can't replace the last good snapshot with an empty one.
  if latest() and read(STATE .. "/restored") ~= instance() then restore() end

  local snap = { saved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"), sessions = {} }
  local live = {}
  for _, s in ipairs(call(rex.call, "session.list").sessions) do
    current = s.session_id
    rex.session.attach{ session_id = s.session_id }
    local v = call(rex.session.view, { session_id = s.session_id })
    local saved = { id = s.session_id, label = v.label, windows = {} }
    for _, w in ipairs(v.windows) do
      for _, layer in ipairs(w.layers) do
        if layer.kind == "tiled" and layer.layout then
          local blocks = {}
          for _, b in ipairs(layer.blocks or {}) do blocks[b.block_id] = b end
          saved.windows[#saved.windows + 1] = {
            label = not w.label:match("^Window %x+$") and w.label or nil,
            layout = save_layout(layer.layout, blocks, live),
          }
        end
      end
    end
    if #saved.windows > 0 and not untouched(saved) then
      snap.sessions[#snap.sessions + 1] = saved
    end
  end

  for _, f in ipairs(list_dir(CLAUDE)) do
    if not live["block:" .. f] then os.remove(CLAUDE .. "/" .. f) end
  end
  if #snap.sessions == 0 then return "nothing to save" end

  local name = os.date("%Y%m%d-%H%M%S") .. ".json"
  write(SNAPS .. "/" .. name, rex.json.encode(snap, { indent = true }))
  local names = list_dir(SNAPS)
  for i = 1, #names - KEEP do os.remove(SNAPS .. "/" .. names[i]) end
  return "saved " .. #snap.sessions .. " sessions to " .. name
end

-- ---- Restore ----

local function dir_exists(path)
  return path and rex.exec{ "test", "-d", path }.ok
end

local function restore_layout(node)
  if node.split then
    local s = node.split
    return { split = {
      direction = s.direction, ratio = s.ratio,
      before = restore_layout(s.before), after = restore_layout(s.after),
    } }
  end
  local b = node.block
  return { block = {
    flavor = SHELL,
    label = b.label,
    options = { cwd = dir_exists(b.cwd) and b.cwd or HOME, initial_input = b.cmd },
  } }
end

function restore(once)
  local inst = instance()
  if once and read(STATE .. "/restored") == inst then return "already restored on this server" end
  local snap, name = latest()
  if not snap then return "no snapshot" end

  local live = {}
  for _, s in ipairs(call(rex.call, "session.list").sessions) do
    live[s.session_id], live[s.label] = true, true
  end
  local created, skipped, failed = 0, 0, 0
  for _, s in ipairs(snap.sessions) do
    if live[s.id] or live[s.label] then
      skipped = skipped + 1
    else
      local windows = {}
      for _, w in ipairs(s.windows) do
        windows[#windows + 1] = { window_label = w.label, layout = restore_layout(w.layout) }
      end
      local _, err = rex.call("session.create", { label = s.label, initial_windows = windows })
      if err then
        failed = failed + 1
        log("restore " .. s.label .. ": " .. err)
      else
        created = created + 1
      end
    end
  end
  -- Count the server as restored unless everything failed, so the next save retries.
  if created > 0 or failed == 0 then write(STATE .. "/restored", inst) end
  local msg = ("%s: created %d, skipped %d (live), failed %d"):format(name, created, skipped, failed)
  if failed > 0 then error(msg, 0) end
  return msg
end

-- ---- Main ----

sh{ "mkdir", "-p", SNAPS, CLAUDE }
sh{ "chmod", "700", STATE } -- snapshots hold command lines

local cmd = rex.args.cmd
local ok, result = pcall(function()
  if cmd == "save" then return save() end
  if cmd == "restore" then return restore(false) end
  if cmd == "auto-restore" then return restore(true) end
  if cmd == "list" then return table.concat(list_dir(SNAPS), "\n") end
  error("usage: rex do resurrect.lua cmd=save|restore|auto-restore|list", 0)
end)
if not ok then
  log(cmd .. ": " .. tostring(result))
  rex.stop(1)
end
return result
