return {
  { 'nvim-treesitter/nvim-treesitter', ft = { 'java' }, opts = { ensure_installed = { 'java' } } },
  { 'nvim-java/nvim-java', ft = 'java' },
  {
    'neovim/nvim-lspconfig',
    ft = 'java',
    dependencies = {
      'saghen/blink.cmp',
    },
    opts = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      require('java').setup {
        -- Your custom jdtls settings goes here
        capabilities = capabilities,
      }

      require('lspconfig').jdtls.setup {
        -- Your custom nvim-java configuration goes here
        capabilities = capabilities,
      }
    end,
  },
}
