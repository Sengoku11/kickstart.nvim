-- basic: enable spell in text-y filetypes
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'gitcommit', 'text' },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { 'en_us' } -- or { "en_gb" }, etc.
  end,
})

-- optional: spell only in comments/strings for code (Tree-sitter does the scoping)
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'lua', 'python', 'rust', 'go', 'typescript', 'javascript' },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- vim.keymap.set('n', '<leader>sn', ']s', { desc = 'Next spelling error' })
-- vim.keymap.set('n', '<leader>sp', '[s', { desc = 'Prev spelling error' })
-- vim.keymap.set('n', '<leader>ss', 'z=', { desc = 'Spelling suggestions' })
-- vim.keymap.set('n', '<leader>sg', 'zg', { desc = 'Mark word as good' })
-- vim.keymap.set('n', '<leader>sw', 'zw', { desc = 'Mark word as wrong' })
