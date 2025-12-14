return {
  {
    'mason-org/mason.nvim',
    event = 'VeryLazy',
    opts = {},
  },

  {
    'mason-org/mason-lspconfig.nvim',
    event = 'VeryLazy',
    dependencies = {
      'mason-org/mason.nvim',
      'neovim/nvim-lspconfig',
    },
    opts = {
      ensure_installed = {
        'lua_ls',
        'harper_ls',
      },

      -- NOTE:
      -- mason-lspconfig auto-enables installed servers by default.
      -- Disable it completely, OR exclude, OR whitelist only.
      -- Pick ONE of the following:

      -- (A) Disable auto-enable entirely:
      automatic_enable = false,

      -- (B) Exclude specific tools only:
      -- automatic_enable = {
      --   exclude = { 'harper_ls' },
      -- },

      -- (C) Only auto-enable these servers:
      -- automatic_enable = { "lua_ls" },
    },
  },
}
