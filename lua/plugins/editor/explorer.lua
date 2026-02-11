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
        actions = {
          explorer_paste_rename = function(picker)
            local Tree = require 'snacks.explorer.tree'
            local actions = require 'snacks.explorer.actions'
            local files = vim.split(vim.fn.getreg(vim.v.register or '+') or '', '\n', { plain = true })
            files = vim.tbl_filter(function(file)
              return file ~= '' and vim.fn.filereadable(file) == 1
            end, files)

            if #files == 0 then
              return Snacks.notify.warn(('The `%s` register does not contain any files'):format(vim.v.register or '+'))
            elseif #files == 1 then
              local file = files[1]
              local base = vim.fn.fnamemodify(file, ':t')
              local dir = picker:dir()
              Snacks.input({
                prompt = 'Rename pasted file',
                default = base,
              }, function(value)
                if not value or value:find '^%s*$' then
                  return
                end
                local uv = vim.uv or vim.loop
                local target = vim.fs.normalize(dir .. '/' .. value)
                if uv.fs_stat(target) then
                  return Snacks.notify.warn('File already exists:\n- `' .. target .. '`')
                end
                Snacks.picker.util.copy_path(file, target)
                Tree:refresh(dir)
                Tree:open(dir)
                actions.update(picker, { target = target })
              end)
            else
              local dir = picker:dir()
              local uv = vim.uv or vim.loop
              for _, file in ipairs(files) do
                local base = vim.fn.fnamemodify(file, ':t')
                local target = vim.fs.normalize(dir .. '/' .. base)
                local name, ext = base:match '^(.*)%.(.*)$'
                name = name or base
                ext = ext and ('.' .. ext) or ''

                local count = 1
                while uv.fs_stat(target) do
                  target = vim.fs.normalize(dir .. '/' .. name .. '_' .. count .. ext)
                  count = count + 1
                end

                Snacks.picker.util.copy_path(file, target)
              end
              Tree:refresh(dir)
              Tree:open(dir)
              actions.update(picker, { target = dir })
            end
          end,
        },
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
            actions = {
              recursive_toggle = function(picker, item)
                local Actions = require 'snacks.explorer.actions'
                local Tree = require 'snacks.explorer.tree'

                local get_children = function(node)
                  local children = {}
                  for _, child in pairs(node.children or {}) do
                    table.insert(children, child)
                  end
                  return children
                end

                local refresh = function()
                  Actions.update(picker, { refresh = true })
                end

                ---@param node snacks.picker.explorer.Node
                local function toggle_recursive(node)
                  Tree:toggle(node.path)
                  refresh()
                  vim.schedule(function()
                    local children = get_children(node)
                    if #children ~= 1 then
                      return
                    end
                    local child = children[1]
                    if not child.dir then
                      return
                    end
                    toggle_recursive(child)
                  end)
                end

                if not item or not item.file then
                  return
                end

                local node = Tree:node(item.file)
                if not node then
                  return
                end

                if node.dir then
                  toggle_recursive(node)
                else
                  picker:action 'confirm'
                end
              end,
            },
            win = {
              list = {
                keys = {
                  ['<CR>'] = 'recursive_toggle',
                  ['<BS>'] = 'explorer_up',
                  ['l'] = 'recursive_toggle',
                  ['h'] = 'explorer_close', -- close directory
                  ['a'] = 'explorer_add',
                  ['d'] = 'explorer_del',
                  ['r'] = 'explorer_rename',
                  ['c'] = 'explorer_copy',
                  ['m'] = 'explorer_move',
                  ['o'] = 'explorer_open', -- open with system application
                  ['V'] = 'toggle_preview',
                  ['y'] = { 'explorer_yank', mode = { 'n', 'x' } },
                  ['p'] = 'explorer_paste',
                  ['P'] = 'explorer_paste_rename',
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
