---@module 'snacks'
return {
  -- lazy.nvim
  {
    'folke/snacks.nvim',
    ---@type snacks.Config
    opts = {
      notifier = {
        -- your notifier configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        icons = BA.config.icons.notifier,
      },
    },
  },
}
