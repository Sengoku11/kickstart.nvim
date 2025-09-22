return {
  -- lsp symbol navigation for lualine. This shows where
  -- in the code structure you are - within functions, classes,
  -- etc - in the statusline.
  {
    'SmiteshP/nvim-navic',
    enabled = false,
    lazy = true,
    init = function()
      vim.g.navic_silence = true -- set to true to supress error messages thrown by nvim-navic.
      BA.util.lsp.on_attach(function(client, buffer)
        if client.supports_method 'textDocument/documentSymbol' then
          require('nvim-navic').attach(client, buffer)
        end
      end)
    end,
    opts = function()
      require('nvim-navic').setup {
        separator = ' ',
        highlight = true,
        depth_limit = 0,
        icons = BA.config.icons.kinds,
        lazy_update_context = true,
      }
    end,
  },
}
