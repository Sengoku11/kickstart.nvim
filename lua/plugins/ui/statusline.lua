---@module 'snacks'
return {
  -- statusline
  {
    'nvim-lualine/lualine.nvim',
    enabled = true,
    event = 'VeryLazy',
    init = function()
      vim.g.lualine_laststatus = vim.o.laststatus
      if vim.fn.argc(-1) > 0 then
        -- set an empty statusline till lualine loads
        vim.o.statusline = ' '
      else
        -- hide the statusline on the starter page
        vim.o.laststatus = 0
      end
    end,
    opts = function()
      -- PERF: we don't need this lualine require madness 🤷
      local lualine_require = require 'lualine_require'
      lualine_require.require = require

      -- local icons = LazyVim.config.icons

      vim.o.laststatus = vim.g.lualine_laststatus

      local opts = {
        options = {
          theme = 'auto',
          globalstatus = vim.o.laststatus == 3,
          disabled_filetypes = { statusline = { 'dashboard', 'alpha', 'ministarter', 'snacks_dashboard' } },
          component_separators = BA.config.icons.lualine.component_separators,
          section_separators = BA.config.icons.lualine.section_separators,
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { { 'branch', icon = BA.config.icons.git.branch } },
          lualine_c = {
            { 'diagnostics' },
            { 'filename' },
            {
              'diff',
              symbols = {
                added = BA.config.icons.git.added,
                modified = BA.config.icons.git.modified,
                removed = BA.config.icons.git.removed,
              },
              source = function()
                local gitsigns = vim.b.gitsigns_status_dict
                if gitsigns then
                  return {
                    added = gitsigns.added,
                    modified = gitsigns.changed,
                    removed = gitsigns.removed,
                  }
                end
              end,
            },
          },

          lualine_x = { 'filesize' },
          lualine_y = {
            { 'filetype' },
            { 'progress', separator = ' ', padding = { left = 1, right = 0 } },
            { 'location', padding = { left = 0, right = 1 } },
          },
          lualine_z = {
            function()
              return BA.config.icons.kinds.Clock .. os.date '%R'
            end,
          },
        },
        extensions = { 'neo-tree', 'lazy', 'fzf' },
      }

      return opts
    end,
  },
}
