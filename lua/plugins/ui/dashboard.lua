return {
  {
    'folke/snacks.nvim',
    ---@type snacks.Config
    opts = {
      dashboard = {
        enabled = true,
        -- your dashboard configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        sections = {
          { section = 'header' },
          { section = 'keys', gap = 1, padding = 1 },
          { section = 'startup' },
          {
            section = 'terminal',
            -- cmd = 'ascii-image-converter ~/Downloads/onizuka-3.jpeg -C -c -H 25',
            cmd = 'cat ~/.config/nvim/lua/plugins/ui/dashboard.ansi',
            -- random = 10,
            pane = 2,
            indent = 1,
            height = 35,
          },
        },
      },
    },
  },
}
