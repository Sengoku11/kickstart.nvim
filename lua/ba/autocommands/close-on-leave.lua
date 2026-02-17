-- This file is automatically loaded by ba.autocommands.init.

-- `true` = always close on leave, `function(bufnr)` = conditional close.
local close_on_leave_rules = {
  -- help = true,
  fugitive = function(bufnr)
    -- `fugitive` filetype includes many views; close only status buffer.
    return vim.b[bufnr].fugitive_type == 'index'
  end,
}

-- Auto-close configured buffers when focus leaves them.
vim.api.nvim_create_autocmd('FileType', {
  pattern = vim.tbl_keys(close_on_leave_rules),
  callback = function(event)
    if vim.b[event.buf].ba_close_on_leave then
      return
    end

    local rule = close_on_leave_rules[vim.bo[event.buf].filetype]
    local should_close = rule == true or (type(rule) == 'function' and rule(event.buf))
    if not should_close then
      return
    end

    vim.b[event.buf].ba_close_on_leave = true

    -- After leaving this buffer, close any window still showing it.
    vim.api.nvim_create_autocmd('BufLeave', {
      buffer = event.buf,
      callback = function(ev)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(ev.buf) then
            return
          end
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == ev.buf then
              pcall(vim.api.nvim_win_close, win, true)
            end
          end
        end)
      end,
      desc = 'Close matching special windows when leaving them',
    })
  end,
  desc = 'Auto-close selected buffers when leaving them',
})
