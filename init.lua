--[[
==============================================================================
==============================================================================
========                                                              ========
========         .----------------------.   +----------+----------+   ========
========         |.-""""""""""""""""""-.|   |    *  *  |    ( *   |   ========
========         ||                    ||   |  *   *   |  *    *  |   ========
========         ||                    ||   +----------+----------+   ========
========         ||       NEOVIM       ||   |   *   *  | *   *    |   ========
========         ||                    ||   | *    *   |   *   *  |   ========
========         ||:h                  ||   +----------+----------+   ========
========         |'-..................-'|          ( ( (              ========
========         `"")----------------(""`          ) ) )              ========
========        /::::::::::|  |::::::::::\       .-------.            ========
========       /:::========|  |==hjkl==:::\      |      |             ========
========      '""""""""""""'  '""""""""""""'     '-------'            ========
========                                                              ========
==============================================================================
==============================================================================
--]]

--  NOTE: Must set before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = false

-- Set to true to do extra configuration if you run Neovim over SSH.
vim.g.is_remote = false

-- [[ Setting Options ]]
-- For more options see
--  `:help vim.o`
--  `:help option-list`
--  `:help lua-options`
--  `:help lua-options-guide`
vim.o.breakindent = true -- Enable break indent
vim.o.confirm = true -- raise a dialog if performing and operation that would fail (like `:q`)
vim.o.cursorline = true -- Show which line your cursor is on
vim.o.inccommand = 'split' -- Preview substitutions live, as you type!
vim.o.mouse = 'a' -- Enable mouse mode, can be useful for resizing splits for example!
vim.o.number = true -- Make line numbers default
vim.o.relativenumber = true -- You can also add relative line numbers, to help with jumping.
vim.o.scrolloff = 10 -- Minimal number of screen lines to keep above and below the cursor.
vim.o.showmode = false -- Don't show the mode, since it's already in the status line
vim.o.signcolumn = 'yes' -- Keep signcolumn on by default
vim.o.timeoutlen = 300 -- Decrease mapped sequence wait time
vim.o.undofile = true -- Save undo history
vim.o.updatetime = 250 -- Decrease update time

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Make whitespace visible
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } -- replace certain whitespace characters

-- [[ Other Configs ]]
_G.BA = {}
BA.config = require 'ba.config'

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open Quickfix List' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit Terminal Mode' })

-- See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- [[ Install plugins ]]
require('lazy').setup {
  spec = {
    { import = 'plugins.ui' },
    { import = 'plugins.editor' },
    { import = 'plugins.coding' },
    { import = 'plugins.lang' },
    { import = 'plugins.uncategorized' },
  },
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
}

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
