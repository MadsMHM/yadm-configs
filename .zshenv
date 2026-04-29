# Optional sources — guard so a missing tool doesn't break shell startup
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
[[ -f "$HOME/.vite-plus/env" ]] && . "$HOME/.vite-plus/env"
