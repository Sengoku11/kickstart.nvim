-- This file is automatically loaded by ba.autocommands.init.

-- Filetype-local mappings grouped in one place.
local close_with_q_filetypes = { 'qf' }

vim.api.nvim_create_autocmd('FileType', {
  pattern = close_with_q_filetypes,
  callback = function(event)
    vim.keymap.set('n', 'q', '<cmd>close<CR>', {
      buffer = event.buf,
      silent = true,
      desc = 'Close quickfix window',
    })
  end,
})
