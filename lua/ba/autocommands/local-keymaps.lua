-- Filetype-local mappings grouped in one place.
local close_with_q_filetypes = { 'qf', 'help' }

-- Map `q` to close for configured utility filetypes.
vim.api.nvim_create_autocmd('FileType', {
  pattern = close_with_q_filetypes,
  callback = function(event)
    vim.keymap.set('n', 'q', '<cmd>close<CR>', {
      buffer = event.buf,
      silent = true,
      desc = 'Close window',
    })
  end,
  desc = 'Map q to close for selected filetypes',
})
