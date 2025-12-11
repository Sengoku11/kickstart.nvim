vim.opt.spell = true
vim.opt.spelllang = { 'en_us' }
vim.opt.spelloptions = 'camel'

-- Global dev spellfile (versioned in dotfiles repo)
local global_spell = vim.fn.stdpath 'config' .. '/spell/en.utf-8.add'

-- Local machine-wide spellfile
local local_spell_dir = vim.fn.stdpath 'data' .. '/spell'
if vim.fn.isdirectory(local_spell_dir) == 0 then
  vim.fn.mkdir(local_spell_dir, 'p')
end
local local_spell = local_spell_dir .. '/local.en.utf-8.add'

-- Order matters:
--   1st = local (machine) → `zg`
--   2nd = global (synced) → `2zg`
vim.opt.spellfile = { local_spell, global_spell }

-- vim.keymap.set('n', '<leader>sn', ']s', { desc = 'Next spelling error' })
-- vim.keymap.set('n', '<leader>sp', '[s', { desc = 'Prev spelling error' })
-- vim.keymap.set('n', '<leader>ss', 'z=', { desc = 'Spelling suggestions' })
-- vim.keymap.set('n', '<leader>sg', 'zg', { desc = 'Mark word as good' })
-- vim.keymap.set('n', '<leader>sw', 'zw', { desc = 'Mark word as wrong' })
