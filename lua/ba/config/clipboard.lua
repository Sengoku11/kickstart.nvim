-- This file is automatically loaded by ba.config.init.

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'

  -- Route yanks through OSC52 for clipboard sync (fast, no lag),
  -- while leaving paste operations local for normal performance.
  -- You'll still be able to paste from your system clipboard with cmd+v or ctrl+shift+v.
  if vim.g.is_remote then
    local function paste()
      local s = vim.fn.getreg '"'
      local t = vim.fn.getregtype '"'
      return { vim.split(s, '\n', { plain = true }), t }
    end

    vim.g.clipboard = {
      name = 'osc52-only-yank',
      copy = {
        ['+'] = require('vim.ui.clipboard.osc52').copy '+',
        ['*'] = require('vim.ui.clipboard.osc52').copy '*',
      },
      paste = { ['+'] = paste, ['*'] = paste },
      cache_enabled = 0,
    }
  end
end)
