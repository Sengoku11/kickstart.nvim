return {
  {
    'echasnovski/mini.nvim',
    event = 'VeryLazy',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - Visually select Around )paren
      --  - yinq - Yank Inside Next Quote
      --  - ci'  - Change Inside 'quote
      require('mini.ai').setup { n_lines = 500 }
    end,
  },
}
