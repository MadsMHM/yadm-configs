-- Kubernetes schema for yamlls on any YAML under a k8s/ directory
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      yamlls = {
        settings = {
          yaml = {
            schemas = {
              kubernetes = { "**/k8s/**/*.yaml", "**/k8s/**/*.yml" },
            },
          },
        },
      },
    },
  },
}
