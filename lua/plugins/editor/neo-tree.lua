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
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
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
    },
    window = {
      mappings = {
        ['\\'] = 'close_window',
        ['l'] = 'open',
        ['h'] = 'close_node',
        ['<space>'] = 'none',
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
      indent = {
        with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
        expander_collapsed = BA.config.icons.kinds.Collapsed,
        expander_expanded = BA.config.icons.kinds.Expanded,
        expander_highlight = 'NeoTreeExpander',
      },
      icon = {
        folder_closed = BA.config.icons.kinds.Folder,
        folder_open = BA.config.icons.kinds.FolderOpen,
        folder_empty = BA.config.icons.kinds.FolderEmpty,
      },
      git_status = {
        symbols = {
          -- Change type
          added = BA.config.icons.git.added,
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
