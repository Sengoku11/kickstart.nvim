return {
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      opts.servers.harper_ls = vim.tbl_deep_extend('force', opts.servers.harper_ls or {}, {
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
            codeActions = { ForceStable = false },
            markdown = { IgnoreLinkTitle = false },
            diagnosticSeverity = 'hint',
            isolateEnglish = false,
            dialect = 'American',
            maxFileLength = 120000,
            ignoredLintsPath = '',
            excludePatterns = {},
          },
        },
      })
    end,
  },
}
