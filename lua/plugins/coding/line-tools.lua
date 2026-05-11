return {
  {
    'Sengoku11/line-tools.nvim',
    keys = {
      -- List markers
      { '<leader>lb',  ':BulletLines<CR>',           mode = { 'n', 'x' }, desc = 'LT: bullet lines' },
      { '<leader>lh',  ':HyphenLines<CR>',           mode = { 'n', 'x' }, desc = 'LT: hyphen lines' },
      { '<leader>ln',  ':NumberLines<CR>',           mode = { 'n', 'x' }, desc = 'LT: number lines' },
      { '<leader>lR',  ':RomanLines<CR>',            mode = { 'n', 'x' }, desc = 'LT: roman lines' },
      { '<leader>ll',  ':LetterLines<CR>',           mode = { 'n', 'x' }, desc = 'LT: letter lines' },
      { '<leader>lL',  ':CapitalLetterLines<CR>',    mode = { 'n', 'x' }, desc = 'LT: capital letter lines' },

      -- Cleanup
      { '<leader>lr',  ':CleanLines<CR>',            mode = { 'n', 'x' }, desc = 'LT: clean markers' },

      -- Comments
      { '<leader>lc',  ':ToggleCommentLines<CR>',    mode = { 'n', 'x' }, desc = 'LT: toggle comments' },

      -- Indentation
      { '<leader>l>',  ':IndentLines<CR>',           mode = { 'n', 'x' }, desc = 'LT: indent lines' },
      { '<leader>l<',  ':OutdentLines<CR>',          mode = { 'n', 'x' }, desc = 'LT: outdent lines' },

      -- Sorting
      { "<leader>lsa", ":SortLines<CR>",             mode = { "n", "x" }, desc = "LT: sort A-Z" },
      { "<leader>lsA", ":SortLinesDesc<CR>",         mode = { "n", "x" }, desc = "LT: sort Z-A" },
      { "<leader>lsl", ":SortLinesByLength<CR>",     mode = { "n", "x" }, desc = "LT: sort shortest first" },
      { "<leader>lsL", ":SortLinesByLengthDesc<CR>", mode = { "n", "x" }, desc = "LT: sort longest first" },
    },
    opts = {},
  },
}
