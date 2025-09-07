local util = require 'lspconfig.util'
local configs = require 'lspconfig.configs'

-- Create a new config for DAML LSP.
if not configs.daml then
  configs.daml = {
    default_config = {
      cmd = { 'daml', 'damlc', 'ide', '--scenarios=yes', '--RTS', '+RTS', '-M4G', '-N' }, -- DA docs :contentReference[oaicite:0]{index=0}
      filetypes = { 'daml' },
      root_dir = util.root_pattern('daml.yaml', '.git'),
      single_file_support = true,
    },
  }
end

-- Setup DAML LSP.
require('lspconfig').daml.setup {
  capabilities = require('blink.cmp').get_lsp_capabilities(),
}

-- Treat *.daml as Haskell for Tree-sitter
-- The daml.vim plugin provides basic syntax highliting,
-- but mapping DAML to Haskell improves highliting coverage.
vim.treesitter.language.register('haskell', 'daml')

-- Optional, to keep Haskell indentation.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'daml',
  callback = function()
    vim.bo.indentexpr = 'GetHaskellIndent()'
    vim.b.did_indent = 1 -- keep other scripts from resetting it
  end,
})

return { -- Adds syntax highlighting.
  { 'obsidiansystems/daml.vim', ft = 'daml' },
}
