return {
  'mbbill/undotree',
  -- Load the plugin when these keys/commands are used
  keys = {
    { '<leader>u', '<cmd>UndotreeToggle<cr>', desc = 'Toggle UndoTree' },
  },
  cmd = { 'UndotreeToggle', 'UndotreeShow', 'UndotreeHide' },

  init = function()
    -- optional tweaks
    vim.g.undotree_WindowLayout = 2
    vim.g.undotree_DiffpanelHeight = 8
    vim.g.undotree_SetFocusWhenToggle = 1 -- focus the Undotree window on toggle
  end,
}
