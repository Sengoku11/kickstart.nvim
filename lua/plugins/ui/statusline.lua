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

      -- [[ Noice Integration ]]
      -- stylua: ignore start
      local has_noice        = function() local ok, n = pcall(require, 'noice'); return ok and n.api and n.api.status end
      local noice_cmd_get    = function() local ok, n = pcall(require, 'noice'); return (ok and n.api.status.command.get()) or '' end
      local noice_cmd_has    = function() local ok, n = pcall(require, 'noice'); return ok and n.api.status.command.has() end
      local noice_mode_get   = function() local ok, n = pcall(require, 'noice'); return (ok and n.api.status.mode.get()) or '' end
      local noice_mode_has   = function() local ok, n = pcall(require, 'noice'); return ok and n.api.status.mode.has() end
      local noice_search_has = function() local ok, n = pcall(require, 'noice'); return ok and n.api.status.search.has() end
      local noice_search_get = function() local ok, n = pcall(require, 'noice'); return ok and n.api.status.search.get() end
      local color_of         = function(hl) local ok, S = pcall(require, 'snacks'); return (ok and S.util and S.util.color) and { fg = S.util.color(hl) } or nil end
      -- stylua: ignore end

      local opts = {
        options = {
          icons_enabled = vim.g.have_nerd_font,
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
            {
              'diagnostics',
              symbols = {
                error = BA.config.icons.statusline_diagnostics.Error,
                warn = BA.config.icons.statusline_diagnostics.Warn,
                info = BA.config.icons.statusline_diagnostics.Info,
                hint = BA.config.icons.statusline_diagnostics.Hint,
              },
            },
            { 'filename', path = 1 },
            { 'navic', color_correction = 'dynamic' },
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
          lualine_x = {
            -- stylua: ignore start
            { noice_cmd_get,  cond = function() return has_noice() and noice_cmd_has() end,  color = function() return color_of('Statement') end },
            { noice_mode_get, cond = function() return has_noice() and noice_mode_has() end, color = function() return color_of('Constant') end },
            -- { noice_search_get, cond = function() return has_noice() and noice_search_has() end, color = function() return color_of('Constant') end },
            -- -- stylua: ignore end
            'filesize',
          },
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
