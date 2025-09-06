-- ~/.config/nvim/after/ftplugin/daml.lua
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.softtabstop = 2

-- Treat *.daml as Haskell for Tree-sitter
vim.treesitter.language.register('haskell', 'daml')

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'daml',
  callback = function()
    vim.bo.indentexpr = 'GetHaskellIndent()'
    vim.b.did_indent = 1 -- keep other scripts from resetting it
  end,
})
