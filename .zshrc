# TEMP instrumentation for the intermittent slow-pane investigation (Jul 2026).
# Every shell logs its zshrc wall time + zprof top to ~/.cache/zsh-startup-profile.log.
# After the next slow pane: check the log — if the entry is fast, the stall was
# tmux-server-side, not zsh. Delete this block and the matching one at the bottom
# of this file once confirmed.
zmodload zsh/zprof
zmodload zsh/datetime
_zshrc_t0=$EPOCHREALTIME

# ---- Tmux (run first; attach-or-create, never exec) ----
# new-session -A attaches when "default" exists and creates it otherwise,
# so two windows opening at once can't race into "duplicate session".
# No exec: if tmux fails (terminfo, client/server version mismatch after
# an upgrade, ...), fall through to a plain shell instead of a dead window.
if command -v tmux &>/dev/null && [[ -z "$TMUX" ]] && [[ $- == *i* ]]; then
    tmux new-session -A -s default && exit
    echo "tmux failed to start — continuing with a plain shell" >&2
fi

# ---- Core Zsh Settings ----
# compinit -C trusts the existing dump → ~0ms. The full rebuild takes ~3s on
# this machine and used to run inline in the first shell after the dump turned
# 24h old — THAT was the intermittent 6-7s pane open. Now the rebuild runs
# disowned in the background (-i audits but never prompts); this shell keeps
# the stale dump, the next one picks up the fresh one.
autoload -Uz compinit
compinit -C
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    (autoload -Uz compinit; compinit -i) &>/dev/null &!
fi

HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS HIST_VERIFY
setopt AUTO_CD INTERACTIVE_COMMENTS

bindkey -e

# Ctrl-X Ctrl-E: pop the current command line into $EDITOR (nvim) — ideal for
# editing long/multiline commands. Save & quit returns it to the prompt; zsh
# does not auto-run it, so press Enter to execute. Defined here (before the
# autosuggestions/syntax-highlighting plugins load) so they wrap it correctly.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Dedupe PATH entries
typeset -U PATH path

# Better completion UX
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ---- Environment ----
export EDITOR=nvim
export BAT_THEME=tokyonight_night

# ---- Bun ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ---- fnm (fast nvm replacement) ----
export PATH="$HOME/.local/share/fnm:$PATH"
# fnm multishell dirs are per-invocation and get cleaned up by fnm/macOS,
# so validate the cached one still exists — a stale cache silently removes
# node from PATH.
FNM_CACHE="$HOME/.cache/fnm-env.zsh"
_fnm_cached_dir="$(sed -n 's/^export FNM_MULTISHELL_PATH="\(.*\)"/\1/p' "$FNM_CACHE" 2>/dev/null)"
if [[ ! -f "$FNM_CACHE" || ! -e "$_fnm_cached_dir/bin" ]]; then
    fnm env --use-on-cd > "$FNM_CACHE"
fi
unset _fnm_cached_dir
source "$FNM_CACHE"

# ---- Yazi ----
# Must stay defined BEFORE the `cd="z"` alias below: aliases expand at
# function-parse time, so moving this after it would turn the `cd` here into
# `z` and break the quit-to-cwd handoff.
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    echo -ne "\033]0;📁 Yazi\007"
    command yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
    echo -ne "\033]0;${PWD##*/}\007"
}

# ---- Aliases ----
alias ls="eza --color=always --long --git --icons=always --header --modified --group-directories-first --time-style=relative -a --no-user --no-permissions"
alias cd="z"
alias nvm="fnm"
# All evals has been cached now, so if tools are updated, cache needs to be cleared
alias clear-zsh-cache="rm -f ~/.cache/{fzf,zoxide,starship,fnm-env,atuin}.zsh && exec zsh"
# xh for local mkcert-signed HTTPS: xh is rustls-built and ignores the macOS
# keychain, so it must be pointed at mkcert's root CA explicitly.
alias xhl='xh --verify "$HOME/Library/Application Support/mkcert/rootCA.pem"'

# ---- Ports ----
# ports            → list everything LISTENing on a TCP port
# killport 3000    → kill whatever listens on :3000
# killport         → fzf-pick listeners (Tab = multi-select) and kill them
ports() { lsof -iTCP -sTCP:LISTEN -P -n }
killport() {
    local pids
    if [[ -n "$1" ]]; then
        pids=$(lsof -ti tcp:"$1" -sTCP:LISTEN)
    else
        pids=$(lsof -iTCP -sTCP:LISTEN -P -n | fzf --header-lines=1 --multi | awk '{print $2}' | sort -u)
    fi
    if [[ -z "$pids" ]]; then
        echo "no matching listener"
        return 1
    fi
    # Show what is about to die — a container's port belongs to Docker's
    # forwarder, and killing that takes down Docker, not just the container.
    ps -p "${pids//$'\n'/,}" -o pid,comm
    echo "$pids" | xargs kill -9
}

