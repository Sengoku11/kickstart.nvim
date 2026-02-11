return {
  {
    'nvim-neotest/neotest',
    optional = true,
    opts = {
      icons = {
        expanded = '-',
        collapsed = '+',
        child_prefix = '|-',
        final_child_prefix = '`-',
        child_indent = '| ',
        non_collapsible = '-',
        passed = 'OK',
        running = '->',
        failed = 'XX',
        skipped = '--',
        unknown = '??',
      },
    },
  },
}
