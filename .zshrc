
# ---- Core Zsh Settings ----
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_FIND_NO_DUPS INC_APPEND_HISTORY
setopt AUTO_CD CORRECT

set -o vi
# Fix for backspace in vi mode
bindkey -v '^?' backward-delete-char

# ---- Environment ----
export EDITOR=nvim
export BAT_THEME=tokyonight_night

# ---- Bun ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ---- fnm (fast nvm replacement) ----
export PATH="$HOME/.local/share/fnm:$PATH"
FNM_CACHE="$HOME/.cache/fnm-env.zsh"
if [[ ! -f "$FNM_CACHE" ]]; then
    fnm env --use-on-cd > "$FNM_CACHE"
fi
source "$FNM_CACHE"

# ---- Yazi ----
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
alias clear-zsh-cache="rm -f ~/.cache/{fzf,zoxide,starship,fnm-env}.zsh && exec zsh"

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

source ~/fzf-git.sh/fzf-git.sh

# ---- Zoxide (cached) ----
ZOXIDE_CACHE="$HOME/.cache/zoxide.zsh"
if [[ ! -f "$ZOXIDE_CACHE" ]]; then
    zoxide init zsh > "$ZOXIDE_CACHE"
fi
source "$ZOXIDE_CACHE"

# ---- Plugins ----
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Zellij ----
eval "$(zellij setup --generate-auto-start zsh)"

# ---- Starship Prompt (cached, keep at end) ----
STARSHIP_CACHE="$HOME/.cache/starship.zsh"
if [[ ! -f "$STARSHIP_CACHE" ]]; then
    starship init zsh > "$STARSHIP_CACHE"
fi
source "$STARSHIP_CACHE"

