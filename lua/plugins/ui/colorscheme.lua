-- Disable builtin colorschemes
vim.opt.wildignore:append {
  -- 'blue.vim',
  'darkblue.vim',
  'default.vim',
  'delek.vim',
  'desert.vim',
  'elflord.vim',
  'evening.vim',
  'habamax.vim',
  'industry.vim',
  'koehler.vim',
  'lunaperche.vim',
  'morning.vim',
  'murphy.vim',
  'pablo.vim',
  'peachpuff.vim',
  'quiet.vim',
  'retrobox.vim',
  'ron.vim',
  'shine.vim',
  'slate.vim',
  'sorbet.vim',
  'torte.vim',
  'unokai.vim',
  'vim.lua',
  'wildcharm.vim',
  'zaibatsu.vim',
  'zellner.vim',
}

return {
  -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    opts = {
      -- Default options from tokyonight, with comments italics disabled.
      style = 'moon',
      light_style = 'day',
      transparent = false,
      terminal_colors = true,
      styles = {
        comments = { italic = false },
        keywords = { italic = true },
        functions = {},
        variables = {},
        sidebars = 'dark',
        floats = 'dark',
      },
      day_brightness = 0.3,
      dim_inactive = false,
      lualine_bold = false,
      on_colors = function(colors) end,
      on_highlights = function(highlights, colors) end,
      cache = true,
      plugins = {
        all = package.loaded.lazy == nil,
        auto = true,
      },
    },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme 'tokyonight-moon'
    end,
  },
  {
    'catppuccin/nvim',
    lazy = true,
    name = 'catppuccin',
    opts = {
      -- Default options from catppuccin with project-specific integration overrides kept.
      flavour = 'auto',
      background = {
        light = 'latte',
        dark = 'mocha',
      },
      compile_path = vim.fn.stdpath 'cache' .. '/catppuccin',
      transparent_background = false,
      float = {
        transparent = false,
        solid = false,
      },
      show_end_of_buffer = false,
      term_colors = false,
      kitty = vim.env.KITTY_WINDOW_ID and true or false,
      dim_inactive = {
        enabled = false,
        shade = 'dark',
        percentage = 0.15,
      },
      no_italic = false,
      no_bold = false,
      no_underline = false,
      styles = {
        comments = { 'italic' },
        conditionals = { 'italic' },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      lsp_styles = {
        virtual_text = {
          errors = { 'italic' },
          hints = { 'italic' },
          warnings = { 'italic' },
          information = { 'italic' },
          ok = { 'italic' },
        },
        underlines = {
          errors = { 'underline' },
          hints = { 'underline' },
          warnings = { 'underline' },
          information = { 'underline' },
          ok = { 'underline' },
        },
        inlay_hints = {
          background = true,
        },
      },
      default_integrations = true,
      auto_integrations = false,
      integrations = {
        alpha = true,
        blink_cmp = { enabled = true, style = 'bordered' },
        blink_indent = true,
        fzf = true,
        cmp = true,
        dap = true,
        dap_ui = true,
        dashboard = true,
        diffview = false,
        flash = true,
        gitsigns = true,
        markdown = true,
        neogit = true,
        neotree = true,
        nvimtree = true,
        ufo = true,
        rainbow_delimiters = true,
        render_markdown = true,
        telescope = { enabled = true },
        treesitter_context = true,
        barbecue = {
          dim_dirname = true,
          bold_basename = true,
          dim_context = false,
          alt_background = false,
        },
        illuminate = {
          enabled = true,
          lsp = false,
        },
        indent_blankline = {
          enabled = true,
          scope_color = '',
          colored_indent_levels = false,
        },
        navic = {
          enabled = true,
          custom_bg = 'lualine',
        },
        dropbar = {
          enabled = true,
          color_mode = false,
        },
        colorful_winsep = {
          enabled = false,
          color = 'red',
        },
        mini = {
          enabled = true,
          indentscope_color = 'overlay2',
        },
        lir = {
          enabled = false,
          git_status = false,
        },
        snacks = {
          enabled = true,
        },
        aerial = true,
        grug_far = true,
        headlines = true,
        leap = true,
        lsp_trouble = true,
        mason = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        treesitter = true,
        which_key = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { 'undercurl' },
            hints = { 'undercurl' },
            warnings = { 'undercurl' },
            information = { 'undercurl' },
          },
        },
        neotest = true,
      },
      color_overrides = {},
      highlight_overrides = {},
    },
    specs = {
      {
        'akinsho/bufferline.nvim',
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ''):find 'catppuccin' then
            opts.highlights = require('catppuccin.groups.integrations.bufferline').get()
          end
        end,
      },
    },
  },
  {
    'rebelot/kanagawa.nvim',
    lazy = true,
    opts = {
      -- Default Kanagawa config with comment/keyword italics disabled.
      undercurl = true,
      commentStyle = { italic = false },
      functionStyle = {},
      keywordStyle = { italic = false },
      statementStyle = { bold = true },
      typeStyle = {},
      transparent = false,
      dimInactive = false,
      terminalColors = true,
      colors = {
        theme = {
          wave = {},
          lotus = {},
          dragon = {},
          all = {},
        },
        palette = {},
      },
      overrides = function()
        return {}
      end,
      background = { dark = 'wave', light = 'lotus' },
      theme = 'wave',
      compile = false,
    },
  },
  {
    'rose-pine/neovim',
    lazy = true,
    name = 'rose-pine',
    opts = {
      -- Default Rose-Pine options with global italics disabled.
      variant = 'auto',
      dark_variant = 'main',
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      enable = {
        legacy_highlights = true,
        migrations = true,
        terminal = true,
      },
      styles = {
        bold = true,
        italic = false,
        transparency = false,
      },
      palette = {},
      groups = {
        border = 'muted',
        link = 'iris',
        panel = 'surface',

        error = 'love',
        hint = 'iris',
        info = 'foam',
        ok = 'leaf',
        warn = 'gold',
        note = 'pine',
        todo = 'rose',

        git_add = 'foam',
        git_change = 'rose',
        git_delete = 'love',
        git_dirty = 'rose',
        git_ignore = 'muted',
        git_merge = 'iris',
        git_rename = 'pine',
        git_stage = 'iris',
        git_text = 'rose',
        git_untracked = 'subtle',

        h1 = 'iris',
        h2 = 'foam',
        h3 = 'rose',
        h4 = 'gold',
        h5 = 'pine',
        h6 = 'leaf',
      },
      highlight_groups = {},
      before_highlight = function(group, highlight, palette) end,
    },
  },
  {
    'EdenEast/nightfox.nvim',
    lazy = true,
    opts = {
      options = {
        -- Nightfox defaults from `nightfox.config`, plus neutral syntax styles.
        compile_path = vim.fn.stdpath 'cache' .. '/nightfox',
        compile_file_suffix = '_compiled',
        transparent = false,
        terminal_colors = true,
        dim_inactive = false,
        module_default = true,
        colorblind = {
          enable = false,
          simulate_only = false,
          severity = {
            protan = 0,
            deutan = 0,
            tritan = 0,
          },
        },
        -- Values are Vim highlight attrs: NONE, bold, italic, underline, undercurl, reverse, etc.
        styles = {
          comments = 'NONE',
          conditionals = 'NONE',
          constants = 'NONE',
          functions = 'NONE',
          keywords = 'NONE',
          numbers = 'NONE',
          operators = 'NONE',
          preprocs = 'NONE',
          strings = 'NONE',
          types = 'NONE',
          variables = 'NONE',
        },
        inverse = {
          match_paren = false,
          visual = false,
          search = false,
        },
        modules = {
          coc = {
            background = true,
          },
          diagnostic = {
            enable = true,
            background = true,
          },
          native_lsp = {
            enable = vim.fn.has 'nvim' == 1,
            background = true,
          },
          treesitter = vim.fn.has 'nvim' == 1,
          lsp_semantic_tokens = vim.fn.has 'nvim' == 1,
          leap = {
            background = true,
          },
        },
      },
    },
  },
  {
    'navarasu/onedark.nvim',
    lazy = true,
    opts = {
      -- Default Onedark config with non-italic syntax styles.
      style = 'dark',
      toggle_style_key = nil,
      toggle_style_list = { 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer', 'light' },
      transparent = false,
      term_colors = true,
      ending_tildes = false,
      cmp_itemkind_reverse = false,
      -- Valid values: none, italic, bold, underline.
      code_style = {
        comments = 'none',
        keywords = 'none',
        functions = 'none',
        strings = 'none',
        variables = 'none',
      },
      lualine = {
        transparent = false,
      },
      colors = {},
      highlights = {},
      diagnostics = {
        darker = true,
        undercurl = true,
        background = true,
      },
    },
  },
  {
    'sainnhe/gruvbox-material',
    lazy = true,
    init = function()
      -- Defaults from gruvbox-material autoload config (0=false, 1=true).
      vim.g.gruvbox_material_background = 'medium'
      vim.g.gruvbox_material_foreground = 'material'
      vim.g.gruvbox_material_transparent_background = 0
      vim.g.gruvbox_material_dim_inactive_windows = 0
      vim.g.gruvbox_material_disable_italic_comment = 1
      vim.g.gruvbox_material_enable_bold = 0
      vim.g.gruvbox_material_enable_italic = 0
      vim.g.gruvbox_material_cursor = ''
      vim.g.gruvbox_material_visual = 'grey background'
      vim.g.gruvbox_material_menu_selection_background = 'grey'
      vim.g.gruvbox_material_sign_column_background = 'none'
      vim.g.gruvbox_material_spell_foreground = 'none'
      vim.g.gruvbox_material_ui_contrast = 'low'
      vim.g.gruvbox_material_show_eob = 1
      vim.g.gruvbox_material_float_style = 'bright'
      vim.g.gruvbox_material_current_word = 'grey background'
      vim.g.gruvbox_material_inlay_hints_background = 'none'
      vim.g.gruvbox_material_statusline_style = 'default'
      vim.g.gruvbox_material_lightline_disable_bold = 0
      vim.g.gruvbox_material_diagnostic_text_highlight = 0
      vim.g.gruvbox_material_diagnostic_line_highlight = 0
      vim.g.gruvbox_material_diagnostic_virtual_text = 'grey'
      vim.g.gruvbox_material_disable_terminal_colors = 0
      vim.g.gruvbox_material_better_performance = 1
      vim.g.gruvbox_material_colors_override = vim.empty_dict()
    end,
  },
  {
    'sainnhe/everforest',
    lazy = true,
    init = function()
      -- Defaults from everforest autoload config (0=false, 1=true).
      vim.g.everforest_background = 'medium'
      vim.g.everforest_transparent_background = 0
      vim.g.everforest_dim_inactive_windows = 0
      vim.g.everforest_disable_italic_comment = 1
      vim.g.everforest_enable_italic = 0
      vim.g.everforest_cursor = ''
      vim.g.everforest_sign_column_background = 'none'
      vim.g.everforest_spell_foreground = 'none'
      vim.g.everforest_ui_contrast = 'low'
      vim.g.everforest_show_eob = 1
      vim.g.everforest_float_style = 'bright'
      vim.g.everforest_current_word = 'grey background'
      vim.g.everforest_inlay_hints_background = 'none'
      vim.g.everforest_lightline_disable_bold = 0
      vim.g.everforest_diagnostic_text_highlight = 0
      vim.g.everforest_diagnostic_line_highlight = 0
      vim.g.everforest_diagnostic_virtual_text = 'grey'
      vim.g.everforest_disable_terminal_colors = 0
      vim.g.everforest_better_performance = 1
      vim.g.everforest_colors_override = vim.empty_dict()
    end,
  },
  {
    'scottmckendry/cyberdream.nvim',
    lazy = true,
    opts = {
      -- Full Cyberdream defaults.
      transparent = false,
      variant = 'default',
      saturation = 1,
      colors = {},
      highlights = {},
      italic_comments = false,
      hide_fillchars = false,
      borderless_pickers = false,
      terminal_colors = true,
      cache = false,
      extensions = {
        alpha = true,
        blinkcmp = true,
        cmp = true,
        dapui = true,
        dashboard = true,
        fzflua = true,
        gitpad = true,
        gitsigns = true,
        grapple = true,
        grugfar = true,
        heirline = true,
        helpview = true,
        hop = true,
        indentblankline = true,
        kubectl = true,
        lazy = true,
        leap = true,
        markdown = true,
        markview = true,
        mini = true,
        noice = true,
        neogit = true,
        notify = true,
        rainbow_delimiters = true,
        snacks = true,
        telescope = true,
        treesitter = true,
        treesittercontext = true,
        trouble = true,
        whichkey = true,
      },
    },
  },
  {
    'olimorris/onedarkpro.nvim',
    lazy = true,
    opts = {
      -- Full OneDarkPro defaults.
      caching = true,
      cache_path = vim.fn.expand(vim.fn.stdpath 'cache' .. '/onedarkpro'),
      cache_suffix = '_compiled',
      colors = {},
      debug = false,
      highlights = {},
      themes = {
        onedark = 'onedark',
        onedark_vivid = 'onedark_vivid',
        onedark_dark = 'onedark_dark',
        onelight = 'onelight',
        vaporwave = 'vaporwave',
      },
      styles = {
        tags = 'NONE',
        types = 'NONE',
        methods = 'NONE',
        numbers = 'NONE',
        strings = 'NONE',
        comments = 'NONE',
        keywords = 'NONE',
        constants = 'NONE',
        functions = 'NONE',
        operators = 'NONE',
        variables = 'NONE',
        parameters = 'NONE',
        conditionals = 'NONE',
        virtual_text = 'NONE',
      },
      filetypes = {
        c = true,
        comment = true,
        go = true,
        html = true,
        java = true,
        javascript = true,
        json = true,
        latex = true,
        lua = true,
        markdown = true,
        php = true,
        python = true,
        ruby = true,
        rust = true,
        scss = true,
        toml = true,
        typescript = true,
        typescriptreact = true,
        vue = true,
        xml = true,
        yaml = true,
      },
      plugins = {
        aerial = true,
        barbar = true,
        blink_cmp = true,
        blink_indent = true,
        blink_pairs = true,
        codecompanion = true,
        copilot = true,
        csvview = true,
        dashboard = true,
        diffview = true,
        flash_nvim = true,
        gitgraph_nvim = true,
        gitsigns = true,
        hop = true,
        indentline = true,
        leap = true,
        lsp_saga = true,
        lsp_semantic_tokens = true,
        marks = true,
        mason = true,
        mcphub = true,
        mini_diff = true,
        mini_icons = true,
        mini_indentscope = true,
        mini_test = true,
        neotest = true,
        neo_tree = true,
        nvim_cmp = true,
        nvim_bqf = true,
        nvim_dap = true,
        nvim_dap_ui = true,
        nvim_hlslens = true,
        nvim_lsp = true,
        nvim_navic = true,
        nvim_notify = true,
        nvim_tree = true,
        nvim_ts_rainbow = true,
        nvim_ts_rainbow2 = true,
        op_nvim = true,
        packer = true,
        persisted = true,
        polygot = true,
        rainbow_delimiters = true,
        render_markdown = true,
        snacks = true,
        startify = true,
        telescope = true,
        toggleterm = true,
        treesitter = true,
        trouble = true,
        vim_ultest = true,
        which_key = true,
        vim_dadbod_ui = true,
      },
      options = {
        cursorline = false,
        transparency = false,
        terminal_colors = true,
        lualine_transparency = false,
        highlight_inactive_windows = false,
      },
    },
  },
  {
    'shaunsingh/nord.nvim',
    lazy = true,
    init = function()
      -- nord.nvim globals from README defaults.
      vim.g.nord_contrast = false
      vim.g.nord_borders = false
      vim.g.nord_disable_background = false
      vim.g.nord_cursorline_transparent = false
      vim.g.nord_enable_sidebar_background = false
      vim.g.nord_italic = false
      vim.g.nord_uniform_diff_background = false
      vim.g.nord_bold = true
    end,
  },
  {
    'craftzdog/solarized-osaka.nvim',
    lazy = true,
    opts = {
      -- Full Solarized-Osaka defaults with comment italics disabled.
      style = '',
      light_style = 'light',
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = false },
        keywords = { italic = true },
        functions = {},
        variables = {},
        sidebars = 'dark',
        floats = 'dark',
      },
      sidebars = { 'qf', 'help' },
      day_brightness = 0.3,
      hide_inactive_statusline = false,
      dim_inactive = false,
      lualine_bold = false,
      on_colors = function(colors) end,
      on_highlights = function(highlights, colors) end,
      use_background = true,
      plugins = {
        all = package.loaded.lazy == nil,
        auto = true,
      },
    },
  },
  {
    'sainnhe/sonokai',
    lazy = true,
    init = function()
      -- Defaults from sonokai autoload config (0=false, 1=true).
      vim.g.sonokai_style = 'default'
      vim.g.sonokai_colors_override = vim.empty_dict()
      vim.g.sonokai_transparent_background = 0
      vim.g.sonokai_dim_inactive_windows = 0
      vim.g.sonokai_disable_italic_comment = 1
      vim.g.sonokai_enable_italic = 0
      vim.g.sonokai_cursor = ''
      vim.g.sonokai_menu_selection_background = 'blue'
      vim.g.sonokai_spell_foreground = 'none'
      vim.g.sonokai_show_eob = 1
      vim.g.sonokai_float_style = 'bright'
      vim.g.sonokai_current_word = 'grey background'
      vim.g.sonokai_inlay_hints_background = 'none'
      vim.g.sonokai_lightline_disable_bold = 0
      vim.g.sonokai_diagnostic_text_highlight = 0
      vim.g.sonokai_diagnostic_line_highlight = 0
      vim.g.sonokai_diagnostic_virtual_text = 'grey'
      vim.g.sonokai_disable_terminal_colors = 0
      vim.g.sonokai_better_performance = 1
    end,
  },
  {
    'AlexvZyl/nordic.nvim',
    lazy = true,
    opts = {
      -- Full Nordic defaults with non-italic comments.
      on_palette = function(palette) end,
      after_palette = function(palette) end,
      on_highlight = function(highlights, palette) end,
      bold_keywords = false,
      italic_comments = false,
      transparent = {
        bg = false,
        float = false,
      },
      bright_border = false,
      reduced_blue = true,
      swap_backgrounds = false,
      cursorline = {
        bold = false,
        bold_number = true,
        theme = 'dark',
        blend = 0.85,
      },
      visual = {
        bold = false,
        bold_number = true,
        theme = 'dark',
        blend = 0.85,
      },
      integrations = {
        dashboard = true,
        diff_view = true,
        gitsigns = true,
        indent_blankline = true,
        lazy = true,
        leap = true,
        lsp_saga = true,
        mini = true,
        neo_tree = true,
        neorg = true,
        noice = true,
        notify = true,
        nvim_cmp = true,
        blink_cmp = true,
        nvim_dap = true,
        nvim_tree = true,
        rainbow_delimiters = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
        trouble = true,
        vimtex = true,
        visual_whitespace = true,
        which_key = true,
      },
      noice = {
        style = 'classic',
      },
      telescope = {
        style = 'flat',
      },
      leap = {
        dim_backdrop = false,
      },
      ts_context = {
        dark_background = true,
      },
    },
  },
  {
    'bluz71/vim-moonfly-colors',
    lazy = true,
    init = function()
      -- Defaults from moonfly colorscheme.
      vim.g.moonflyCursorColor = false
      vim.g.moonflyItalics = false
      vim.g.moonflyNormalPmenu = false
      vim.g.moonflyNormalFloat = false
      vim.g.moonflyTerminalColors = true
      vim.g.moonflyTransparent = false
      vim.g.moonflyUndercurls = true
      vim.g.moonflyUnderlineMatchParen = false
      vim.g.moonflyVirtualTextColor = false
      vim.g.moonflyWinSeparator = 1
    end,
  },
  {
    'ribru17/bamboo.nvim',
    lazy = true,
    opts = {
      -- Full Bamboo defaults with comment/keyword italics disabled.
      style = 'vulgaris',
      toggle_style_key = nil,
      toggle_style_list = { 'vulgaris', 'multiplex', 'light' },
      transparent = false,
      dim_inactive = false,
      term_colors = true,
      ending_tildes = false,
      cmp_itemkind_reverse = false,
      code_style = {
        comments = { italic = false },
        conditionals = { italic = true },
        keywords = { italic = false },
        functions = {},
        namespaces = { italic = true },
        parameters = { italic = true },
        strings = {},
        variables = {},
      },
      lualine = {
        transparent = false,
      },
      colors = {},
      highlights = {},
      diagnostics = {
        darker = false,
        undercurl = true,
        background = true,
      },
    },
  },
}
