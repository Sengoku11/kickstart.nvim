---@module 'snacks'
return {
  'aznhe21/actions-preview.nvim',
  event = 'VeryLazy',
  config = function()
    require('actions-preview').setup {
      diff = {
        ctxlen = 3,
      },

      -- priority list of external command to highlight diff
      -- disabled by defalt, must be set by yourself
      highlight_command = {
        -- require("actions-preview.highlight").delta(),
        -- require("actions-preview.highlight").diff_so_fancy(),
        -- require("actions-preview.highlight").diff_highlight(),
      },

      -- priority list of preferred backend
      backend = { 'snacks', 'telescope', 'minipick', 'nui' },

      -- options for nui.nvim components
      nui = {
        -- component direction. "col" or "row"
        dir = 'col',
        -- keymap for selection component: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/menu#keymap
        keymap = nil,
        -- options for nui Layout component: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/layout
        layout = {
          position = '50%',
          size = {
            width = '60%',
            height = '90%',
          },
          min_width = 40,
          min_height = 10,
          relative = 'editor',
        },
        -- options for preview area: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup
        preview = {
          size = '60%',
          border = {
            style = 'rounded',
            padding = { 0, 1 },
          },
        },
        -- options for selection area: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/menu
        select = {
          size = '40%',
          border = {
            style = 'rounded',
            padding = { 0, 1 },
          },
        },
      },

      --- options for snacks picker
      ---@type snacks.picker.Config
      snacks = {
        layout = { preset = 'default' },
      },
    }

    vim.keymap.set({ 'v', 'n' }, 'ga', require('actions-preview').code_actions, { desc = 'Code actions' })
  end,
}
