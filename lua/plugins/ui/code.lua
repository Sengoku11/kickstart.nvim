return {
  { -- Add indentation guides (vertical lines for blocks) even on blank lines.
    -- See `:help ibl`
    'lukas-reineke/indent-blankline.nvim',
    event = 'VeryLazy',
    main = 'ibl',
    opts = {},
  },
  { -- Finds and lists all of the TODO, HACK, BUG, etc comment
    -- in your project and loads them into a browsable list.
    'folke/todo-comments.nvim',
    event = 'VeryLazy',
    cmd = { 'TodoTrouble', 'TodoTelescope' },
    opts = {
      keywords = {
        FIX = {
          icon = BA.config.icons.todo.fix, -- icon used for the sign, and in search results
          color = 'error', -- can be a hex color, or a named color (see below)
          alt = { 'FIXME', 'BUG', 'FIXIT', 'ISSUE' }, -- a set of other keywords that all map to this FIX keywords
          -- signs = false, -- configure signs for some keywords individually
        },
        TODO = { icon = BA.config.icons.todo.todo, color = 'info', alt = { 'TODO' } },
        HACK = { icon = BA.config.icons.todo.hack, color = 'warning' },
        WARN = { icon = BA.config.icons.todo.warn, color = 'warning', alt = { 'WARNING', 'XXX' } },
        PERF = { icon = BA.config.icons.todo.perf, alt = { 'OPTIM', 'PERFORMANCE', 'OPTIMIZE' } },
        NOTE = { icon = BA.config.icons.todo.note, color = 'hint', alt = { 'INFO' } },
        TEST = { icon = BA.config.icons.todo.test, color = 'test', alt = { 'TESTING', 'PASSED', 'FAILED' } },
      },
    },
    -- stylua: ignore
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next Todo Comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous Todo Comment" },
      { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "Search Todo (Trouble)" },
      { "<leader>xT", "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>", desc = "Todo/Fix/Fixme (Trouble)" },
      { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Search Todo" },
      { "<leader>sT", "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>", desc = "Search Todo/Fix/Fixme" },
    },
  },
}
