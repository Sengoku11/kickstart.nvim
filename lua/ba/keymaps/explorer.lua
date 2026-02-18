local explorer = require 'ba.util.explorer'

-- Routes <leader>e to Neo-tree in JVM roots, otherwise keeps Snacks explorer.
vim.keymap.set('n', '<leader>e', explorer.open, {
  desc = 'Explorer',
  silent = true,
})
