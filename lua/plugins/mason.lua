return {
  {
    -- Mason core: manages external tools installed in Neovim's data dir
    'mason-org/mason.nvim',
    event = 'VeryLazy',
    opts = {},
  },
  {
    -- Bridge between Mason and LSP servers
    'mason-org/mason-lspconfig.nvim',
    event = 'VeryLazy',
    dependencies = {
      'mason-org/mason.nvim',
      'neovim/nvim-lspconfig',
    },
    opts = {
      -- LSP servers and tools to install via Mason
      ensure_installed = {
        'lua_ls',
        'harper_ls',
        'stylua',
      },
      automatic_installation = true,
    },
  },
}
