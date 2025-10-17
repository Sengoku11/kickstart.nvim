return {
  {
    'smjonas/inc-rename.nvim',
    event = 'VeryLazy',
    enabled = true,
    config = function()
      require('inc_rename').setup {
        -- presets = { inc_rename = true },
      }

      vim.keymap.set('n', '<leader>rn', ':IncRename ', { desc = 'Rename' })

      -- If you want to fill in the word under the cursor you can use the following:
      -- vim.keymap.set('n', '<leader>rn', function()
      --   return ':IncRename ' .. vim.fn.expand '<cword>'
      -- end, { expr = true })
    end,
  },
}
