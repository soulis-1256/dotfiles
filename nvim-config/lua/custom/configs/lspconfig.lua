local base = require("plugins.configs.lspconfig")
local on_attach = base.on_attach
local capabilities = base.capabilities

local lspconfig = require("lspconfig")

lspconfig.clangd.setup {
  on_attach = function (client, bufnr)
    client.server_capabilities.signatureHelpProvides = false
    on_attach(client, bufnr)
  end,
  capabilities = capabilities,
  cmd = {
    "clangd",
    "--offset-encoding=utf-16"
  }
}

lspconfig.tsserver.setup {
  on_attach = on_attach,
  capabilities = capabilities
}
