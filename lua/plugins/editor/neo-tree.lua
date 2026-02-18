--- @module 'snacks'
-- Neo-tree is a Neovim plugin to browse the filesystem
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    'MunifTanjim/nui.nvim',
  },
  keys = {
    { '\\', ':Neotree toggle<CR>', desc = 'NeoTree toggle', silent = true },
    -- { '<leader>e', ':Neotree toggle<CR>', desc = 'NeoTree toggle', silent = true },
    { '<leader>os', ':Neotree git_status<CR>', desc = 'NeoTree Open Git Status', silent = true },
    { '<leader>ob', ':Neotree buffers<CR>', desc = 'NeoTree Open Buffers', silent = true },
  },
  opts = {
    sources = { 'filesystem', 'buffers', 'git_status' },
    open_files_do_not_replace_types = { 'terminal', 'Trouble', 'trouble', 'qf', 'Outline' },
    filesystem = {
      bind_to_cwd = true,
      cwd_target = {
        sidebar = 'global',
        current = 'window',
      },
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      group_empty_dirs = true,
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
        ['\\'] = 'close_window',
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
        padding = 1, -- extra padding on left-hand side
        -- indent guides
        with_markers = true,
        indent_marker = '│ ',
        middle_marker = '├╴',
        last_indent_marker = '└╴',
        highlight = 'NeoTreeIndentMarker',
        -- expander config, needed for nesting files
        with_expanders = false, -- if nil and file nesting is enabled, will enable expanders
        expander_collapsed = BA.config.icons.kinds.Collapsed,
        expander_expanded = BA.config.icons.kinds.Expanded,
        expander_highlight = 'NeoTreeExpander',
      },
      icon = {
        folder_closed = '', -- BA.config.icons.kinds.Folder,
        folder_open = '', -- BA.config.icons.kinds.FolderOpen,
        folder_empty = '', -- BA.config.icons.kinds.FolderEmpty,
        -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
        -- then these will never be used.
        default = '', --'*',
        highlight = 'NeoTreeFileIcon',
      },
      modified = {
        symbol = '+',
        highlight = 'NeoTreeModified',
      },
      diagnostics = {
        symbols = {
          hint = BA.config.icons.explorer_diagnostics.Hint,
          info = BA.config.icons.explorer_diagnostics.Info,
          warn = BA.config.icons.explorer_diagnostics.Warn,
          error = BA.config.icons.explorer_diagnostics.Error,
        },
      },
      git_status = {
        symbols = {
          -- Change type
          added = '',
          modified = '○',
          deleted = '',
          renamed = '',
          -- Status type
          untracked = '?',
          ignored = ' ',
          unstaged = '○',
          staged = '●',
          conflict = ' ',
        },
      },
    },
  },
  config = function(_, opts)
    local fallback_explorer_icons = {
      git = {
        enabled = true,
        staged = '●',
        added = '',
        deleted = '',
        ignored = ' ',
        modified = '○',
        renamed = '',
        unmerged = ' ',
        untracked = '?',
      },
      diagnostics = BA.config.icons.explorer_diagnostics,
    }

    local function get_explorer_icons()
      local icons = vim.deepcopy(fallback_explorer_icons)
      local ok_cfg, picker_cfg = pcall(require, 'snacks.picker.config')
      if ok_cfg and type(picker_cfg.get) == 'function' then
        local ok_opts, picker_opts = pcall(picker_cfg.get, { source = 'explorer' })
        if ok_opts and type(picker_opts) == 'table' and type(picker_opts.icons) == 'table' then
          icons = vim.tbl_deep_extend('force', icons, picker_opts.icons)
        end
      end
      return icons
    end

    local function tree_indent(config, node, state)
      if not state.skip_marker_at_level then
        state.skip_marker_at_level = {}
      end
      local skip_marker = state.skip_marker_at_level
      local indent_size = config.indent_size or 2
      local padding = config.padding or 0
      local level = node.level
      local with_markers = config.with_markers
      local marker_highlight = config.highlight or 'NeoTreeIndentMarker'

      if indent_size == 0 or level < 1 or not with_markers then
        return {
          text = string.rep(' ', indent_size * level + padding),
        }
      end

      local indent_marker = config.indent_marker or '│ '
      local middle_marker = config.middle_marker or '├╴'
      local last_indent_marker = config.last_indent_marker or '└╴'

      skip_marker[level] = node.is_last_child
      local indent = {}
      if padding > 0 then
        table.insert(indent, { text = string.rep(' ', padding) })
      end

      for i = 1, level do
        local char = ''
        local spaces_count = indent_size
        local highlight = nil

        if i < level then
          if not skip_marker[i] then
            char = indent_marker
            highlight = marker_highlight
          end
        else
          char = node.is_last_child and last_indent_marker or middle_marker
          highlight = marker_highlight
        end

        if char ~= '' then
          spaces_count = math.max(0, spaces_count - vim.api.nvim_strwidth(char))
        end

        table.insert(indent, {
          text = char .. string.rep(' ', spaces_count),
          highlight = highlight,
          no_next_padding = true,
        })
      end

      return indent
    end

    local default_common_components = require 'neo-tree.sources.common.components'

    local function tree_git_status(config, node, state)
      if config.hide_when_expanded and node.type == 'directory' and node:is_expanded() then
        return {}
      end
      if not state.git_status_lookup then
        return {}
      end

      local xy = state.git_status_lookup[node.path]
      if not xy then
        if node.filtered_by and node.filtered_by.gitignored then
          xy = '!!'
        else
          return {}
        end
      end

      local ok_git, git_source = pcall(require, 'snacks.picker.source.git')
      if not ok_git or type(git_source.git_status) ~= 'function' then
        return default_common_components.git_status(config, node, state)
      end

      local ok_status, status = pcall(git_source.git_status, xy)
      if not ok_status or type(status) ~= 'table' then
        return default_common_components.git_status(config, node, state)
      end

      local icons = get_explorer_icons()
      local git_icons = icons.git or {}
      local icon = (status.status or ''):sub(1, 1):upper()
      if status.status == 'untracked' then
        icon = '?'
      elseif status.status == 'ignored' then
        icon = '!'
      end

      if git_icons.enabled ~= false then
        local candidate = git_icons[status.unmerged and 'unmerged' or status.status]
        if type(candidate) == 'string' and candidate ~= '' then
          icon = candidate
        end
        if status.staged then
          local staged = git_icons.staged
          if type(staged) == 'string' and staged ~= '' then
            icon = staged
          end
        end
      end

      if type(icon) ~= 'string' or icon == '' then
        return {}
      end

      local hl
      if status.unmerged then
        hl = 'NeoTreeGitConflict'
      elseif status.staged then
        hl = 'NeoTreeGitStaged'
      else
        local map = {
          added = 'NeoTreeGitAdded',
          modified = 'NeoTreeGitModified',
          deleted = 'NeoTreeGitDeleted',
          renamed = 'NeoTreeGitRenamed',
          copied = 'NeoTreeGitRenamed',
          untracked = 'NeoTreeGitUntracked',
          ignored = 'NeoTreeGitIgnored',
        }
        hl = map[status.status] or 'NeoTreeGitModified'
      end

      if vim.api.nvim_strwidth(icon) == 1 then
        icon = icon .. ' '
      end

      return {
        text = icon,
        highlight = hl,
      }
    end

    for _, source in ipairs { 'filesystem', 'buffers', 'git_status' } do
      opts[source] = opts[source] or {}
      opts[source].components = opts[source].components or {}
      opts[source].components.indent = tree_indent
      opts[source].components.icon = function() return {} end
      opts[source].components.git_status = tree_git_status
    end

    local function apply_snacks_highlights()
      local links = {
        NeoTreeNormal = 'SnacksPickerList',
        NeoTreeNormalNC = 'SnacksPickerList',
        NeoTreeSignColumn = 'SnacksPickerList',
        NeoTreeEndOfBuffer = 'SnacksPickerList',
        NeoTreeCursorLine = 'SnacksPickerListCursorLine',
        NeoTreeFloatBorder = 'SnacksPickerBorder',
        NeoTreeFloatTitle = 'SnacksPickerTitle',
        NeoTreeTitleBar = 'SnacksPickerTitle',
        NeoTreeVertSplit = 'WinSeparator',
        NeoTreeWinSeparator = 'WinSeparator',
        NeoTreeDirectoryName = 'SnacksPickerDirectory',
        NeoTreeFileName = 'SnacksPickerFile',
        NeoTreeFileNameOpened = 'SnacksPickerFile',
        NeoTreeRootName = 'SnacksPickerDirectory',
        NeoTreeDirectoryIcon = 'SnacksPickerDirectory',
        NeoTreeFileIcon = 'SnacksPickerFile',
        NeoTreeIndentMarker = 'SnacksPickerTree',
        NeoTreeExpander = 'SnacksPickerTree',
        NeoTreeSymbolicLinkTarget = 'SnacksPickerLink',
        NeoTreeDotfile = 'SnacksPickerPathHidden',
        NeoTreeHiddenByName = 'SnacksPickerPathHidden',
        NeoTreeIgnored = 'SnacksPickerPathIgnored',
        NeoTreeGitIgnored = 'SnacksPickerGitStatusIgnored',
        NeoTreeModified = 'SnacksPickerGitStatusModified',
        NeoTreeGitAdded = 'SnacksPickerGitStatusAdded',
        NeoTreeGitModified = 'SnacksPickerGitStatusModified',
        NeoTreeGitDeleted = 'SnacksPickerGitStatusDeleted',
        NeoTreeGitRenamed = 'SnacksPickerGitStatusRenamed',
        NeoTreeGitStaged = 'SnacksPickerGitStatusStaged',
        NeoTreeGitUntracked = 'SnacksPickerGitStatusUntracked',
        NeoTreeGitUnstaged = 'SnacksPickerGitStatusModified',
        NeoTreeGitConflict = 'SnacksPickerGitStatusUnmerged',
        NeoTreeMessage = 'SnacksPickerDimmed',
        NeoTreeDimText = 'SnacksPickerDimmed',
        NeoTreeFadeText1 = 'SnacksPickerDimmed',
        NeoTreeFadeText2 = 'SnacksPickerDimmed',
      }
      for from, to in pairs(links) do
        vim.api.nvim_set_hl(0, from, { link = to })
      end
    end

    local function style_neotree_window(winid)
      if not (winid and vim.api.nvim_win_is_valid(winid)) then
        return
      end
      local fillchars = vim.wo[winid].fillchars or ''
      if fillchars:find 'eob:' then
        fillchars = fillchars:gsub('eob:[^,]*', 'eob: ')
      else
        fillchars = (fillchars ~= '' and (fillchars .. ',') or '') .. 'eob: '
      end
      vim.wo[winid].fillchars = fillchars
      if vim.fn.exists '&winfixbuf' == 1 then
        vim.wo[winid].winfixbuf = false
      end
    end

    local function on_move(data)
      Snacks.rename.on_rename_file(data.source, data.destination)
    end

    local function sync_icons_from_snacks()
      local icons = get_explorer_icons()
      local snacks_git = icons.git or {}
      local snacks_diag = icons.diagnostics or {}

      opts.default_component_configs = opts.default_component_configs or {}
      opts.default_component_configs.diagnostics = opts.default_component_configs.diagnostics or {}
      opts.default_component_configs.git_status = opts.default_component_configs.git_status or {}

      opts.default_component_configs.diagnostics.symbols = {
        hint = snacks_diag.Hint or BA.config.icons.explorer_diagnostics.Hint,
        info = snacks_diag.Info or BA.config.icons.explorer_diagnostics.Info,
        warn = snacks_diag.Warn or BA.config.icons.explorer_diagnostics.Warn,
        error = snacks_diag.Error or BA.config.icons.explorer_diagnostics.Error,
      }

      opts.default_component_configs.git_status.symbols = {
        added = snacks_git.added or fallback_explorer_icons.git.added,
        modified = snacks_git.modified or fallback_explorer_icons.git.modified,
        deleted = snacks_git.deleted or fallback_explorer_icons.git.deleted,
        renamed = snacks_git.renamed or fallback_explorer_icons.git.renamed,
        untracked = snacks_git.untracked or fallback_explorer_icons.git.untracked,
        ignored = snacks_git.ignored or fallback_explorer_icons.git.ignored,
        unstaged = snacks_git.modified or fallback_explorer_icons.git.modified,
        staged = snacks_git.staged or fallback_explorer_icons.git.staged,
        conflict = snacks_git.unmerged or fallback_explorer_icons.git.unmerged,
      }
    end

    local events = require 'neo-tree.events'
    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
      {
        event = events.NEO_TREE_WINDOW_AFTER_OPEN,
        handler = function(args)
          style_neotree_window(args.winid)
        end,
      },
    })
    sync_icons_from_snacks()
    require('neo-tree').setup(opts)
    if vim.fn.maparg('<C-w>h', 'n') == '' then
      vim.keymap.set('n', '<C-w>h', function()
        for _ = 1, vim.v.count1 do
          vim.cmd 'wincmd h'
        end
      end, { silent = true, desc = 'Move focus to the left window' })
    end
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(winid)
      if vim.bo[buf].filetype == 'neo-tree' then
        style_neotree_window(winid)
      end
    end
    local hl_group = vim.api.nvim_create_augroup('ba_neotree_snacks_hl', { clear = true })
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = hl_group,
      callback = function()
        vim.schedule(apply_snacks_highlights)
      end,
    })
    vim.schedule(apply_snacks_highlights)
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
