-- If you're wondering about lsp vs treesitter, see:
--  `:help lsp-vs-treesitter`
return {
  { -- configures Lua LSP for your Neovim config, runtime and plugins
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    event = 'VeryLazy',
    dependencies = {
      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },

    -- anything in other files can extend this
    opts = {
      servers = {
        lua_ls = { settings = { Lua = { completion = { callSnippet = 'Replace' } } } },
      },
    },

    config = function(_, opts)
      -- One-shot virtual-lines helper:
      -- NOTE: vim.diagnostic.config() is GLOBAL, so the reset autocmd must NOT be buffer-local.
      -- Otherwise, you can show vlines in one split and then move in another split -> reset never fires -> vlines “stick”.
      local jump_vlines_group = vim.api.nvim_create_augroup('jumpWithVirtLines', { clear = true })

      local vlines_state = {
        active = false,
        saved = nil, ---@type {virtual_text:any, virtual_lines:any}|nil
      }

      local function save_diag_config_once()
        if vlines_state.active then
          return
        end
        local cur = vim.diagnostic.config() or {}
        vlines_state.saved = {
          virtual_text = vim.deepcopy(cur.virtual_text),
          virtual_lines = vim.deepcopy(cur.virtual_lines),
        }
        vlines_state.active = true
      end

      local function restore_diag_config()
        if not vlines_state.active or not vlines_state.saved then
          return
        end
        vim.diagnostic.config {
          virtual_text = vlines_state.saved.virtual_text,
          virtual_lines = vlines_state.saved.virtual_lines,
        }
        vlines_state.active = false
        vlines_state.saved = nil

        -- force redraw for current buffer (good enough; avoids iterating all buffers)
        pcall(vim.diagnostic.show, nil, 0)
      end

      --- Show virtual_lines for current line once and restore on the next “real” interaction anywhere.
      ---@param bufnr? integer
      local function showVirtLineDiagsOnce(bufnr)
        bufnr = bufnr or 0

        save_diag_config_once()

        vim.diagnostic.config {
          virtual_text = false,
          virtual_lines = { current_line = true },
        }
        pcall(vim.diagnostic.show, nil, bufnr) -- force redraw

        -- Replace any previous pending reset. Global (not buffer-local) on purpose.
        vim.api.nvim_clear_autocmds { group = jump_vlines_group }
        vim.api.nvim_create_autocmd({
          'CursorMoved',
          'CursorMovedI',
          'InsertEnter',
          'WinLeave',
          'BufLeave',
          'CmdlineEnter',
          'ModeChanged',
        }, {
          desc = 'User(once): Reset diagnostics virtual lines',
          once = true,
          group = jump_vlines_group,
          callback = restore_diag_config,
        })
      end

      ---@param jumpCount number
      ---@param jumpOpts? table
      local function jumpWithVirtLines(jumpCount, jumpOpts)
        jumpOpts = jumpOpts or {}
        jumpOpts.count = jumpCount

        -- avoid leaving global config toggled if jump errors / nothing to jump to
        local ok = pcall(vim.diagnostic.jump, jumpOpts)
        if not ok then
          return
        end

        -- Deferred so the show/reset isn't “eaten” by the jump itself
        vim.defer_fn(function()
          showVirtLineDiagsOnce(0)
        end, 1)
      end

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an LSP (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- stylua: ignore start
          -- Jump to WARN/ERROR
          map(']d', function() jumpWithVirtLines(1, { severity = { min = vim.diagnostic.severity.WARN } }) end, 'Next Diagnostic')
          map('[d', function() jumpWithVirtLines(-1, { severity = { min = vim.diagnostic.severity.WARN } }) end, 'Prev Diagnostic')
          -- Jump to INFO/HINT 
          map(']h', function() jumpWithVirtLines(1, { severity = { max = vim.diagnostic.severity.HINT } }) end, 'Next Hint')
          map('[h', function() jumpWithVirtLines(-1, { severity = { max = vim.diagnostic.severity.HINT } }) end, 'Prev Hint')
          -- Show diagnostic in virtual lines
          map('<leader>k', function() showVirtLineDiagsOnce(event.buf) end, 'Show diagnostics lines')
          -- stylua: ignore end

          -- Open diagnostic float window with cursor in it.
          map('<C-w>d', function()
            local _, winid = vim.diagnostic.open_float()
            if winid then
              vim.api.nvim_set_current_win(winid)
            end
          end, 'Open diagnostics window under the cursor')

          -- This function resolves a difference between Neovim nightly (version 0.11) and stable (version 0.10)
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, 'Toggle Inlay Hints')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { scope = 'line', border = 'rounded', source = 'if_many' },
        underline = {
          severity = {
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
          },
        },
        signs = {
          severity = { min = vim.diagnostic.severity.WARN }, -- no sign column noise from hints
          text = {
            [vim.diagnostic.severity.ERROR] = BA.config.icons.diagnostics.Error,
            [vim.diagnostic.severity.WARN] = BA.config.icons.diagnostics.Warn,
            [vim.diagnostic.severity.HINT] = BA.config.icons.diagnostics.Hint,
            [vim.diagnostic.severity.INFO] = BA.config.icons.diagnostics.Info,
          },
        } or {},
        virtual_text = {
          severity = { min = vim.diagnostic.severity.WARN }, -- no hint spam in diagnostic message on the right
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- reads merged servers from all files
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local servers = (opts and opts.servers) or {}

      for name, cfg in pairs(servers) do
        cfg.capabilities = vim.tbl_deep_extend('force', {}, capabilities, cfg.capabilities or {})
        vim.lsp.config(name, cfg)
      end

      vim.lsp.enable(vim.tbl_keys(servers))
    end,
  },
}
