local filetypes = { 'java' }
local roots = {
  'build.gradle',
  'build.gradle.kts',
  'build.xml', -- Ant
  'pom.xml', -- Maven
  'settings.gradle', -- Gradle
  'settings.gradle.kts', -- Gradle
}

return {
  { 'nvim-treesitter/nvim-treesitter', ft = roots, root = roots, opts = { ensure_installed = { 'java' } } },
  { 'nvim-java/nvim-java', ft = filetypes, root = roots },
  {
    'neovim/nvim-lspconfig',
    ft = filetypes,
    root = roots,
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
