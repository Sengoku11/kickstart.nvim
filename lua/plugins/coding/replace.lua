return {
  {
    'MagicDuck/grug-far.nvim',
    event = 'VeryLazy',
    config = function()
      -- optional setup call to override plugin options
      -- alternatively you can set options with vim.g.grug_far = { ... }
      require('grug-far').setup {
        -- h: grug-far-opts
        icons = {
          -- whether to show icons
          enabled = vim.g.have_nerd_font,

          -- provider to use for file icons
          -- acceptable values: 'first_available', 'nvim-web-devicons', 'mini.icons', false (to disable)
          fileIconsProvider = 'first_available',

          actionEntryBullet = ' ',

          searchInput = ' ',
          replaceInput = ' ',
          filesFilterInput = 'f', -- ' ',
          flagsInput = '󰮚 ',
          pathsInput = ' ',

          resultsStatusReady = '󱩾 ',
          resultsStatusError = ' ',
          resultsStatusSuccess = '󰗡 ',
          resultsActionMessage = '  ',
          resultsEngineLeft = '⟪',
          resultsEngineRight = '⟫',
          resultsChangeIndicator = '┃',
          resultsAddedIndicator = '▒',
          resultsRemovedIndicator = '▒',
          resultsDiffSeparatorIndicator = '┊',
          historyTitle = '   ',
          helpTitle = ' 󰘥  ',
          lineNumbersEllipsis = ' ',

          newline = ' ',
        },
      }

      vim.keymap.set({ 'n', 'x' }, '<leader>sr', function()
        require('grug-far').open { visualSelectionUsage = 'operate-within-range', prefills = { search = vim.fn.expand '<cword>' } }
      end, { desc = 'grug-far: Search within range' })
    end,
  },
}
