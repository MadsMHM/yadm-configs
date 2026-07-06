# Terminal Workflow Playbook

Tuned to this machine's dotfiles (zsh + starship + tmux + Ghostty, Neovim/LazyVim,
fzf/zoxide/eza/bat/fd/rg, xh, lazygit, yazi). Last validated 2026-06-12.

---

## TL;DR — keystrokes that pay rent

| Keys | Where | What |
|---|---|---|
| `Ctrl+T` | shell | fzf file picker (fd-backed, bat/eza preview) — inserts path at cursor |
| `Ctrl+R` | shell | fzf fuzzy history search |
| `Esc` then `c` | shell | fzf **cd** into subdirectory (this is "Alt+C" — see Ghostty note below) |
| `**<Tab>` | shell | fzf completion for any command: `nvim **<Tab>`, `cd **<Tab>`, `ssh **<Tab>`, `kill -9 **<Tab>` |
| `Ctrl+G` `Ctrl+B` | shell | fzf-git: pick branch (also `^F` files, `^H` hashes, `^S` stashes…) |
| `z <part-of-name>` | shell | zoxide jump (your `cd` is aliased to this); `zi` = interactive picker |
| `y` | shell | yazi, and your shell **follows** the dir you quit in |
| `Ctrl+Space` then `g` / `y` / `b` / `t` | tmux | popup lazygit / yazi / btop / scratch shell |
| `Ctrl+Space` then `O` | tmux | sessionx — fuzzy project/session switcher over `~/Desktop/dev` |
| `Ctrl+h/j/k/l` | tmux+nvim | seamless pane/split navigation (vim-tmux-navigator) |
| `Space` (and wait) | nvim | which-key shows every binding; `Space s k` searches keymaps |
| `fc` | shell | reopen the **last command** in nvim, edit, save → re-runs. Lifesaver for long `xh` calls |
| `Cmd+B` | Ghostty | types `\` — skips the Danish `Opt+Shift+7` chord |

---

## Shell (zsh)

### fzf, fully enabled

- **`Ctrl+T`** — files + dirs (hidden included, `.git` excluded). `Tab` multi-selects;
  `Enter` inserts the selection(s) into the command line. Preview is `bat` for files,
  `eza --tree` for dirs.
- **`Ctrl+R`** — history. Type any words in any order.
- **`Alt+C`** — cd into a fuzzy-picked subdirectory. **In Ghostty on macOS this does
  not fire from the Option key** (no `macos-option-as-alt` set — and turning it on
  would steal `{ } [ ] | \ @` on a Danish layout). Use **`Esc` then `c`** instead, or
  bind a free Ctrl key in `.zshrc`:

  ```zsh
  bindkey '^o' fzf-cd-widget   # Ctrl+O → fuzzy cd
  ```

- **`**<Tab>` trigger** — works after *any* command and uses your custom previews:
  - `cd **<Tab>` → dirs with tree preview
  - `export **<Tab>` / `unset **<Tab>` → env vars with current value preview
  - `ssh **<Tab>` → hosts with `dig` preview
  - `nvim **<Tab>`, `cat **<Tab>`, `kill -9 **<Tab>` → files/PIDs

### fzf-git (`Ctrl+G` chords — lazy-loaded on first press)

| Chord | Picks |
|---|---|
| `Ctrl+G Ctrl+F` | changed/tracked **f**iles |
| `Ctrl+G Ctrl+B` | **b**ranches (preview = log) |
| `Ctrl+G Ctrl+H` | commit **h**ashes (paste into `git rebase -i`, `git cherry-pick`…) |
| `Ctrl+G Ctrl+S` | **s**tashes |
| `Ctrl+G Ctrl+T` | **t**ags |
| `Ctrl+G Ctrl+R` | **r**emotes |
| `Ctrl+G Ctrl+L` | ref**l**og entries |
| `Ctrl+G Ctrl+W` | **w**orktrees |

`Tab` multi-selects in all of them. Everything pastes onto your command line.

### History tricks

- **Leading space = off the record.** ` xh -a user:SECRET …` never enters history
  (`HIST_IGNORE_SPACE` is on). Use it whenever a token is in the command — several
  real tokens are sitting in `~/.zsh_history` today.
- **`fc`** — opens the previous command in nvim; quit and it runs the edited version.
  The fix for re-running multiline `xh POST` calls without retyping.
- **`Esc` then `.`** — inserts the last argument of the previous command.
- `!!` and `!$` expand but show first before running (`HIST_VERIFY`).
- Worth adding: edit the *current* line in nvim with `Ctrl+X Ctrl+E`:

  ```zsh
  autoload -Uz edit-command-line
  zle -N edit-command-line
  bindkey '^x^e' edit-command-line
  ```

### Multiline commands without backslash (Danish-layout-friendly)

- **`Cmd+B` types `\`** (Ghostty keybind — reload Ghostty config with `Cmd+Shift+,`
  the first time).
- You rarely *need* `\` to continue a line: zsh keeps reading automatically when a
  line ends with `&&`, `||`, `|`, or has an unclosed quote or paren — just press
  Enter and get a continuation prompt.
- Long `xh` requests: keep the body in a file (`xh POST :4545/x @payload.json`) or
  edit the command in nvim via `fc` — no continuation lines at all.

### zoxide

- `cd` is aliased to `z`: `cd art` jumps to the most-frecent dir matching "art".
  Real paths still work; `cd -` returns to the previous dir.
- `z foo bar` — match multiple words across the path.
- `zi` — interactive fzf pick of the database.

### Misc you already have

- `AUTO_CD`: type a directory name alone to enter it.
- Autosuggestions: `→` accepts the whole ghost suggestion, `Alt+F`/`Ctrl+→` one word.
- `ls` is a fully-loaded eza (git status, icons, relative dates, dirs first).
- `clear-zsh-cache` — **run after upgrading** starship/fzf/zoxide/fnm (see Maintenance).
- `xhl` — `xh` that trusts your mkcert root CA (see the xh section).

---

## tmux (prefix = `Ctrl+Space`, `Ctrl+b` still works)

| Keys (after prefix) | What |
|---|---|
| `g` / `y` / `b` / `t` | 80% popup: lazygit / yazi / btop / scratch shell — closes with the app, no window pollution |
| `O` (capital) | **sessionx**: fuzzy-switch or create sessions from `~/Desktop/dev` subdirs — your "open project" command |
| `Ctrl+s` / `Ctrl+r` | resurrect: save / restore the whole session layout (survives reboots) |
| `[` | copy mode — vi keys: `v` select, `y` yanks straight to macOS clipboard |
| `z` | zoom pane (stock tmux — pairs perfectly with popups) |
| `c`, `n`/`p`, `1-9` | new window, next/prev, jump (windows start at 1, renumber on close) |

- `Ctrl+h/j/k/l` (no prefix) moves between tmux panes **and** nvim splits.
- Mouse is on: scroll, click panes, drag to copy (also lands in clipboard).
- Popup caveat: yazi in a popup (`prefix y`) can't change your shell's directory —
  use the `y` shell command when you want to *land* somewhere.
- Claude Code-friendly: passthrough + extended keys already configured (Shift+Enter works).

---

## yazi (`y` in shell — cd-follows on quit)

| Key | What |
|---|---|
| `.` | toggle hidden files |
| `Space` | select; `y`/`x`/`p` yank/cut/paste; `d` trash; `a` create; `r` rename |
| `z` | zoxide jump *inside* yazi; `Z` fzf jump |
| `/` | filter-as-you-type; `gg`/`G` top/bottom |
| `~` | help / all keybindings |

---

## Neovim (LazyVim, leader = `Space`)

Discovery first: press `Space` and wait — which-key lists everything. `Space s k`
fuzzy-searches keymaps when you forget one.

- **Files/search**: `Space Space` files · `Space /` live grep · `Space ,` buffers ·
  `Space e` explorer · `Space s s` symbols.
- **Harpoon** (pin the 4-5 files you're living in): `Space H` pin · `Space h` menu ·
  `Space 1..5` jump to pin.
- **Flash**: `s` + two chars jumps anywhere on screen; `S` selects treesitter nodes.
- **Surround**: `gsa` add (e.g. `gsaiw"`), `gsd` delete, `gsr` replace.
- **Yanky**: `Space p` browse yank history; after a paste, `[y` / `]y` cycle older/newer yanks.
- **Dial**: `Ctrl+a` / `Ctrl+x` smart-increment — numbers, dates, `true⇄false`, `&&⇄||`.
- **Git**: `Space g g` lazygit · `Space g d` diffview · **`Space g D` diff PR vs its
  base branch** (your custom gh-powered review view) · `Space g c` close diffview.
- **AI**: Copilot ghost text (`Tab` accepts); Claude Code + Copilot Chat under `Space a`
  (`Space a a` intentionally disabled).
- Formatting is automatic and project-aware: Prettier when an ESLint config exists,
  Biome otherwise, always Prettier for `.svelte`.

---

## xh — local API testing playbook

### The shorthand that removes 80% of the typing

```sh
xh :4545/health                              # http://localhost:4545/health
xh :4545/debug/article histId==CHDB-3885090  # ==  → query param, NO URL quoting needed
xh :3000/api/things name=mads count:=2       # body present → POST inferred, JSON by default
```

| Item syntax | Meaning |
|---|---|
| `Header:value` | header — `Authorization:"Bearer $TOKEN"` |
| `param==value` | query string (quoting-proof — stop hand-writing `?a=b`) |
| `key=value` | JSON string field |
| `key:=value` | raw JSON: `ok:=true`, `n:=3`, `tags:='["a","b"]'` |
| `a[b]=c` | nested JSON: `{"a":{"b":"c"}}` |
| `@body.json` | whole request body from file |
| `key=@notes.txt` | field value from file |

- Forms instead of JSON: `-f` (`key=value` becomes urlencoded, `file@./x.png` multipart).
- Auth: `-a user:pass` · bearer: `-A bearer -a "$TOKEN"`.
- Output: `-v` request+response · `-b` body only · `-h` headers only ·
  `-p HBhbm` pick parts (request Headers/Body, response headers/body/metadata).
- `--follow` for redirects · `--timeout 5` · `-o out.json` / `-d` download.

### The two debugging lifesavers

```sh
xh --offline POST :4545/api/x name=mads tags:='["a"]'   # print the request, send nothing
xh --curl    POST :4545/api/x name=mads                  # translate to curl to share
```

`--offline` shows you exactly the JSON/headers xh would send — use it whenever a
request "should work but doesn't" before blaming the server.

### Why HTTPS on local dev kept failing (root cause)

Your xh build is **rustls-based (`+rustls -native-tls`): it does not read the macOS
keychain**, where mkcert installed its root CA. So `https://hf.login.local:5175`
verifies fine in the browser/curl but fails in xh. Fixes, best first:

```sh
xhl GET https://hf.login.local:5175/health   # alias → xh --verify "<mkcert rootCA.pem>"
xh --verify=no GET https://localhost:2525/x  # one-off escape hatch
```

Notes: `xhl` *replaces* the trust store with mkcert's CA — use it for local hosts
only (public sites will fail under it, by design). Don't put `--verify=no` in
`~/.config/xh/config.json` `default_options`; it would disable TLS checks for
production calls too. Also remember plain-http services are `http://` — a
`https://localhost:2525` typo produces a connection error, not a cert error.

### Postman-shaped workflows without Postman

xh has **no session/collection support** — by design. The pieces that replace it:

1. **Bodies in files, committed to the repo**: `xh POST :4545/api/x @payloads/export.json`.
2. **`fc`** to edit-and-rerun the last long request.
3. **Tokens via env, never inline**: `xh :3000/api Authorization:"Bearer $API_TOKEN"`
   (+ direnv per project — see Recommended additions).
4. **posting** (already installed, never configured) — TUI collections/environments,
   the actual Postman replacement for poke-around work: just run `posting`.
5. **hurl** (suggested) — plain-text request files with asserts; collections-as-code
   that live in the repo and run in CI.

---

## Git helpers you have

- `prefix g` (tmux) or `Space g g` (nvim) → lazygit.
- `ghd` → gh-dash scoped to the repo you're standing in (falls back to global dashboard).
- `Space g D` → review the current PR against its base branch in diffview.
- `.gitconfig` already has `push.autoSetupRemote` and `bun.lockb` text diffs.
- **delta** — syntax-highlighted, side-by-side diffs with tokyonight_night theme.
  Configured in two places: `~/.gitconfig` (`core.pager`) for all terminal git commands
  (`git diff`, `git log -p`, `git show`…), and `~/.config/lazygit/config.yml`
  (`git.paging.pager`) for lazygit's diff panels. In lazygit, `--paging=never` is
  required so lazygit keeps scroll control. `n`/`N` navigate between diff hunks.

---

## Node versions (fnm first, Vite+ on demand)

- `node` in a fresh shell = **fnm's default** (currently v24.15.0). Change with
  `fnm default <version>`, list installed with `fnm ls`.
- Per project: `fnm use` switches to the version in `.node-version` / `engines`.
- The moment you run any `vp` command, **Vite+ activates in that shell** and its
  bundled node takes over PATH — so future Vite+ projects just work, while fnm
  rules everywhere else.
- If `node`/`npm` ever vanish from a new shell: `clear-zsh-cache` (and `.zshrc`
  self-heals stale fnm caches automatically anyway).

---

## Maintenance ritual

```sh
brew upgrade && clear-zsh-cache   # ALWAYS paired — your shell caches starship/fzf/zoxide/fnm init
```

- All core tools current as of 2026-06-12 (fzf 0.73, tmux 3.6b, nvim 0.12.3,
  starship 1.25, zoxide 0.9.9). Check again anytime with `brew outdated`.
- **If the upgrade included tmux: restart the tmux server.** brew deletes the old
  keg, and macOS ties folder permissions (TCC) to the binary on disk — a running
  server whose binary was replaced gets *silently denied* access to
  Desktop/Documents. Symptom: `fatal: Unable to read current working directory:
  Operation not permitted` from git/lazygit. Fix: `prefix Ctrl+s` (save layout) →
  `tmux kill-server` → reopen Ghostty → `prefix Ctrl+r` (restore). Same logic
  after Ghostty auto-updates: fully quit and reopen it.
- tmux plugins: `prefix I` install, `prefix U` update. nvim: `:Lazy sync`.
- Dotfiles are yadm-managed: `yadm status` → commit when happy.

---

## Resolved 2026-06-12 (was "Known quirks")

- **Node managers**: fnm now owns `node`; Vite+ activates on first `vp` call (see
  Node versions above). fnm default was bumped to v24.15.0 to match what Vite+ had
  been serving — revert with `fnm default v22.22.0`.
- **LazyVim pickers**: the overlapping `editor.fzf` extra was removed from
  `lazyvim.json`; snacks_picker is the one picker. Run `:Lazy clean` once to
  uninstall the now-unused fzf-lua.
- **Starship palette**: `crust`/`sapphire`/`lavender` are now defined in
  `starship.toml` — rust/go/php/docker/conda/cmd_duration segments styled again.
- **Cruft removed** (recoverable in `~/.Trash/config-cleanup-20260612/`):
  `.oh-my-zsh`, `.p10k.zsh`, four old `.zshrc` backups, three old nvim configs.
  The two yadm-tracked backup dirs are staged as deletions — commit when ready.
- **Still open**: `~/.config/nushell` (yadm-tracked, untouched — remove if nushell
  is truly retired). `Alt+C` remains `Esc` then `c` (or bind `^o`, see fzf section).

---

## Recommended additions (ranked by fit)

| Tool | Why it fits *this* workflow | Install |
|---|---|---|
| **just** | Your history retypes the same `xh POST …/export` 10+ times. A `justfile` per repo: `just export JAR-3882912` | `brew install just` |
| **direnv** | Per-project `.envrc` exports `API_TOKEN` etc. automatically — kills inline tokens in commands/history | `brew install direnv` + hook in `.zshrc` |
| **hurl** | `.hurl` files = committable, assertable request collections; the "Postman in git" piece xh lacks | `brew install hurl` |
| ~~**delta**~~ | ✓ Installed — see Git helpers above | — |
| **fx** (or jless) | Interactive JSON explorer: `xh :3000/api \| fx` — drill into big payloads instead of jq round-trips | `brew install fx` |
| **tmux-continuum** | Auto-saves resurrect state every 15 min — you currently must remember `prefix Ctrl+s` | add `set -g @plugin 'tmux-plugins/tmux-continuum'` |
| **atuin** | Optional: SQLite history with cross-machine sync and context-aware ranking (replaces fzf Ctrl+R) | `brew install atuin` |

Already installed but dormant: **posting** (Postman-style TUI — give it 15 minutes
before reaching for anything else).
