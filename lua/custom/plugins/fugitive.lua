return {
  {
    'tpope/vim-fugitive',
    dependencies = {
      'tpope/vim-rhubarb', -- GitHub GBrowse
      'shumphrey/fugitive-gitlab.vim', -- GitLab GBrowse
    },
    cmd = { 'G', 'Git', 'GBrowse' }, -- Lazy-load only when these are used
    config = function()
      -- Optional keymaps
      vim.keymap.set('n', '<leader>gs', ':Git<CR>', { desc = 'Fugitive status' })
      vim.keymap.set('n', '<leader>gb', ':GBrowse<CR>', { desc = 'Open in browser' })
    end,
  },
}
