---@module 'snacks'
return {
  {
    'folke/snacks.nvim',

    init = function()
      -- Custom operator for <leader>s{motion} to grep the text covered by that motion
      vim.SnacksGrepOperator = function(optype)
        if optype == 'block' then
          return
        end

        local regtype = (optype == 'line') and 'V' or 'v'
        local lines = vim.fn.getregion(vim.fn.getpos "'[", vim.fn.getpos "']", { type = regtype })

        local text = vim.trim(table.concat(lines, ' '))
        if text == '' then
          return
        end

        Snacks.picker.grep {
          search = text,
          regex = false,
        }
      end
    end,

    opts = {
      picker = {
        win = {
          input = {
            -- stylua: ignore
            keys = { ['<a-c>'] = { 'toggle_cwd', mode = { 'n', 'i' } } },
          },
        },
        prompt = ' > ',
        ---@field icons? snacks.picker.icons
        icons = {
          files = {
            enabled = vim.g.have_nerd_font,
            -- dir = BA.config.icons.kinds.Folder,
            -- dir_open = BA.config.icons.kinds.FolderOpen,
            -- file = '* ',
          },
          keymaps = {
            nowait = '󰓅 ',
          },
          tree = {
            vertical = '│ ',
            middle = '├╴',
            last = '└╴',
          },
          undo = {
            saved = ' ',
          },
          ui = {
            live = '󰐰 ',
            hidden = 'h',
            ignored = 'i',
            follow = 'f',
            selected = '● ',
            unselected = '○ ',
          },
          diagnostics = BA.config.icons.explorer_diagnostics,
        },
        ---@class snacks.picker.previewers.Config
        previewers = {
          diff = {
            -- fancy: Snacks fancy diff (borders, multi-column line numbers, syntax highlighting)
            -- syntax: Neovim's built-in diff syntax highlighting
            -- terminal: external command (git's pager for git commands, `cmd` for other diffs)
            style = 'fancy', ---@type "fancy"|"syntax"|"terminal"
          },
          git = {
            args = {}, -- additional arguments passed to the git command. Useful to set pager options usin `-c ...`
          },
        },
      },
    },

    -- stylua: ignore
    keys = {
      -- Top Pickers & Explorer
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notification History" },
      { "<leader>e", function() Snacks.explorer() end, desc = "Explorer" },
      { "\\", function() Snacks.explorer() end, desc = "Explorer" },

      -- find
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
      { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },

      -- git
      { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
      { "<leader>gL", function() Snacks.picker.git_log_line() end, desc = "Git Log Line" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
      { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git Stash" },
      { "<leader>gD", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },
      { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git Log File" },

      -- Grep
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Visual selection or word", mode = { "n", "x" } },
      -- operator-pending grep by motion, e.g. <leader>siw, <leader>sab, <leader>sip
      { "<leader>s", function() vim.go.operatorfunc = "v:lua.vim.SnacksGrepOperator" return "g@" end, expr = true, desc = "Grep by motion" },

      -- search
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
      { "<leader>sA", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
      { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
      { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
      { "<leader>sI", function() Snacks.picker.icons() end, desc = "Icons" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
      { "<leader>sp", function() Snacks.picker.pickers() end, desc = "Pickers" },
      { "<leader>sP", function() Snacks.picker.lazy() end, desc = "Search for Plugin Spec" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
      { "<leader>s.", function() Snacks.picker.resume() end, desc = "Repeat" },
      { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo History" },
      { "<leader>uc", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },

      -- LSP
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
      { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
      { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
      -- { "gai", function() Snacks.picker.lsp_incoming_calls() end, desc = "C[a]lls Incoming" },
      -- { "gao", function() Snacks.picker.lsp_outgoing_calls() end, desc = "C[a]lls Outgoing" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
    },
  },

  {
    'folke/todo-comments.nvim',
    optional = true,
    -- stylua: ignore
    keys = {
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo" },
      { "<leader>sT", function () Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end, desc = "Todo/Fix/Fixme" },
    },
  },

  {
    'folke/snacks.nvim',
    opts = function(_, opts)
      table.insert(opts.dashboard.preset.keys, 3, {
        icon = BA.config.icons.dashboard.projects,
        key = 'p',
        desc = 'Projects',
        action = ':lua Snacks.picker.projects()',
      })
    end,
  },

  {
    'folke/flash.nvim',
    optional = true,
    specs = {
      {
        'folke/snacks.nvim',
        opts = {
          picker = {
            win = {
              input = {
                keys = {
                  ['<a-s>'] = { 'flash', mode = { 'n', 'i' } },
                  ['s'] = { 'flash' },
                },
              },
            },
            actions = {
              flash = function(picker)
                require('flash').jump {
                  pattern = '^',
                  label = { after = { 0, 0 } },
                  search = {
                    mode = 'search',
                    exclude = {
                      function(win)
                        return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'snacks_picker_list'
                      end,
                    },
                  },
                  action = function(match)
                    local idx = picker.list:row2idx(match.pos[1])
                    picker.list:_move(idx, true, true)
                  end,
                }
              end,
            },
          },
        },
      },
    },
  },
}
