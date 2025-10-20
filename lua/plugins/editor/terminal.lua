---@module 'snacks'
return {
  {
    'folke/snacks.nvim',
    event = 'VeryLazy',
    ---@type snacks.Config
    opts = {
      terminal = {
        -- your terminal configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      },
    },
    keys = {
      -- stylua: ignore
      {'<leader>tt', function() Snacks.terminal() end, desc = "Terminal (cwd)" },
    },
  },
}
