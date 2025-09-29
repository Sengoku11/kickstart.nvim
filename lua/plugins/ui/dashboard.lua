---@module 'snacks'
return {
  {
    'folke/snacks.nvim',
    ---@type snacks.Config
    opts = {
      ---@type table<string, snacks.win.Config>
      styles = {
        -- When opening the dashboard during startup, only the bo and wo options are used.
        -- The other options are used with :lua Snacks.dashboard()
        dashboard = {
          -- zindex = 10,
          -- height = 0,
          -- width = 0,
          bo = {
            bufhidden = 'wipe',
            buftype = 'nofile',
            buflisted = false,
            filetype = 'snacks_dashboard',
            swapfile = false,
            undofile = false,
          },
          wo = {
            colorcolumn = '',
            cursorcolumn = false,
            cursorline = false,
            foldmethod = 'manual',
            list = false,
            number = false,
            relativenumber = false,
            sidescrolloff = 0,
            signcolumn = 'no',
            spell = false,
            statuscolumn = '',
            statusline = '',
            winbar = '',
            winhighlight = 'Normal:SnacksDashboardNormal,NormalFloat:SnacksDashboardNormal',
            wrap = false,
          },
        },
      },
      dashboard = {
        preset = {
          -- stylua: ignore
          keys = {
            { icon = BA.config.icons.dashboard.find, key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
            { icon = BA.config.icons.dashboard.new_file, key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = BA.config.icons.dashboard.grep, key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = BA.config.icons.dashboard.recent, key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = BA.config.icons.dashboard.config, key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = BA.config.icons.dashboard.restore, key = 's', desc = 'Restore Session', section = 'session' },
            { icon = BA.config.icons.dashboard.lazy, key = 'l', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = BA.config.icons.dashboard.quit, key = 'q', desc = 'Quit', action = ':qa' },
          },
          header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        },
        enabled = true,
        -- your dashboard configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        sections = {
          { section = 'header' },
          { section = 'keys', gap = 1, padding = 2 },
          { icon = BA.config.icons.dashboard.projects, title = 'Projects', section = 'projects', indent = 2, padding = 2 },
          { section = 'startup' },
          {
            section = 'terminal',
            -- cmd = 'ascii-image-converter ~/Downloads/onizuka-3.jpeg -C -c -H 25',
            cmd = 'cat ~/.config/nvim/lua/plugins/ui/dashboard.ansi',
            random = 10,
            pane = 2,
            indent = 4,
            height = 35,
            width = 44,
          },
        },
      },
    },
  },
}
