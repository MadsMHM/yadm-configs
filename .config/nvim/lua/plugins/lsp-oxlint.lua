return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        oxlint = {
          settings = {
            -- typeAware stays OFF: `oxlint --lsp` spawns node_modules/.bin/tsgolint per
            -- lint run and never wait()s on it, so every run leaks one <defunct> child.
            -- Reproduced deterministically (didOpen -> 1 zombie, +1 per save; zero with
            -- this flag off) and still present in oxlint 1.79.0, the latest. It accrues
            -- ~30/hour per open repo, and macOS `ulimit -u` is 2666 — a nvim session left
            -- open for a few days exhausts the process table and fork() starts failing
            -- machine-wide (git's credential helper, `vp fmt`, `oxfmt` all die on EAGAIN).
            --
            -- Little is lost: vite.config.ts already sets `typeCheck: false` because
            -- tsgolint has no svelte2tsx, and `npm run check` (svelte-check) is the real
            -- type gate. `vp lint` still runs type-aware rules in CI and pre-commit.
            -- Re-enable once oxlint reaps the child; verify with `ps -Ao stat | grep -c Z`.
            typeAware = false,
            fixKind = "all",
          },
        },
      },
    },
  },
}