# ---- FZF (cached) ----
FZF_CACHE="$HOME/.cache/fzf.zsh"
if [[ ! -f "$FZF_CACHE" ]]; then
    fzf --zsh > "$FZF_CACHE"
fi
source "$FZF_CACHE"

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
    fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
    fd --type=d --hidden --exclude .git . "$1"
}

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# The cd widget ships on Alt-C, which is dead on a Danish Mac layout
# (no macos-option-as-alt in Ghostty) — rebind it to Ctrl-O.
bindkey '^o' fzf-cd-widget

_fzf_comprun() {
    local command=$1
    shift
    case "$command" in
        cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
        export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
        ssh)          fzf --preview 'dig {}'                   "$@" ;;
        *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
    esac
}

# Lazy-load fzf-git.sh on first ctrl-g keypress
_lazy_fzf_git() {
    bindkey -r '^g'
    source ~/fzf-git.sh/fzf-git.sh
    zle -U $'\cg'
}
zle -N _lazy_fzf_git
bindkey '^g' _lazy_fzf_git

# ---- Plugins ----
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Must load AFTER syntax-highlighting. Type a prefix, then Up/Down cycles
# through history entries that start with it.
source /opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ---- Atuin (cached) ----
# Owns Ctrl-R (searchable, directory-aware history db). Up-arrow stays with
# history-substring-search via --disable-up-arrow.
ATUIN_CACHE="$HOME/.cache/atuin.zsh"
if [[ ! -f "$ATUIN_CACHE" ]]; then
    # grep strips atuin's "? on an empty line opens AI mode" binding —
    # a surprise trigger on a printable key. Ctrl-R is the only entry point.
    atuin init zsh --disable-up-arrow | grep -v "^bindkey '?'" > "$ATUIN_CACHE"
fi
source "$ATUIN_CACHE"

# ---- Starship Prompt (cached, keep at end) ----
# NOTE: do not name this STARSHIP_CACHE — that env var is read by starship
# itself as its log/cache *directory*, and a file at that path makes it error.
_STARSHIP_INIT_CACHE="$HOME/.cache/starship.zsh"
if [[ ! -f "$_STARSHIP_INIT_CACHE" ]]; then
    starship init zsh > "$_STARSHIP_INIT_CACHE"
fi
source "$_STARSHIP_INIT_CACHE"


# ---- Vite+ (dormant until used) ----
# fnm owns `node` by default; .zshenv puts Vite+ on PATH but fnm's prepend
# lands in front of it. The first `vp` call re-sources Vite+'s env, which
# moves its bin back to the front — from then on vp's node wins in this shell.
vp() {
    unfunction vp
    [[ -f "$HOME/.vite-plus/env" ]] && . "$HOME/.vite-plus/env"
    vp "$@"
}
export PATH="$HOME/.local/bin:$PATH"

# ---- gh-dash repo-scoped wrapper ----
# Rewrites the "All Open" filter to repo:<current> when run inside a repo.
ghd() {
    local repo
    if repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null); then
        gh dash --config <(sed "s|org:mediehusenemidtjylland|repo:$repo|" ~/.config/gh-dash/config.yml)
    else
        gh dash
    fi
}

# ---- Zoxide (cached) ----
# Keep this LAST: zoxide registers a chpwd hook and warns if anything else
# registers shell hooks after it (starship, syntax-highlighting, etc.).
# The doctor warning is a false positive here (it is last) — silence it.
export _ZO_DOCTOR=0
ZOXIDE_CACHE="$HOME/.cache/zoxide.zsh"
if [[ ! -f "$ZOXIDE_CACHE" ]]; then
    zoxide init zsh > "$ZOXIDE_CACHE"
fi
source "$ZOXIDE_CACHE"

# TEMP instrumentation — pairs with the zprof block at the top of this file.
{
    printf '==== %s pid=%d zshrc=%.0fms ====\n' \
        "$(strftime '%F %T' $EPOCHSECONDS)" $$ $(( (EPOCHREALTIME - _zshrc_t0) * 1000 ))
    zprof | head -12
} >> ~/.cache/zsh-startup-profile.log 2>/dev/null
unset _zshrc_t0
