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

-- if the completion engine supports the AI source,
-- use that instead of inline suggestions
vim.g.ai_cmp = true

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

-- When non-empty, this option determines the content of the area to the
-- side of a window, normally containing the fold, sign and number columns.
vim.o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]

-- Folds with a higher level will be closed by default.
-- Setting this to zero will allways keep all fold closed by default.
vim.o.foldlevel = 99

-- Fold method.
if vim.fn.has 'nvim-0.10' == 1 then
  vim.o.smoothscroll = true
  vim.o.foldexpr = "v:lua.require'ba.util'.ui.foldexpr()"
  vim.o.foldmethod = 'expr'
  vim.o.foldtext = ''
else
  vim.o.foldmethod = 'indent'
  vim.o.foldtext = "v:lua.require'ba.util'.ui.foldtext()"
end

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Make whitespace visible
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } -- replace certain whitespace characters

-- ---- indent behavior: keep file's style predictable ----
vim.o.autoindent = true
vim.o.smartindent = true
vim.o.copyindent = true
vim.o.preserveindent = true

-- [[ Other Configs ]]
_G.BA = {}
BA.config = require 'ba.config'
BA.util = require 'ba.util'

-- Load autocommands.
require 'ba.autocommands'

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

-- Install and run Lazy plugin manager.
require 'plugins.lazy'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
