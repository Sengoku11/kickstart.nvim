return {
  {
    'MagicDuck/grug-far.nvim',
    event = 'VeryLazy',
    -- Note (lazy loading): grug-far.lua defers all it's requires so it's lazy by default
    -- additional lazy config to defer loading is not really needed...
    config = function()
      -- optional setup call to override plugin options
      -- alternatively you can set options with vim.g.grug_far = { ... }
      require('grug-far').setup {
        -- options, see Configuration section below
        -- there are no required options atm
      }

      vim.keymap.set({ 'n', 'x' }, '<leader>sr', function()
        require('grug-far').open { visualSelectionUsage = 'operate-within-range', prefills = { search = vim.fn.expand '<cword>' } }
      end, { desc = 'grug-far: Search within range' })
    end,
  },
}
