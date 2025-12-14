return {
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        harper_ls = {
          settings = {
            ['harper-ls'] = {
              userDictPath = '',
              workspaceDictPath = '',
              fileDictPath = '',
              linters = {
                SpellCheck = false,
                ToDoHyphen = false,
                ExpandTimeShorthands = false,
                SentenceCapitalization = false,
                SpelledNumbers = true,
                NoOxfordComma = false,
                BoringWords = true,
                UnclosedQuotes = true,
                LongSentences = true,
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
        },
      },
    },
  },
}
