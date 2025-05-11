-- lua/custom/plugins/daml.lua
return {
  ------------------------------------------------------------------
  --  syntax
  ------------------------------------------------------------------
  { 'obsidiansystems/daml.vim', ft = 'daml' },

  ------------------------------------------------------------------
  --  language-server
  ------------------------------------------------------------------
  {
    'neovim/nvim-lspconfig',
    ft = 'daml', -- ← loads only when a .daml file opens
    config = function()
      local configs = require 'lspconfig.configs'
      local lspconfig = require 'lspconfig'
      local util = require 'lspconfig.util'

      -- ❶ register once – use the public name **daml**
      if not configs.daml then
        configs.daml = {
          default_config = {
            cmd = { 'daml', 'damlc', 'ide', '--scenarios=no', '--RTS', '+RTS', '-M4G', '-N' },
            filetypes = { 'daml' },
            root_dir = util.root_pattern('daml.yaml', '.git'),
            single_file_support = true,
          },
        }
      end

      -- ❷ capabilities (blink.cmp when present)
      local caps = vim.lsp.protocol.make_client_capabilities()
      local ok_cmp, cmp = pcall(require, 'blink.cmp')
      if ok_cmp then
        caps = cmp.get_lsp_capabilities()
      end

      -- ❸ start / attach
      lspconfig.daml.setup { capabilities = caps }
    end,
  },
}
