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

--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader       = ' '
vim.g.maplocalleader  = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = false

-- [[ Setting options ]]
-- For more options see 
--  `:help vim.o`
--  `:help option-list`
--  `:help lua-options`
--  `:help lua-options-guide`
vim.o.number          = true  -- Make line numbers default
vim.o.relativenumber  = true  -- You can also add relative line numbers, to help with jumping.

vim.o.mouse       = 'a'     -- Enable mouse mode, can be useful for resizing splits for example!
vim.o.undofile    = true    -- Save undo history
vim.o.confirm     = true    -- raise a dialog if performing and operation that would fail (like `:q`)
vim.o.cursorline  = true    -- Show which line your cursor is on
vim.o.scrolloff   = 10      -- Minimal number of screen lines to keep above and below the cursor.
vim.o.showmode    = false   -- Don't show the mode, since it's already in the status line
vim.o.breakindent = true    -- Enable break indent
vim.o.ignorecase  = true    -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.smartcase   = true    -- ^
vim.o.signcolumn  = 'yes'   -- Keep signcolumn on by default
vim.o.updatetime  = 250     -- Decrease update time
vim.o.timeoutlen  = 300     -- Decrease mapped sequence wait time
vim.o.splitright  = true    -- Configure how new splits should be opened
vim.o.splitbelow  = true    -- ^
vim.o.inccommand  = 'split' -- Preview substitutions live, as you type!

-- Make whitespace visible
vim.o.list        = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } -- replace certain whitespace characters

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'

  -- Enable this block when running Neovim over SSH.
  -- It routes yanks through OSC52 for clipboard sync (fast, no lag),
  -- while leaving paste operations local for normal performance.
  -- You'll still be able to paste from your system clipboard with cmd+v or ctrl+shift+v.

  -- local function paste()
  --   local s = vim.fn.getreg '"'
  --   local t = vim.fn.getregtype '"'
  --   return { vim.split(s, '\n', { plain = true }), t }
  -- end

  -- vim.g.clipboard = {
  --   name = 'osc52-only-yank',
  --   copy = {
  --     ['+'] = require('vim.ui.clipboard.osc52').copy '+',
  --     ['*'] = require('vim.ui.clipboard.osc52').copy '*',
  --   },
  --   paste = { ['+'] = paste, ['*'] = paste },
  --   cache_enabled = 0,
  -- }
end)

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>',            { desc = 'Exit terminal mode' })

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

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

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

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
require('lazy').setup({
  { import = 'plugins.ui' },
  { import = 'plugins.editor' },

  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to automatically pass options to a plugin's `setup()` function, forcing the plugin to be loaded.
  --
  -- Alternatively, use `config = function() ... end` for full control over the configuration.
  -- If you prefer to call `setup` explicitly, use:
  --    {
  --        'lewis6991/gitsigns.nvim',
  --        config = function()
  --            require('gitsigns').setup({
  --                -- Your gitsigns configuration here
  --            })
  --        end,
  --    }

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },

  require 'kickstart.plugins.debug',
  require 'kickstart.plugins.indent_line',
  require 'kickstart.plugins.lint',
  require 'kickstart.plugins.autopairs',
  require 'kickstart.plugins.neo-tree',

  { import = 'plugins.coding' },
  { import = 'plugins.lang' },
  { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
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
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
