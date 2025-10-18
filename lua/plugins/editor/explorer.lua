---@module 'snacks'
return {
  {
    'folke/snacks.nvim',
    ---@type snacks.Config
    opts = {
      explorer = {
        -- your explorer configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        enabled = true,
      },
      picker = {
        sources = {
          ---@class snacks.picker.explorer.Config: snacks.picker.files.Config|{}
          explorer = {
            -- your explorer picker configuration comes here
            -- or leave it empty to use the default settings
            finder = 'explorer',
            sort = { fields = { 'sort' } },
            supports_live = true,
            tree = true,
            watch = true,
            diagnostics = true,
            diagnostics_open = false,
            git_status = true,
            git_status_open = false,
            git_untracked = true,
            follow_file = true,
            focus = 'list',
            auto_close = false,
            jump = { close = false },
            layout = { preset = 'sidebar', preview = false },
            -- to show the explorer to the right, add the below to
            -- your config under `opts.picker.sources.explorer`
            -- layout = { layout = { position = "right" } },
            formatters = {
              file = { filename_only = true },
              severity = { pos = 'right' },
            },
            matcher = { sort_empty = false, fuzzy = false },
            config = function(opts)
              return require('snacks.picker.source.explorer').setup(opts)
            end,
            win = {
              list = {
                keys = {
                  ['<BS>'] = 'explorer_up',
                  ['l'] = 'confirm',
                  ['h'] = 'explorer_close', -- close directory
                  ['a'] = 'explorer_add',
                  ['d'] = 'explorer_del',
                  ['r'] = 'explorer_rename',
                  ['c'] = 'explorer_copy',
                  ['m'] = 'explorer_move',
                  ['o'] = 'explorer_open', -- open with system application
                  ['P'] = 'toggle_preview',
                  ['y'] = { 'explorer_yank', mode = { 'n', 'x' } },
                  ['p'] = 'explorer_paste',
                  ['u'] = 'explorer_update',
                  ['<c-c>'] = 'tcd',
                  ['<leader>/'] = 'picker_grep',
                  ['<c-t>'] = 'terminal',
                  ['.'] = 'explorer_focus',
                  ['I'] = 'toggle_ignored',
                  ['H'] = 'toggle_hidden',
                  ['s'] = { 'edit_vsplit', mode = 'n' },
                  ['Z'] = 'explorer_close_all',
                  [']g'] = 'explorer_git_next',
                  ['[g'] = 'explorer_git_prev',
                  [']d'] = 'explorer_diagnostic_next',
                  ['[d'] = 'explorer_diagnostic_prev',
                  [']w'] = 'explorer_warn_next',
                  ['[w'] = 'explorer_warn_prev',
                  [']e'] = 'explorer_error_next',
                  ['[e'] = 'explorer_error_prev',
                },
              },
            },
          },
        },
      },
    },
  },
}
