-- Adds git related signs to the gutter, as well as utilities for managing changes
-- NOTE: gitsigns is already included in init.lua but contains only the base
-- config. This will add also the recommended keymaps.

return {
  {
    'tpope/vim-fugitive',
    event = 'VeryLazy',
    dependencies = {
      'tpope/vim-rhubarb', -- GitHub GBrowse
      'shumphrey/fugitive-gitlab.vim', -- GitLab GBrowse
    },
    config = function()
      -- Optional keymaps
      vim.keymap.set('n', '<leader>gg', ':Git<CR>', { desc = 'Git Fugitive' })
      vim.keymap.set('n', '<leader>gb', ':GBrowse<CR>', { desc = 'Open Git Page in Browser' })
      vim.keymap.set('n', '<leader>gd', ':Gvdiffsplit<CR>', { desc = 'Git Diff' })
    end,
  },
  {
    'lewis6991/gitsigns.nvim',
    event = 'VeryLazy',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next git change' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous git change' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git stage hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'git reset hunk' })
        -- normal mode
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'Stage Hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'Reset Hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'Stage Buffer' })
        map('n', '<leader>hu', gitsigns.stage_hunk, { desc = 'Undo Stage Hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'Reset Buffer' })
        map('n', '<leader>hh', gitsigns.preview_hunk, { desc = 'Hunk Hovered' })
        map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'Hunk Inline' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'Blame Line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'Diff against Index' })
        -- map('n', '<leader>hD', function() gitsigns.diffthis '@' end, { desc = 'git Diff against last commit' }) -- better use fugitive
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = 'Toggle Git Blame' })
        map('n', '<leader>tD', gitsigns.preview_hunk_inline, { desc = 'Toggle Show Deleted' })
      end,
    },
  },
}
