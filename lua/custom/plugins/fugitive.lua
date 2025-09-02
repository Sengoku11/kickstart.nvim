return {
  {
    'tpope/vim-fugitive',
    dependencies = {
      'tpope/vim-rhubarb', -- GitHub GBrowse
      'shumphrey/fugitive-gitlab.vim', -- GitLab GBrowse
    },
    config = function()
      -- Optional keymaps
      vim.keymap.set('n', '<leader>gs', ':Git<CR>', { desc = 'Fugitive [g]it [s]tatus' })
      vim.keymap.set('n', '<leader>gb', ':GBrowse<CR>', { desc = 'Open [g]it page in [b]rowser' })
      vim.keymap.set('n', '<leader>gd', ':Gvdiffsplit<CR>', { desc = '[G]it [d]iff' })
    end,
  },
}
