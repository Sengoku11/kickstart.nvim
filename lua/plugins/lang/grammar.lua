return {
  {
    'neovim/nvim-lspconfig',
    event = 'VeryLazy',
    dependencies = {
      'saghen/blink.cmp',
    },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      vim.lsp.config('harper_ls', {
        capabilities = capabilities,
        settings = {
          ['harper-ls'] = {
            userDictPath = '',
            workspaceDictPath = '',
            fileDictPath = '',
            linters = {
              SpellCheck = false,
              SpelledNumbers = false,
              AnA = true,
              SentenceCapitalization = false,
              UnclosedQuotes = true,
              WrongQuotes = false,
              LongSentences = true,
              RepeatedWords = true,
              Spaces = true,
              Matcher = true,
              CorrectNumberSuffix = true,
            },
            codeActions = {
              ForceStable = false,
            },
            markdown = {
              IgnoreLinkTitle = false,
            },
            diagnosticSeverity = 'hint',
            isolateEnglish = false,
            dialect = 'American',
            maxFileLength = 120000,
            ignoredLintsPath = '',
            excludePatterns = {},
          },
        },
      })

      vim.lsp.enable 'harper_ls'
    end,
  },
}
