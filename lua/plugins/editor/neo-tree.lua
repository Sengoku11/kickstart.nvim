--- @module 'snacks'
-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    'MunifTanjim/nui.nvim',
  },
  event = 'UIEnter',
  keys = {
    -- { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
    { '<leader>os', ':Neotree git_status<CR>', desc = 'NeoTree Open Git Status', silent = true },
    { '<leader>ob', ':Neotree buffers<CR>', desc = 'NeoTree Open Buffers', silent = true },
  },
  opts = {
    sources = { 'filesystem', 'buffers', 'git_status' },
    open_files_do_not_replace_types = { 'terminal', 'Trouble', 'trouble', 'qf', 'Outline' },
    filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = {
        always_show = { -- remains visible even if other settings would normally hide it
          '.gitignore',
          '.stylua.toml',
        },
      },
    },
    enable_diagnostics = true,
    enable_git_status = true,
    window = {
      position = 'left',
      width = 40,
      mappings = {
        -- ['\\'] = 'close_window',
        ['l'] = 'open',
        ['h'] = 'close_node',
        ['<space>'] = 'none',
        ['<esc>'] = 'close_window',
        ['e'] = function(state)
          -- per-buffer flag so each tree remembers its last mode
          local src = state.name or state.source or 'filesystem'
          local flag_key = ('neotree_toggle_all_%s'):format(src)
          local was_expanded = vim.b[flag_key] == true

          local ok, cmds = pcall(require, 'neo-tree.sources.' .. src .. '.commands')
          if not ok then
            return
          end

          if was_expanded then
            cmds.close_all_nodes(state)
          else
            cmds.expand_all_nodes(state)
          end

          vim.b[flag_key] = not was_expanded
        end,
        ['Y'] = {
          function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            vim.fn.setreg('+', path, 'c')
          end,
          desc = 'Copy Path to Clipboard',
        },
        ['O'] = {
          function(state)
            require('lazy.util').open(state.tree:get_node().path, { system = true })
          end,
          desc = 'Open with System Application',
        },
        ['P'] = { 'toggle_preview', config = { use_float = false } },
      },
    },
    default_component_configs = {
      container = {
        enable_character_fade = true,
      },
      indent = {
        indent_size = 2,
        padding = 1, -- extra padding on left hand side
        -- indent guides
        with_markers = true,
        indent_marker = '│',
        last_indent_marker = '└',
        highlight = 'NeoTreeIndentMarker',
        -- expander config, needed for nesting files
        with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
        expander_collapsed = BA.config.icons.kinds.Collapsed,
        expander_expanded = BA.config.icons.kinds.Expanded,
        expander_highlight = 'NeoTreeExpander',
      },
      icon = {
        folder_closed = BA.config.icons.kinds.Folder,
        folder_open = BA.config.icons.kinds.FolderOpen,
        folder_empty = BA.config.icons.kinds.FolderEmpty,
        -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
        -- then these will never be used.
        default = '*',
        highlight = 'NeoTreeFileIcon',
      },
      modified = {
        symbol = '+',
        highlight = 'NeoTreeModified',
      },
      git_status = {
        symbols = {
          -- Change type
          added = BA.config.icons.git.added,
          modified = '', -- or ""
          deleted = BA.config.icons.git.deleted,
          renamed = BA.config.icons.git.renamed,
          -- Status type
          untracked = BA.config.icons.git.untrackd,
          ignored = BA.config.icons.git.ignored,
          unstaged = BA.config.icons.git.unstaged,
          staged = BA.config.icons.git.staged,
          conflict = BA.config.icons.git.conflict,
        },
      },
    },
  },
  config = function(_, opts)
    local function on_move(data)
      Snacks.rename.on_rename_file(data.source, data.destination)
    end

    local events = require 'neo-tree.events'
    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
    })
    require('neo-tree').setup(opts)
    vim.api.nvim_create_autocmd('TermClose', {
      pattern = '*lazygit',
      callback = function()
        if package.loaded['neo-tree.sources.git_status'] then
          require('neo-tree.sources.git_status').refresh()
        end
      end,
    })
  end,
}
